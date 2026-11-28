//! OpenNOW chat: local-first friend messaging with a peer transport.
//!
//! Conversations live in the core data directory and travel directly between
//! OpenNOW instances that can reach each other - two copies on one machine, or
//! two machines on the same network. Peers announce themselves in a shared
//! local discovery directory and, best effort, through a UDP beacon; messages
//! are store-and-forward, so anything written while a friend is away is
//! flushed the moment they come back.

use rand::RngCore;
use serde_json::{Map, Value, json};
use std::collections::BTreeMap;
use std::io::{BufRead, BufReader, Write};
use std::net::{SocketAddr, TcpListener, TcpStream, UdpSocket};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, mpsc};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const DISCOVERY_DIR: &str = "opennow-chat-peers";
const BEACON_PORT: u16 = 48713;
const PEER_TIMEOUT_MS: u64 = 12_000;
const MAX_TEXT_CHARS: usize = 2_000;
const MAX_LINE_BYTES: u64 = 64 * 1024;
const CONNECT_TIMEOUT_MS: u64 = 1_200;
const ACK_TIMEOUT_MS: u64 = 1_500;
const PENDING_TTL_MS: u64 = 24 * 60 * 60 * 1_000;

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
}

fn new_id(prefix: &str) -> String {
    let mut rng = rand::thread_rng();
    format!("{prefix}-{:08x}{:08x}", rng.next_u32(), rng.next_u32())
}

/// Trims and caps outgoing text so a pasted wall of text cannot flood a peer.
fn sanitize_text(text: &str) -> String {
    text.chars()
        .take(MAX_TEXT_CHARS)
        .collect::<String>()
        .trim()
        .to_owned()
}

fn resolve_address(host: &str, port: u16) -> Result<SocketAddr, ()> {
    format!("{host}:{port}")
        .to_socket_addrs()
        .map_err(|_| ())?
        .next()
        .ok_or(())
}

#[derive(Default)]
struct Store {
    self_id: String,
    self_name: String,
    friends: Vec<Value>,
    pending: Vec<Value>,
    threads: BTreeMap<String, Vec<Value>>,
    peers: BTreeMap<String, Peer>,
    last_incoming: Value,
}

#[derive(Clone, Default)]
struct Peer {
    id: String,
    name: String,
    host: String,
    port: u16,
    seen_ms: u64,
    lan: bool,
}

impl Store {
    fn load(path: &Path) -> Store {
        let mut store = Store::default();
        if let Ok(bytes) = std::fs::read(path) {
            if let Ok(raw) = serde_json::from_slice::<Value>(&bytes) {
                store.self_id = raw["selfId"].as_str().unwrap_or("").to_owned();
                store.self_name = raw["selfName"].as_str().unwrap_or("").to_owned();
                if let Some(friends) = raw["friends"].as_array() {
                    store.friends = friends
                        .iter()
                        .filter(|friend| !friend["id"].as_str().unwrap_or("").is_empty())
                        .cloned()
                        .collect();
                }
                if let Some(threads) = raw["threads"].as_object() {
                    for (peer, messages) in threads {
                        let kept = messages
                            .as_array()
                            .map(|list| {
                                list.iter()
                                    .filter(|message| message["text"].is_string())
                                    .cloned()
                                    .collect::<Vec<Value>>()
                            })
                            .unwrap_or_default();
                        if !kept.is_empty() {
                            store.threads.insert(peer.clone(), kept);
                        }
                    }
                }
                store.last_incoming = raw["lastIncoming"].clone();
            }
        }
        if store.self_id.is_empty() {
            store.self_id = new_id("opennow-user");
        }
        store
    }

    fn save(&self, path: &Path) {
        let threads = self
            .threads
            .iter()
            .map(|(peer, messages)| (peer.clone(), Value::Array(messages.clone())))
            .collect::<Map<String, Value>>();
        let payload = json!({
            "version": 1,
            "selfId": self.self_id,
            "selfName": self.self_name,
            "friends": self.friends.clone(),
            "threads": threads,
            "lastIncoming": self.last_incoming.clone(),
        });
        let temp = path.with_extension("json.tmp");
        if let Ok(bytes) = serde_json::to_vec(&payload) {
            if std::fs::write(&temp, bytes).is_ok() {
                let _ = std::fs::rename(&temp, path);
            }
        }
    }

