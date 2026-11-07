import { createServer as createHttpServer } from 'node:http';
import { randomBytes, scrypt as scryptCallback, createHash, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { mkdir, readFile, rename, chmod, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const scrypt = promisify(scryptCallback);
const BODY_LIMIT = 32 * 1024;
const SESSION_MS = 30 * 24 * 60 * 60 * 1000;
const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/;
const DEFAULT_PRIVACY = Object.freeze({ sharePresence: false, shareActivity: false, shareHistory: false });

const json = (res, status, body) => {
  const bytes = Buffer.from(JSON.stringify(body));
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': bytes.length,
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
    'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
  });
  res.end(bytes);
};
const fail = (res, status, message) => json(res, status, { error: message });
const sha256 = value => createHash('sha256').update(value).digest('hex');
const normalizeUsername = value => String(value || '').trim().toLowerCase();
const safeEqualHex = (left, right) => {
  const a = Buffer.from(String(left), 'hex');
  const b = Buffer.from(String(right), 'hex');
  return a.length === b.length && a.length > 0 && timingSafeEqual(a, b);
};
const conversationKey = (a, b) => [a, b].sort().join(':');

function publicProfile(user) {
  const presenceVisible = user.privacy.sharePresence;
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    friendCode: user.friendCode,
    nvidiaDisplayName: user.nvidiaDisplayName,
    nvidiaDisplayNameVerified: false,
    online: presenceVisible && user.presence.status !== 'offline'
      && Date.now() - user.presence.lastSeen < 50_000,
    status: presenceVisible ? user.presence.status : 'offline',
    activity: user.privacy.shareActivity && presenceVisible ? user.presence.activity : null,
    recentGames: user.privacy.shareHistory ? user.history.slice(0, 10) : [],
    lastSeen: presenceVisible ? user.presence.lastSeen : null,
  };
}

async function readBody(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > BODY_LIMIT) throw Object.assign(new Error('Request body is too large'), { status: 413 });
    chunks.push(chunk);
  }
  if (!size) return {};
  try {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('Expected a JSON object');
    return body;
  } catch {
    throw Object.assign(new Error('Invalid JSON request body'), { status: 400 });
  }
}

