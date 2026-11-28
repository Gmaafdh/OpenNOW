"""Friends chat: the surface, the shell wiring and the core transport stay wired.

The chat section of the Friends tab is backed by the core chat service
(discovery + direct peer transport + store-and-forward). These pins keep the
surface object names, the shell state wiring, the message toast and the nav
badge from silently regressing.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QT = ROOT / "opennow-qt"
SCREEN = (QT / "qml" / "desktop" / "friends" / "DesktopFriendsScreen.qml").read_text(encoding="utf-8")
TOAST = (QT / "qml" / "desktop" / "shell" / "DesktopChatToast.qml").read_text(encoding="utf-8")
APP = (QT / "qml" / "desktop" / "shell" / "DesktopApp.qml").read_text(encoding="utf-8")
NAV = (QT / "qml" / "components" / "NavPill.qml").read_text(encoding="utf-8")
STORE = (QT / "qml" / "state" / "ShellStore.qml").read_text(encoding="utf-8")
CORE_MAIN = (ROOT / "native" / "opennow-core" / "src" / "main.rs").read_text(encoding="utf-8")
CORE_CHAT = (ROOT / "native" / "opennow-core" / "src" / "chat.rs").read_text(encoding="utf-8")
LOCALES = json.loads((ROOT / "locales" / "en.json").read_text(encoding="utf-8"))


class FriendsChatSurfaceTest(unittest.TestCase):
    def test_friends_screen_exposes_the_chat_surface(self) -> None:
        for name in ["desktopFriendsScreen", "friendsList", "chatThread", "chatComposer",
                     "chatSend", "addFriendButton", "chatPeerList", "chatPendingList",
                     "friendEndpointField"]:
            self.assertIn(f'objectName: "{name}"', SCREEN)
        self.assertIn("ShellStore.chatSend(", SCREEN)
        self.assertIn("ShellStore.chatMarkRead(", SCREEN)
        self.assertIn("ShellStore.chatRespond(", SCREEN)
        self.assertIn("ShellStore.chatRequestFriend(", SCREEN)

    def test_message_toast_is_hosted_and_wired(self) -> None:
        self.assertIn("function onChatMessageReceived(peerName, preview)", TOAST)
        self.assertIn("function onChatFriendRequestReceived(peerName)", TOAST)
        self.assertIn('objectName: "desktopChatToast"', APP)
        self.assertIn("DesktopChatToast {", APP)

    def test_nav_pill_shows_the_unread_badge(self) -> None:
        self.assertIn('visible: modelData.route === "friends" && ShellStore.chatUnread > 0', NAV)

    def test_shell_store_keeps_chat_state_and_events(self) -> None:
        self.assertIn("property var chatState", STORE)
        self.assertIn("readonly property int chatUnread", STORE)
        self.assertIn("signal chatMessageReceived(string peerName, string preview)", STORE)
        self.assertIn('CoreClient.request("chat.send"', STORE)
        self.assertIn('name === "chat.changed"', STORE)
        self.assertIn("function acceptChatState(state)", STORE)


class FriendsChatCoreTest(unittest.TestCase):
    def test_core_exposes_chat_methods(self) -> None:
        for method in ['"chat.state"', '"chat.start"', '"chat.send"',
                       '"chat.request"', '"chat.respond"', '"chat.markRead"']:
            self.assertIn(method, CORE_MAIN)
        self.assertIn('"chat.v1"', CORE_MAIN)

    def test_core_transport_is_store_and_forward(self) -> None:
        self.assertIn("opennow-chat-peers", CORE_CHAT)
        self.assertIn("fn beacon_tick", CORE_CHAT)
        self.assertIn("fn talk_to", CORE_CHAT)
        self.assertIn("PENDING_TTL_MS", CORE_CHAT)
        self.assertIn('json!({"t":"ack"', CORE_CHAT)

    def test_incoming_frames_name_their_sender(self) -> None:
        # A "msg" frame carries the message id in "id" and the sender in "from";
        # keying the thread off "id" made every message from a real friend look
        # like a stranger, so the listener declined all of them.
        self.assertIn('let peer_id = if kind == "msg" {', CORE_CHAT)
        self.assertIn('payload["from"].as_str()', CORE_CHAT)
        # Frames announce the listening port, and the listener records where the
        # frame came from, so a peer that only ever receives from us still learns
        # how to dial back and accept a friend request.
        self.assertIn('"port": self.port,', CORE_CHAT)
        self.assertIn("remote: &str,", CORE_CHAT)
        self.assertIn(".peer_addr()", CORE_CHAT)
        self.assertIn("fn merge_peer(", CORE_CHAT)

    def test_pending_requests_survive_a_restart(self) -> None:
        self.assertIn('"pending": self.pending.clone(),', CORE_CHAT)
        self.assertIn('raw["pending"].as_array()', CORE_CHAT)

    def test_chat_strings_are_translated(self) -> None:
        values = set(LOCALES["desktopQt"].values())
        for text in ["Write a message…", "Message from %1", "Add a friend",
                     "No messages yet. Say hi!", "Friend request"]:
            self.assertIn(text, values)


if __name__ == "__main__":
    unittest.main()