    fn friend_index(&self, peer_id: &str) -> Option<usize> {
        self.friends
            .iter()
            .position(|friend| friend["id"].as_str() == Some(peer_id))
    }

    fn pending_index(&self, peer_id: &str) -> Option<usize> {
        self.pending
            .iter()
            .position(|entry| entry["id"].as_str() == Some(peer_id))
    }

    fn unread_total(&self) -> u64 {
        self.friends
            .iter()
            .map(|friend| friend["unread"].as_u64().unwrap_or(0))
            .sum()
    }
}

pub struct ChatService {
    store: Arc<Mutex<Store>>,
    path: PathBuf,
    port: u16,
    events: mpsc::Sender<Value>,
    stopped: Arc<AtomicBool>,
}

impl ChatService {
    pub fn new(data_dir: &Path, events: mpsc::Sender<Value>) -> Result<Self, String> {
        let path = data_dir.join("chat.json");
        let store = Arc::new(Mutex::new(Store::load(&path)));
        let listener =
            TcpListener::bind("0.0.0.0:0").map_err(|error| format!("chat listener: {error}"))?;
        let port = listener
            .local_addr()
            .map_err(|error| format!("chat listener address: {error}"))?
            .port();
        let service = Self {
            store: Arc::clone(&store),
            path,
            port,
            events,
            stopped: Arc::new(AtomicBool::new(false)),
        };
        service.spawn_listener(listener);
        service.spawn_beacon();
        Ok(service)
    }

    pub fn state(&self) -> Value {
        let store = self.store.lock().expect("chat store poisoned");
        Self::state_value(&store, self.port)
    }

    fn state_value(store: &Store, port: u16) -> Value {
        let now = now_ms();
        let peers = store
            .peers
            .values()
            .map(|peer| {
                json!({
                    "id": peer.id,
                    "name": peer.name,
                    "host": peer.host,
                    "port": peer.port,
                    "online": now.saturating_sub(peer.seen_ms) < PEER_TIMEOUT_MS,
                    "lan": peer.lan,
                })
            })
            .collect::<Vec<Value>>();
        let friends = store
            .friends
            .iter()
            .map(|friend| {
                let id = friend["id"].as_str().unwrap_or("");
                let online = store
                    .peers
                    .get(id)
                    .map(|peer| now.saturating_sub(peer.seen_ms) < PEER_TIMEOUT_MS)
                    .unwrap_or(false);
                let mut value = friend.clone();
                value["online"] = json!(online);
                value
            })
            .collect::<Vec<Value>>();
        let threads = store
            .threads
            .iter()
            .map(|(peer, messages)| (peer.clone(), Value::Array(messages.clone())))
            .collect::<Map<String, Value>>();
        json!({
            "selfId": store.self_id,
            "selfName": store.self_name,
            "port": port,
            "peers": peers,
            "friends": friends,
            "pending": store.pending.clone(),
            "threads": threads,
            "unreadTotal": store.unread_total(),
            "lastIncoming": store.last_incoming.clone(),
        })
    }

    fn emit(&self) {
        let _ = self
            .events
            .send(json!({"type":"event", "name":"chat.changed", "payload": self.state()}));
    }

    fn persist(&self) {
        let store = self.store.lock().expect("chat store poisoned");
        store.save(&self.path);
    }

    pub fn set_name(&self, name: &str) {
        let cleaned = sanitize_text(name);
        if cleaned.is_empty() {
            return;
        }
        {
            let mut store = self.store.lock().expect("chat store poisoned");
            if store.self_name == cleaned {
                return;
            }
            store.self_name = cleaned;
        }
        self.persist();
        self.emit();
    }