export function createSocialServer({ dataDir = process.env.DATA_DIR || './data', host = process.env.HOST || '0.0.0.0' } = {}) {
  const databasePath = path.resolve(dataDir, 'social-db.json');
  let db = { users: {}, sessions: {}, conversations: {}, nextMessageId: 1 };
  let persistTail = Promise.resolve();
  const rateWindows = new Map();

  async function persist() {
    const snapshot = JSON.stringify(db);
    const write = persistTail.then(async () => {
      await mkdir(path.dirname(databasePath), { recursive: true, mode: 0o700 });
      const temporary = `${databasePath}.${process.pid}.${randomBytes(4).toString('hex')}.tmp`;
      await writeFile(temporary, snapshot, { mode: 0o600 });
      await chmod(temporary, 0o600);
      await rename(temporary, databasePath);
    });
    persistTail = write.catch(() => {});
    return write;
  }

  async function load() {
    await mkdir(path.dirname(databasePath), { recursive: true, mode: 0o700 });
    try {
      const parsed = JSON.parse(await readFile(databasePath, 'utf8'));
      db = {
        users: parsed.users && typeof parsed.users === 'object' ? parsed.users : {},
        sessions: parsed.sessions && typeof parsed.sessions === 'object' ? parsed.sessions : {},
        conversations: parsed.conversations && typeof parsed.conversations === 'object' ? parsed.conversations : {},
        nextMessageId: Number.isSafeInteger(parsed.nextMessageId) ? parsed.nextMessageId : 1,
      };
      for (const user of Object.values(db.users)) {
        user.privacy = { ...DEFAULT_PRIVACY, ...(user.privacy || {}) };
        user.presence ||= { status: 'offline', activity: null, lastSeen: 0, activityStartedAt: 0 };
        user.history ||= [];
        user.friends ||= [];
        user.requestsSent ||= [];
        user.requestsReceived ||= [];
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }

  function limited(key, maximum, intervalMs) {
    const now = Date.now();
    if (rateWindows.size > 10_000) {
      for (const [rateKey, value] of rateWindows)
        if (now - value.startedAt > 3_600_000) rateWindows.delete(rateKey);
    }
    const entry = rateWindows.get(key);
    if (!entry || now - entry.startedAt >= intervalMs) {
      rateWindows.set(key, { startedAt: now, count: 1 });
      return false;
    }
    entry.count += 1;
    return entry.count > maximum;
  }

  function clientAddress(req) {
    if (process.env.TRUST_PROXY === '1') {
      const forwarded = req.headers['x-forwarded-for'];
      if (typeof forwarded === 'string' && forwarded.length < 512) return forwarded.split(',')[0].trim();
    }
    return req.socket.remoteAddress || 'unknown';
  }

  function authenticated(req) {
    const header = String(req.headers.authorization || '');
    if (!header.startsWith('Bearer ')) return null;
    const token = header.slice(7);
    if (token.length < 32 || token.length > 256) return null;
    const key = sha256(token);
    const session = db.sessions[key];
    if (!session || session.expiresAt <= Date.now()) return null;
    const user = db.users[session.userId];
    return user ? { user, tokenKey: key } : null;
  }

  function requireAuth(req, res) {
    const auth = authenticated(req);
    if (!auth) fail(res, 401, 'Sign in to your OpenNOW social account');
    return auth;
  }

  function settleActivity(user, now = Date.now()) {
    const active = user.presence.activity;
    const started = Number(user.presence.activityStartedAt || 0);
    if (user.privacy.shareHistory && active && started > 0 && active.gameId) {
      const elapsed = Math.max(0, Math.min(now - started, 60_000));
      if (elapsed >= 1000) {
        let record = user.history.find(item => item.gameId === active.gameId);
        if (!record) {
          record = { gameId: active.gameId, gameName: active.gameName, playTimeMs: 0, lastPlayedAt: now };
          user.history.unshift(record);
        }
        record.gameName = active.gameName;
        record.playTimeMs += elapsed;
        record.lastPlayedAt = now;
        user.history.sort((a, b) => b.lastPlayedAt - a.lastPlayedAt);
        if (user.history.length > 500) user.history.length = 500;
      }
    }
    user.presence.activityStartedAt = now;
  }

  const server = createHttpServer(async (req, res) => {
    try {
      if (!['GET', 'POST', 'PUT', 'DELETE'].includes(req.method)) {
        res.setHeader('allow', 'GET, POST, PUT, DELETE');
        return fail(res, 405, 'Method not allowed');
      }
      const url = new URL(req.url, 'http://opennow.invalid');
      const route = url.pathname.replace(/\/+$/, '') || '/';
      if (req.method === 'GET' && route === '/healthz') return json(res, 200, { ok: true, service: 'opennow-social' });
      if (!route.startsWith('/v1/')) return fail(res, 404, 'Endpoint not found');

      if (req.method === 'POST' && (route === '/v1/auth/register' || route === '/v1/auth/login')) {
        const ip = clientAddress(req);
        if (limited(`auth:${ip}`, route.endsWith('register') ? 6 : 12, route.endsWith('register') ? 3_600_000 : 900_000))
          return fail(res, 429, 'Too many sign-in attempts; wait and try again');
        const body = await readBody(req);
        const username = String(body.username || '').trim();
        const normalized = normalizeUsername(username);
        const password = String(body.password || '');
        if (route.endsWith('register')) {
          if (!USERNAME_RE.test(username)) return fail(res, 400, 'Username must be 3–20 letters, numbers, or underscores');
          if (password.length < 12 || password.length > 256) return fail(res, 400, 'Password must be 12–256 characters');
          if (Object.values(db.users).some(user => user.usernameNormalized === normalized)) return fail(res, 409, 'That OpenNOW username is already taken');
          const salt = randomBytes(16).toString('hex');
          const passwordHash = Buffer.from(await scrypt(password, salt, 64)).toString('hex');
          if (Object.values(db.users).some(user => user.usernameNormalized === normalized))
            return fail(res, 409, 'That OpenNOW username is already taken');
          const id = randomBytes(16).toString('hex');
          let friendCode;
          do { friendCode = `ON-${randomBytes(6).toString('hex').toUpperCase()}`; }
          while (Object.values(db.users).some(user => user.friendCode === friendCode));
          const nvidiaDisplayName = String(body.nvidiaDisplayName || '').trim().slice(0, 40);
          const user = {
            id, username, usernameNormalized: normalized,
            displayName: String(body.displayName || username).trim().slice(0, 40) || username,
            friendCode, nvidiaDisplayName, passwordSalt: salt, passwordHash,
            privacy: { ...DEFAULT_PRIVACY }, friends: [], requestsSent: [], requestsReceived: [], history: [],
            presence: { status: 'offline', activity: null, lastSeen: 0, activityStartedAt: 0 },
          };
          user.presence.status = 'online';
          user.presence.lastSeen = Date.now();
          user.presence.activityStartedAt = user.presence.lastSeen;
          db.users[id] = user;
          const token = randomBytes(32).toString('base64url');
          db.sessions[sha256(token)] = { userId: id, expiresAt: Date.now() + SESSION_MS };
          await persist();
          return json(res, 201, { token, user: publicProfile(user), privacy: user.privacy });
        }
        const user = Object.values(db.users).find(item => item.usernameNormalized === normalized);
        const fallbackSalt = '00000000000000000000000000000000';
        const candidate = Buffer.from(await scrypt(password, user?.passwordSalt || fallbackSalt, 64)).toString('hex');
        if (!user || !safeEqualHex(candidate, user.passwordHash)) return fail(res, 401, 'Username or password is incorrect');
        const token = randomBytes(32).toString('base64url');
        db.sessions[sha256(token)] = { userId: user.id, expiresAt: Date.now() + SESSION_MS };
        const now = Date.now();
        settleActivity(user, now);
        user.presence.status = 'online';
        user.presence.lastSeen = now;
        user.presence.activityStartedAt = now;
        await persist();
        return json(res, 200, { token, user: publicProfile(user), privacy: user.privacy });
      }

      const auth = requireAuth(req, res);
      if (!auth) return;
      const { user } = auth;

      if (req.method === 'POST' && route === '/v1/auth/logout') {
        settleActivity(user);
        user.presence.activity = null;
        user.presence.status = 'offline';
        user.presence.lastSeen = Date.now();
        delete db.sessions[auth.tokenKey];
        await persist();
        return json(res, 200, { ok: true });
      }
      if (req.method === 'GET' && route === '/v1/me')
        return json(res, 200, { user: publicProfile(user), privacy: user.privacy });

      if (req.method === 'PUT' && route === '/v1/profile') {
        const body = await readBody(req);
        if (Object.hasOwn(body, 'nvidiaDisplayName'))
          user.nvidiaDisplayName = String(body.nvidiaDisplayName || '').trim().slice(0, 40);
        await persist();
        return json(res, 200, { user: publicProfile(user) });
      }

      if (req.method === 'PUT' && route === '/v1/privacy') {
        const body = await readBody(req);
        const wasSharingHistory = user.privacy.shareHistory;
        const willShareHistory = typeof body.shareHistory === 'boolean'
          ? body.shareHistory : wasSharingHistory;
        const now = Date.now();
        if (wasSharingHistory && !willShareHistory) settleActivity(user, now);
        for (const key of ['sharePresence', 'shareActivity', 'shareHistory'])
          if (typeof body[key] === 'boolean') user.privacy[key] = body[key];
        if (!wasSharingHistory && willShareHistory)
          user.presence.activityStartedAt = now;
        await persist();
        return json(res, 200, { privacy: user.privacy });
      }

      if (req.method === 'PUT' && route === '/v1/presence') {
        const body = await readBody(req);
        const now = Date.now();
        settleActivity(user, now);
        const mayTrackActivity = user.privacy.shareActivity || user.privacy.shareHistory;
        const candidate = mayTrackActivity && body.activity && typeof body.activity === 'object' ? body.activity : null;
        let activity = null;
        if (candidate && String(candidate.gameId || '').trim() && String(candidate.gameName || '').trim()) {
          activity = {
            gameId: String(candidate.gameId).trim().slice(0, 100),
            gameName: String(candidate.gameName).trim().slice(0, 100),
          };
        }
        user.presence.activity = activity;
        user.presence.status = body.status === 'away' ? 'away' : 'online';
        user.presence.lastSeen = now;
        user.presence.activityStartedAt = now;
        await persist();
        return json(res, 200, { ok: true });
      }

      if (req.method === 'GET' && route === '/v1/friends') {
        const friends = user.friends.map(id => db.users[id]).filter(Boolean).map(friend => publicProfile(friend));
        return json(res, 200, { friends });
      }
      if (req.method === 'GET' && route === '/v1/friend-requests') {
        const requests = user.requestsReceived.map(id => db.users[id]).filter(Boolean).map(requester => ({
          id: requester.id, username: requester.username, displayName: requester.displayName,
          friendCode: requester.friendCode, nvidiaDisplayName: requester.nvidiaDisplayName,
          nvidiaDisplayNameVerified: false,
        }));
        return json(res, 200, { requests });
      }
      if (req.method === 'POST' && route === '/v1/friend-requests') {
        if (limited(`friend-request:${user.id}`, 20, 3_600_000))
          return fail(res, 429, 'Too many friend requests; wait and try again');
        const body = await readBody(req);
        const identifier = String(body.identifier || '').trim();
        if (!identifier || identifier.length > 64) return fail(res, 400, 'Enter a friend code or OpenNOW username');
        const normalizedIdentifier = normalizeUsername(identifier);
        const target = Object.values(db.users).find(item => item.friendCode.toLowerCase() === identifier.toLowerCase()
          || item.usernameNormalized === normalizedIdentifier);
        if (!target) return fail(res, 404, 'No OpenNOW account matched that username or friend code');
        if (target.id === user.id) return fail(res, 400, 'You cannot add yourself');
        if (user.friends.includes(target.id)) return fail(res, 409, 'You are already friends');
        if (user.requestsSent.includes(target.id)) return fail(res, 409, 'A friend request is already pending');
        if (user.requestsReceived.includes(target.id)) return fail(res, 409, 'This person already requested you; accept their request instead');
        target.requestsReceived.push(user.id);
        user.requestsSent.push(target.id);
        await persist();
        return json(res, 201, { ok: true, message: 'Friend request sent' });
      }

      const requestMatch = route.match(/^\/v1\/friend-requests\/([a-f0-9]{32})\/(accept|reject)$/);
      if (req.method === 'POST' && requestMatch) {
        const [, otherId, decision] = requestMatch;
        const other = db.users[otherId];
        if (!other || !user.requestsReceived.includes(otherId)) return fail(res, 404, 'Friend request not found');
        user.requestsReceived = user.requestsReceived.filter(id => id !== otherId);
        other.requestsSent = other.requestsSent.filter(id => id !== user.id);
        if (decision === 'accept') {
          if (!user.friends.includes(otherId)) user.friends.push(otherId);
          if (!other.friends.includes(user.id)) other.friends.push(user.id);
        }
        await persist();
        return json(res, 200, { ok: true });
      }

      const messageMatch = route.match(/^\/v1\/friends\/([a-f0-9]{32})\/messages$/);
      if (messageMatch) {
        const otherId = messageMatch[1];
        if (!user.friends.includes(otherId)) return fail(res, 403, 'Chat is available only between accepted friends');
        const other = db.users[otherId];
        if (!other) return fail(res, 404, 'Friend account not found');
        const key = conversationKey(user.id, otherId);
        const conversation = db.conversations[key] || [];
        if (req.method === 'GET') {
          const after = Number(url.searchParams.get('after') || 0);
          const messages = (after > 0 ? conversation.filter(message => message.id > after) : conversation.slice(-100));
          return json(res, 200, { messages });
        }
        if (req.method === 'POST') {
          if (limited(`chat:${user.id}`, 30, 60_000)) return fail(res, 429, 'You are sending messages too quickly');
          const body = await readBody(req);
          const text = String(body.text || '').trim();
          if (!text || text.length > 2000) return fail(res, 400, 'Message must contain 1–2000 characters');
          const message = { id: db.nextMessageId++, senderId: user.id, text, sentAt: Date.now() };
          conversation.push(message);
          if (conversation.length > 1000) conversation.splice(0, conversation.length - 1000);
          db.conversations[key] = conversation;
          await persist();
          return json(res, 201, { message });
        }
      }

      return fail(res, 404, 'Endpoint not found');
    } catch (error) {
      if (res.headersSent) return res.destroy();
      return fail(res, error.status || 500, error.status ? error.message : 'The social service could not complete the request');
    }
  });

  return {
    server,
    async listen(port = Number(process.env.PORT || 8787)) {
      await load();
      await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(port, host, () => { server.removeListener('error', reject); resolve(); });
      });
      return server.address();
    },
    async close() {
      if (!server.listening) return;
      await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
      await persistTail;
    },
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const service = createSocialServer();
  service.listen().then(address => {
    console.log(`OpenNOW Social service listening on ${address.address}:${address.port}`);
    console.log('Terminate with SIGINT/SIGTERM; put a TLS reverse proxy in front for public use.');
  }).catch(error => {
    console.error('Could not start OpenNOW Social service:', error.message);
    process.exitCode = 1;
  });
  const stop = () => service.close().finally(() => process.exit(0));
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
}