    pub fn send(&self, peer_id: &str, text: &str) -> Result<Value, (String, String)> {
        let cleaned = sanitize_text(text);
        if cleaned.is_empty() {
            return Err(("chat_empty".to_owned(), "Nothing to send".to_owned()));
        }
        let message = json!({
            "id": new_id("msg"),
            "peerId": peer_id,
            "mine": true,
            "text": cleaned,
            "tsMs": now_ms(),
            "delivered": false,
        });
        let message_id = message["id"].as_str().unwrap_or("").to_owned();
        let target = {
            let mut store = self.store.lock().expect("chat store poisoned");
            if store.friend_index(peer_id).is_none() {
                return Err((
                    "chat_not_friends".to_owned(),
                    "Add this person as a friend before messaging them".to_owned(),
                ));
            }
            store
                .threads
                .entry(peer_id.to_owned())
                .or_default()
                .push(message.clone());
            store.peers.get(peer_id).cloned()
        };
        let mut delivered = false;
        if let Some(peer) = target {
            delivered = self.deliver(&peer, &message);
        }
        {
            let mut store = self.store.lock().expect("chat store poisoned");
            if delivered {
                if let Some(list) = store.threads.get_mut(peer_id) {
                    if let Some(entry) = list
                        .iter_mut()
                        .find(|entry| entry["id"].as_str() == Some(message_id.as_str()))
                    {
                        entry["delivered"] = json!(true);
                    }
                }
            }
            store.save(&self.path);
        }
        self.emit();
        Ok(message)
    }

    pub fn request(&self, peer_id: &str, endpoint: &str) -> Result<Value, (String, String)> {
        let peer = if !peer_id.is_empty() {
            let store = self.store.lock().expect("chat store poisoned");
            store.peers.get(peer_id).cloned().ok_or_else(|| {
                (
                    "chat_unknown_peer".to_owned(),
                    "That OpenNOW is not discoverable right now".to_owned(),
                )
            })?
        } else {
            self.resolve_endpoint(endpoint)?
        };
        if peer.id.is_empty() || peer.port == 0 {
            return Err((
                "chat_bad_peer".to_owned(),
                "Incomplete peer address".to_owned(),
            ));
        }
        let already = {
            let store = self.store.lock().expect("chat store poisoned");
            store.friend_index(&peer.id).is_some() || store.pending_index(&peer.id).is_some()
        };
        if already {
            return Ok(self.state());
        }
        let request = json!({"t":"req", "id": self.self_id(), "name": self.self_name()});
        let reply = self.talk(&peer, &request)?;
        match reply["t"].as_str().unwrap_or("") {
            "accept" => self.apply_accept(&peer),
            "decline" => {
                return Err((
                    "chat_declined".to_owned(),
                    "That OpenNOW declined the friend request".to_owned(),
                ));
            }
            _ => {
                let mut store = self.store.lock().expect("chat store poisoned");
                if store.pending_index(&peer.id).is_none() {
                    store.pending.push(json!({
                        "id": peer.id, "name": peer.name, "dir": "outgoing", "tsMs": now_ms(),
                    }));
                }
                store.peers.insert(peer.id.clone(), peer.clone());
            }
        }
        self.persist();
        self.emit();
        Ok(self.state())
    }

    pub fn respond(&self, peer_id: &str, accept: bool) -> Result<Value, (String, String)> {
        let peer = {
            let store = self.store.lock().expect("chat store poisoned");
            let Some(index) = store.pending_index(peer_id) else {
                return Err((
                    "chat_no_request".to_owned(),
                    "No such friend request".to_owned(),
                ));
            };
            let entry = &store.pending[index];
            store.peers.get(peer_id).cloned().unwrap_or(Peer {
                id: entry["id"].as_str().unwrap_or("").to_owned(),
                name: entry["name"].as_str().unwrap_or("").to_owned(),
                host: "127.0.0.1".to_owned(),
                port: 0,
                seen_ms: 0,
                lan: false,
            })
        };
        {
            let mut store = self.store.lock().expect("chat store poisoned");
            if let Some(index) = store.pending_index(peer_id) {
                store.pending.remove(index);
            }
        }
        if accept {
            self.apply_accept(&peer);
            if peer.port != 0 {
                let accept = json!({"t":"accept", "id": self.self_id(), "name": self.self_name()});
                let _ = self.talk(&peer, &accept);
            }
        } else if peer.port != 0 {
            let decline = json!({"t":"decline", "id": self.self_id(), "name": self.self_name()});
            let _ = self.talk(&peer, &decline);
        }
        self.persist();
        self.emit();
        Ok(self.state())
    }

    pub fn mark_read(&self, peer_id: &str) -> Result<Value, (String, String)> {
        {
            let mut store = self.store.lock().expect("chat store poisoned");
            if let Some(index) = store.friend_index(peer_id) {
                store.friends[index]["unread"] = json!(0);
            }
        }
        self.persist();
        self.emit();
        Ok(self.state())
    }

    fn self_id(&self) -> String {
        self.store
            .lock()
            .expect("chat store poisoned")
            .self_id
            .clone()
    }

    fn self_name(&self) -> String {
        self.store
            .lock()
            .expect("chat store poisoned")
            .self_name
            .clone()
    }

    fn apply_accept(&self, peer: &Peer) {
        let mut store = self.store.lock().expect("chat store poisoned");
        if store.friend_index(&peer.id).is_none() {
            store.friends.push(json!({
                "id": peer.id,
                "name": peer.name,
                "addedMs": now_ms(),
                "unread": 0,
            }));
        }
        if let Some(index) = store.pending_index(&peer.id) {
            store.pending.remove(index);
        }
        store.peers.insert(peer.id.clone(), peer.clone());
    }

    fn resolve_endpoint(&self, endpoint: &str) -> Result<Peer, (String, String)> {
        let trimmed = endpoint.trim();
        let (host, port_text) = trimmed.rsplit_once(':').ok_or_else(|| {
            (
                "chat_bad_endpoint".to_owned(),
                "Use host:port of the other OpenNOW".to_owned(),
            )
        })?;
        let port: u16 = port_text.parse().map_err(|_| {
            (
                "chat_bad_endpoint".to_owned(),
                "Port must be a number".to_owned(),
            )
        })?;
        if host.is_empty() || port == 0 {
            return Err((
                "chat_bad_endpoint".to_owned(),
                "Incomplete host:port".to_owned(),
            ));
        }
        let probe = Peer {
            id: String::new(),
            name: String::new(),
            host: host.to_owned(),
            port,
            seen_ms: now_ms(),
            lan: true,
        };
        let reply = self.talk(&probe, &json!({"t":"who"}))?;
        if reply["t"].as_str() != Some("who") || reply["id"].as_str().unwrap_or("").is_empty() {
            return Err((
                "chat_bad_endpoint".to_owned(),
                "No OpenNOW chat answered there".to_owned(),
            ));
        }
        Ok(Peer {
            id: reply["id"].as_str().unwrap_or("").to_owned(),
            name: reply["name"]
                .as_str()
                .unwrap_or("OpenNOW friend")
                .to_owned(),
            host,
            port,
            seen_ms: now_ms(),
            lan: true,
        })
    }

    fn deliver(&self, peer: &Peer, message: &Value) -> bool {
        if peer.port == 0 {
            return false;
        }
        let envelope = json!({
            "t": "msg",
            "id": message["id"],
            "from": self.self_id(),
            "name": self.self_name(),
            "text": message["text"],
            "tsMs": message["tsMs"],
        });
        match self.talk(peer, &envelope) {
            Ok(reply) => reply["t"].as_str() == Some("ack") && reply["id"] == message["id"],
            Err(_) => false,
        }
    }

    fn talk(&self, peer: &Peer, payload: &Value) -> Result<Value, (String, String)> {
        talk_to(peer, payload)
    }

    fn spawn_listener(&self, listener: TcpListener) {
        let store = Arc::clone(&self.store);
        let path = self.path.clone();
        let events = self.events.clone();
        let stopped = Arc::clone(&self.stopped);
        let port = self.port;
        let _ = thread::Builder::new()
            .name("opennow-chat-listener".to_owned())
            .spawn(move || {
                for incoming in listener.incoming() {
                    if stopped.load(Ordering::Relaxed) {
                        break;
                    }
                    let Ok(mut stream) = incoming else { continue };
                    let _ = stream.set_read_timeout(Some(Duration::from_millis(2_000)));
                    let mut line = String::new();
                    let mut reader = BufReader::new(&mut stream);
                    if reader.read_line(&mut line).is_err()
                        || line.is_empty()
                        || line.len() as u64 > MAX_LINE_BYTES
                    {
                        continue;
                    }
                    let Ok(payload) = serde_json::from_str::<Value>(line.trim()) else {
                        continue;
                    };
                    let reply = handle_incoming(&store, &path, &events, port, &payload);
                    if let Ok(mut encoded) = serde_json::to_string(&reply) {
                        encoded.push('\n');
                        let _ = stream.write_all(encoded.as_bytes());
                    }
                }
            });
    }

    fn spawn_beacon(&self) {
        let store = Arc::clone(&self.store);
        let path = self.path.clone();
        let events = self.events.clone();
        let stopped = Arc::clone(&self.stopped);
        let port = self.port;
        let _ = thread::Builder::new()
            .name("opennow-chat-beacon".to_owned())
            .spawn(move || {
                let directory = std::env::temp_dir().join(DISCOVERY_DIR);
                let _ = std::fs::create_dir_all(&directory);
                let udp = UdpSocket::bind(format!("0.0.0.0:{BEACON_PORT}"))
                    .or_else(|_| UdpSocket::bind("0.0.0.0:0"))
                    .ok();
                if let Some(socket) = &udp {
                    let _ = socket.set_broadcast(true);
                    let _ = socket.set_read_timeout(Some(Duration::from_millis(150)));
                }
                let mut signature = String::new();
                while !stopped.load(Ordering::Relaxed) {
                    let changed = beacon_tick(&store, &path, &directory, udp.as_ref(), port);
                    if changed != signature {
                        signature = changed;
                        let state = {
                            let store = store.lock().expect("chat store poisoned");
                            Self::state_value(&store, port)
                        };
                        let _ = events
                            .send(json!({"type":"event", "name":"chat.changed", "payload": state}));
                    }
                    thread::sleep(Duration::from_millis(1_500));
                }
            });
    }
}

impl Drop for ChatService {
    fn drop(&mut self) {
        self.stopped.store(true, Ordering::Relaxed);
    }
}

fn handle_incoming(
    store: &Arc<Mutex<Store>>,
    path: &Path,
    events: &mpsc::Sender<Value>,
    port: u16,
    payload: &Value,
) -> Value {
    let kind = payload["t"].as_str().unwrap_or("");
    let peer_id = payload["id"].as_str().unwrap_or("");
    let peer_name = payload["name"].as_str().unwrap_or("OpenNOW friend");
    if peer_id.is_empty() && kind != "who" {
        return json!({"t":"error"});
    }
    match kind {
        "who" => {
            let store = store.lock().expect("chat store poisoned");
            json!({"t":"who", "id": store.self_id, "name": store.self_name})
        }
        "req" => {
            let reply = {
                let mut store = store.lock().expect("chat store poisoned");
                if store.friend_index(peer_id).is_some() {
                    json!({
                        "t": "accept",
                        "id": store.self_id.clone(),
                        "name": store.self_name.clone(),
                    })
                } else {
                    if store.pending_index(peer_id).is_none() {
                        store.pending.push(json!({
                            "id": peer_id, "name": peer_name, "dir": "incoming", "tsMs": now_ms(),
                        }));
                    }
                    store.save(path);
                    json!({"t":"queued"})
                }
            };
            emit_state(store, events, port);
            reply
        }
        "accept" => {
            {
                let mut store = store.lock().expect("chat store poisoned");
                if store.friend_index(peer_id).is_none() {
                    store.friends.push(json!({
                        "id": peer_id, "name": peer_name, "addedMs": now_ms(), "unread": 0,
                    }));
                }
                if let Some(index) = store.pending_index(peer_id) {
                    store.pending.remove(index);
                }
                store.save(path);
            }
            emit_state(store, events, port);
            json!({"t":"ok"})
        }
        "decline" => {
            {
                let mut store = store.lock().expect("chat store poisoned");
                if let Some(index) = store.pending_index(peer_id) {
                    store.pending.remove(index);
                }
                store.save(path);
            }
            emit_state(store, events, port);
            json!({"t":"ok"})
        }
        "msg" => {
            let text = sanitize_text(payload["text"].as_str().unwrap_or(""));
            let message_id = payload["id"].as_str().unwrap_or("");
            if text.is_empty() || message_id.is_empty() {
                return json!({"t":"error"});
            }
            let accepted = {
                let mut store = store.lock().expect("chat store poisoned");
                let Some(index) = store.friend_index(peer_id) else {
                    return json!({
                        "t": "decline",
                        "id": store.self_id.clone(),
                        "name": store.self_name.clone(),
                    });
                };
                let known = store
                    .threads
                    .get(peer_id)
                    .map(|list| {
                        list.iter()
                            .any(|message| message["id"].as_str() == Some(message_id))
                    })
                    .unwrap_or(false);
                if known {
                    true
                } else {
                    store
                        .threads
                        .entry(peer_id.to_owned())
                        .or_default()
                        .push(json!({
                            "id": message_id,
                            "peerId": peer_id,
                            "mine": false,
                            "text": text.clone(),
                            "tsMs": payload["tsMs"].as_u64().unwrap_or_else(now_ms),
                            "delivered": true,
                        }));
                    let unread = store.friends[index]["unread"].as_u64().unwrap_or(0) + 1;
                    store.friends[index]["unread"] = json!(unread);
                    store.last_incoming = json!({
                        "peerId": peer_id,
                        "peerName": peer_name,
                        "text": text,
                        "tsMs": now_ms(),
                    });
                    store.save(path);
                    true
                }
            };
            if accepted {
                emit_state(store, events, port);
            }
            json!({"t":"ack", "id": message_id})
        }
        _ => json!({"t":"error"}),
    }
}

fn emit_state(store: &Arc<Mutex<Store>>, events: &mpsc::Sender<Value>, port: u16) {
    let store = store.lock().expect("chat store poisoned");
    let _ = events.send(json!({
        "type": "event",
        "name": "chat.changed",
        "payload": ChatService::state_value(&store, port),
    }));
}

/// One discovery + flush pass. Returns a signature of what the shell sees so
/// the beacon thread only emits events when presence or delivery moved.
fn beacon_tick(
    store: &Arc<Mutex<Store>>,
    path: &Path,
    directory: &Path,
    udp: Option<&UdpSocket>,
    port: u16,
) -> String {
    let now = now_ms();
    let (self_id, self_name) = {
        let store = store.lock().expect("chat store poisoned");
        (store.self_id.clone(), store.self_name.clone())
    };
    if let Ok(entries) = std::fs::read_dir(directory) {
        for entry in entries.flatten() {
            let file = entry.path();
            if file.extension().and_then(|value| value.to_str()) != Some("json") {
                continue;
            }
            let is_self = file
                .file_stem()
                .and_then(|value| value.to_str())
                .map(|stem| stem == self_id)
                .unwrap_or(false);
            if is_self {
                continue;
            }
            let fresh = std::fs::metadata(&file)
                .and_then(|metadata| metadata.modified())
                .map(|modified| {
                    modified
                        .elapsed()
                        .map(|elapsed| elapsed.as_millis() < 10_000u128)
                        .unwrap_or(false)
                })
                .unwrap_or(false);
            if !fresh {
                let _ = std::fs::remove_file(&file);
                continue;
            }
            if let Ok(bytes) = std::fs::read(&file) {
                if let Ok(raw) = serde_json::from_slice::<Value>(&bytes) {
                    merge_peer(store, &raw, "127.0.0.1", now, false);
                }
            }
        }
    }
    let mut beacon = json!({"id": self_id, "name": self_name, "port": port, "ts": now});
    beacon["t"] = json!("beacon");
    let own_file = directory.join(format!("{self_id}.json"));
    if let Ok(bytes) = serde_json::to_vec(&beacon) {
        let _ = std::fs::write(&own_file, &bytes);
        if let Some(socket) = udp {
            for target in ["255.255.255.255", "127.0.0.1"] {
                if let Ok(address) = format!("{target}:{BEACON_PORT}").parse::<SocketAddr>() {
                    let _ = socket.send_to(&bytes, address);
                }
            }
            let mut buffer = [0_u8; 2_048];
            while let Ok((size, from)) = socket.recv_from(&mut buffer) {
                if let Ok(raw) = serde_json::from_slice::<Value>(&buffer[..size]) {
                    if raw["t"].as_str() == Some("beacon") {
                        merge_peer(store, &raw, &from.ip().to_string(), now, true);
                    }
                }
            }
        }
    }
    let jobs = {
        let mut store = store.lock().expect("chat store poisoned");
        store
            .peers
            .retain(|_, peer| now.saturating_sub(peer.seen_ms) < PEER_TIMEOUT_MS);
        store
            .peers
            .values()
            .filter(|peer| now.saturating_sub(peer.seen_ms) < PEER_TIMEOUT_MS)
            .filter_map(|peer| {
                let pending = store
                    .threads
                    .get(&peer.id)
                    .map(|list| {
                        list.iter()
                            .filter(|message| {
                                let mine = message["mine"] == json!(true);
                                let undelivered = message["delivered"] != json!(true);
                                let stamp = message["tsMs"].as_u64().unwrap_or(now);
                                mine && undelivered && now.saturating_sub(stamp) < PENDING_TTL_MS
                            })
                            .cloned()
                            .collect::<Vec<Value>>()
                    })
                    .unwrap_or_default();
                if pending.is_empty() {
                    None
                } else {
                    Some((peer.clone(), pending))
                }
            })
            .collect::<Vec<(Peer, Vec<Value>)>>()
    };
    let mut flushed = 0_u32;
    for (peer, pending) in jobs {
        for message in pending {
            let envelope = json!({
                "t": "msg",
                "id": message["id"],
                "from": self_id,
                "name": self_name,
                "text": message["text"],
                "tsMs": message["tsMs"],
            });
            let delivered = talk_to(&peer, &envelope)
                .map(|reply| reply["t"].as_str() == Some("ack") && reply["id"] == message["id"])
                .unwrap_or(false);
            if delivered {
                flushed += 1;
                let mut store = store.lock().expect("chat store poisoned");
                if let Some(list) = store.threads.get_mut(&peer.id) {
                    if let Some(entry) = list.iter_mut().find(|entry| entry["id"] == message["id"])
                    {
                        entry["delivered"] = json!(true);
                    }
                }
                store.save(path);
            }
        }
    }
    let store = store.lock().expect("chat store poisoned");
    let mut parts = store
        .peers
        .values()
        .map(|peer| {
            let online = now.saturating_sub(peer.seen_ms) < PEER_TIMEOUT_MS;
            format!("{}:{}:{}", peer.id, peer.port, online as u8)
        })
        .collect::<Vec<String>>();
    parts.sort();
    parts.push(format!("flushed={flushed}"));
    parts.join(",")
}

fn merge_peer(store: &Arc<Mutex<Store>>, raw: &Value, host: &str, now: u64, lan: bool) {
    let id = raw["id"].as_str().unwrap_or("");
    let port = raw["port"].as_u64().unwrap_or(0) as u16;
    if id.is_empty() || port == 0 {
        return;
    }
    let mut store = store.lock().expect("chat store poisoned");
    if store.self_id == id {
        return;
    }
    let entry = store.peers.entry(id.to_owned()).or_default();
    entry.id = id.to_owned();
    entry.name = raw["name"].as_str().unwrap_or("OpenNOW").to_owned();
    if lan || entry.host.is_empty() {
        entry.host = host.to_owned();
        entry.lan = lan;
    }
    entry.port = port;
    entry.seen_ms = now;
}

fn talk_to(peer: &Peer, payload: &Value) -> Result<Value, (String, String)> {
    let address = resolve_address(&peer.host, peer.port)
        .map_err(|_| ("chat_bad_host".to_owned(), "Unreachable host".to_owned()))?;
    let mut stream =
        TcpStream::connect_timeout(&address, Duration::from_millis(CONNECT_TIMEOUT_MS)).map_err(
            |_| {
                (
                    "chat_offline".to_owned(),
                    "That OpenNOW is not reachable right now".to_owned(),
                )
            },
        )?;
    stream
        .set_read_timeout(Some(Duration::from_millis(ACK_TIMEOUT_MS)))
        .map_err(|error| (error.to_string(), error.to_string()))?;
    let mut line =
        serde_json::to_string(payload).map_err(|error| (error.to_string(), error.to_string()))?;
    line.push('\n');
    stream.write_all(line.as_bytes()).map_err(|_| {
        (
            "chat_offline".to_owned(),
            "The connection closed while sending".to_owned(),
        )
    })?;
    let mut reply = String::new();
    BufReader::new(&mut stream)
        .read_line(&mut reply)
        .map_err(|_| {
            (
                "chat_offline".to_owned(),
                "No reply from the other OpenNOW".to_owned(),
            )
        })?;
    if reply.len() as u64 > MAX_LINE_BYTES {
        return Err((
            "chat_overflow".to_owned(),
            "Reply exceeded the size limit".to_owned(),
        ));
    }
    serde_json::from_str::<Value>(reply.trim()).map_err(|_| {
        (
            "chat_bad_reply".to_owned(),
            "The other OpenNOW answered garbage".to_owned(),
        )
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitize_trims_and_caps_text() {
        assert_eq!(sanitize_text("   hi there\n\n "), "hi there");
        let wall = "a".repeat(MAX_TEXT_CHARS + 500);
        assert_eq!(sanitize_text(&wall).len(), MAX_TEXT_CHARS);
        assert_eq!(sanitize_text("   "), "");
    }

    #[test]
    fn store_round_trips_through_chat_json() {
        let directory = std::env::temp_dir().join(format!("opennow-chat-test-{}", now_ms()));
        std::fs::create_dir_all(&directory).expect("test directory");
        let path = directory.join("chat.json");
        {
            let mut store = Store::load(&path);
            assert!(!store.self_id.is_empty());
            store.self_name = "Tester".to_owned();
            store
                .friends
                .push(json!({"id":"peer-1","name":"Peer","addedMs":1,"unread":2}));
            store.threads.insert(
                "peer-1".to_owned(),
                vec![json!({
                    "id": "msg-1",
                    "peerId": "peer-1",
                    "mine": false,
                    "text": "hello",
                    "tsMs": 2,
                    "delivered": true,
                })],
            );
            store.save(&path);
        }
        let loaded = Store::load(&path);
        assert_eq!(loaded.self_name, "Tester");
        assert_eq!(loaded.friends.len(), 1);
        assert_eq!(loaded.unread_total(), 2);
        assert_eq!(loaded.threads["peer-1"][0]["text"], json!("hello"));
        let _ = std::fs::remove_dir_all(&directory);
    }

    #[test]
    fn state_reports_friends_peers_and_unread() {
        let mut store = Store::default();
        store.self_id = "me".to_owned();
        store.self_name = "Me".to_owned();
        store
            .friends
            .push(json!({"id":"peer-1","name":"Peer","addedMs":1,"unread":1}));
        store.peers.insert(
            "peer-1".to_owned(),
            Peer {
                id: "peer-1".to_owned(),
                name: "Peer".to_owned(),
                host: "127.0.0.1".to_owned(),
                port: 1234,
                seen_ms: now_ms(),
                lan: false,
            },
        );
        let state = ChatService::state_value(&store, 4321);
        assert_eq!(state["unreadTotal"], json!(1));
        assert_eq!(state["friends"][0]["online"], json!(true));
        assert_eq!(state["peers"][0]["port"], json!(1234));
        assert_eq!(state["port"], json!(4321));
    }

    #[test]
    fn incoming_message_from_stranger_is_declined() {
        let store = Arc::new(Mutex::new(Store::default()));
        let path = std::env::temp_dir().join("opennow-chat-noop.json");
        let (sender, _receiver) = mpsc::channel();
        let reply = handle_incoming(
            &store,
            &path,
            &sender,
            0,
            &json!({
                "t": "msg",
                "id": "msg-x",
                "from": "stranger",
                "name": "Stranger",
                "text": "hey",
                "tsMs": 1,
            }),
        );
        assert_eq!(reply["t"], json!("decline"));
    }
}
