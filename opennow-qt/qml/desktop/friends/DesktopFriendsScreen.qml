import QtQuick
import QtQuick.Controls
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopFriendsScreen"
    anchors.fill: parent
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Friends")

    readonly property var chat: ShellStore.chatState || ({})
    readonly property var friends: chat.friends || []
    readonly property var pending: chat.pending || []
    readonly property var peers: chat.peers || []
    readonly property var thread: chat.threads && root.selectedPeer
        ? (chat.threads[root.selectedPeer] || []) : []
    property string selectedPeer: ""
    property bool addOpen: false

    readonly property color panelFill: Theme.lightMode ? "#F2F5FA" : "#E60B1320"
    readonly property color cardFill: Theme.lightMode ? "#F0F3F8" : "#E617202D"

    function selectedFriend() {
        for (const friend of friends)
            if (friend.id === root.selectedPeer)
                return friend
        return null
    }
    function isFriend(peerId) {
        for (const friend of friends)
            if (friend.id === peerId)
                return true
        return false
    }
    function isPending(peerId) {
        for (const entry of pending)
            if (entry.id === peerId)
                return true
        return false
    }
    function discoverablePeers() {
        const rows = []
        for (const peer of peers)
            if (!isFriend(peer.id) && !isPending(peer.id))
                rows.push(peer)
        return rows
    }
    function openConversation(peerId) {
        root.selectedPeer = peerId
        ShellStore.chatMarkRead(peerId)
        Qt.callLater(() => composer.forceActiveFocus())
    }
    function sendCurrent() {
        const text = composer.text.trim()
        if (!root.selectedPeer || text === "")
            return
        ShellStore.chatSend(root.selectedPeer, text)
        composer.text = ""
        composer.forceActiveFocus()
    }

    Row {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        // ── Friends rail ────────────────────────────────────────────
        Rectangle {
            id: rail
            width: 320
            height: parent.height
            radius: 24
            color: root.panelFill
            border.width: 1
            border.color: DesktopTokens.seam

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Friends")
                        color: DesktopTokens.textHigh
                        font.family: DesktopTokens.displayFont
                        font.pixelSize: 24
                        font.weight: Font.Black
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("%1 online").arg(friends.filter(friend => friend.online).length)
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 13
                    }
                }

                DesktopButton {
                    id: addFriendButton
                    objectName: "addFriendButton"
                    width: parent.width
                    text: root.addOpen ? qsTr("Hide adding friends") : qsTr("Add a friend")
                    onClicked: {
                        root.addOpen = !root.addOpen
                        if (root.addOpen)
                            Qt.callLater(() => peerList.forceActiveFocus())
                    }
                }

                Column {
                    id: addPanel
                    visible: root.addOpen
                    width: parent.width
                    spacing: 10

                    Text {
                        width: parent.width
                        text: qsTr("Nearby OpenNOW players")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                    }
                    Item {
                        width: parent.width
                        height: peerList.count === 0 ? 72
                            : Math.min(168, peerList.contentHeight)
                        ListView {
                        id: peerList
                        objectName: "chatPeerList"
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        model: discoverablePeers()
                        Accessible.name: qsTr("Nearby OpenNOW players")
                        delegate: Row {
                            required property var modelData
                            width: peerList.width
                            height: 40
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: peerList.width - 90
                                text: String(modelData.name || qsTr("OpenNOW player"))
                                color: DesktopTokens.textHigh
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            DesktopButton {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 80
                                text: qsTr("Add")
                                onClicked: ShellStore.chatRequestFriend(modelData.id, "")
                            }
                        }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: peerList.count === 0
                            width: parent.width - 16
                            text: qsTr("No one nearby right now. OpenNOW players on this computer or network appear here.")
                            color: DesktopTokens.textMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    Text {
                        width: parent.width
                        text: qsTr("Add by address")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        TextField {
                            id: endpointField
                            objectName: "friendEndpointField"
                            width: parent.width - 90
                            height: 40
                            placeholderText: qsTr("host:port of their OpenNOW")
                            Accessible.name: qsTr("host:port of their OpenNOW")
                            color: DesktopTokens.textHigh
                            placeholderTextColor: DesktopTokens.textMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: 13
                            leftPadding: 12
                            background: Rectangle {
                                radius: 12
                                color: root.cardFill
                                border.width: 1
                                border.color: endpointField.activeFocus ? DesktopTokens.focus : DesktopTokens.seamSoft
                            }
                            Keys.onReturnPressed: addEndpoint.clicked()
                        }
                        DesktopButton {
                            id: addEndpoint
                            width: 80
                            height: 40
                            text: qsTr("Add")
                            onClicked: {
                                const endpoint = endpointField.text.trim()
                                if (endpoint === "")
                                    return
                                ShellStore.chatRequestFriend("", endpoint)
                                endpointField.text = ""
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: pending.length > 0
                    text: qsTr("Friend requests")
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
                ListView {
                    id: pendingList
                    objectName: "chatPendingList"
                    width: parent.width
                    height: Math.min(150, contentHeight)
                    clip: true
                    spacing: 6
                    model: pending
                    Accessible.name: qsTr("Friend requests")
                    delegate: Column {
                        required property var modelData
                        width: pendingList.width
                        spacing: 6
                        Row {
                            width: parent.width
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 170
                                text: modelData.dir === "outgoing"
                                    ? qsTr("Waiting for %1").arg(modelData.name || "")
                                    : String(modelData.name || qsTr("OpenNOW player"))
                                color: DesktopTokens.textHigh
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Row {
                                visible: modelData.dir === "incoming"
                                spacing: 6
                                DesktopButton {
                                    width: 78
                                    text: qsTr("Accept")
                                    primary: true
                                    onClicked: ShellStore.chatRespond(modelData.id, true)
                                }
                                DesktopButton {
                                    width: 78
                                    text: qsTr("Decline")
                                    onClicked: ShellStore.chatRespond(modelData.id, false)
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(120, parent.height - y)
                    ListView {
                    id: friendsList
                    objectName: "friendsList"
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: friends
                    Accessible.name: qsTr("Friends")
                    delegate: ItemDelegate {
                        id: friendRow
                        required property var modelData
                        readonly property bool current: modelData.id === root.selectedPeer
                        width: friendsList.width
                        height: 52
                        padding: 0
                        Accessible.name: modelData.name || qsTr("Friend")
                        onClicked: root.openConversation(modelData.id)
                        background: Rectangle {
                            radius: 14
                            color: friendRow.current ? DesktopTokens.raisedStrong : "transparent"
                            border.width: friendRow.visualFocus ? 2 : 0
                            border.color: DesktopTokens.focus
                        }
                        contentItem: Row {
                            spacing: 10
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34; height: 34; radius: 17
                                color: DesktopTokens.raised
                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData.name || "?").charAt(0).toUpperCase()
                                    color: DesktopTokens.textHigh
                                    font.family: DesktopTokens.displayFont
                                    font.pixelSize: 15
                                    font.weight: Font.Black
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: friendRow.width - 108
                                text: String(modelData.name || qsTr("Friend"))
                                color: DesktopTokens.textHigh
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8; height: 8; radius: 4
                                color: modelData.online ? DesktopTokens.mint : DesktopTokens.seam
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: (modelData.unread || 0) > 0
                                width: unreadLabel.implicitWidth + 14; height: 20; radius: 10
                                color: DesktopTokens.mint
                                Text {
                                    id: unreadLabel
                                    anchors.centerIn: parent
                                    text: String(modelData.unread || 0)
                                    color: "#0A0D14"
                                    font.family: DesktopTokens.monoFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: friendsList.count === 0
                        width: parent.width - 24
                        text: qsTr("No friends yet. Add an OpenNOW player nearby, or paste their address, and the two of you can chat right here.")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // ── Conversation ────────────────────────────────────────────
        Rectangle {
            width: parent.width - rail.width - 24
            height: parent.height
            radius: 24
            color: root.panelFill
            border.width: 1
            border.color: DesktopTokens.seam

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selectedFriend() ? String(root.selectedFriend().name || qsTr("Friend"))
                            : qsTr("Chat")
                        color: DesktopTokens.textHigh
                        font.family: DesktopTokens.displayFont
                        font.pixelSize: 20
                        font.weight: Font.Black
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.selectedFriend() !== null
                        text: root.selectedFriend() && root.selectedFriend().online
                            ? qsTr("Online") : qsTr("Away")
                        color: root.selectedFriend() && root.selectedFriend().online
                            ? (Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.mint)
                            : DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(80, parent.height - y - composerRow.height - 14)
                    ListView {
                    id: threadView
                    objectName: "chatThread"
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    model: root.thread
                    Accessible.name: qsTr("Conversation")
                    onContentHeightChanged: if (contentHeight > height) contentY = contentHeight - height
                    delegate: Item {
                        required property var modelData
                        readonly property bool mine: modelData.mine === true
                        width: threadView.width
                        height: bubble.implicitHeight + 4
                        Rectangle {
                            id: bubble
                            anchors.right: mine ? parent.right : undefined
                            anchors.left: mine ? undefined : parent.left
                            width: Math.min(parent.width - 60, message.implicitWidth + 28)
                            implicitHeight: message.implicitHeight + 20
                            radius: 16
                            color: mine ? Qt.rgba(DesktopTokens.mint.r, DesktopTokens.mint.g, DesktopTokens.mint.b, 0.18)
                                : root.cardFill
                            border.width: 1
                            border.color: mine ? Qt.rgba(DesktopTokens.mint.r, DesktopTokens.mint.g, DesktopTokens.mint.b, 0.45)
                                : DesktopTokens.seamSoft
                            Text {
                                id: message
                                anchors.centerIn: parent
                                width: parent.width - 28
                                text: String(modelData.text || "")
                                color: DesktopTokens.textHigh
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: 14
                                lineHeight: 1.3
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: threadView.count === 0 && root.selectedPeer !== ""
                        width: parent.width - 32
                        text: qsTr("No messages yet. Say hi!")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.selectedPeer === ""
                        width: parent.width - 32
                        text: qsTr("Pick a friend on the left to start chatting. Messages stay on your computer and travel straight to their OpenNOW.")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    id: composerRow
                    width: parent.width
                    spacing: 10
                    TextField {
                        id: composer
                        objectName: "chatComposer"
                        width: parent.width - 100
                        height: 44
                        enabled: root.selectedPeer !== ""
                        placeholderText: qsTr("Write a message…")
                        Accessible.name: qsTr("Write a message")
                        color: DesktopTokens.textHigh
                        placeholderTextColor: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 14
                        leftPadding: 14
                        background: Rectangle {
                            radius: 14
                            color: root.cardFill
                            border.width: 1
                            border.color: composer.activeFocus ? DesktopTokens.focus : DesktopTokens.seamSoft
                        }
                        Keys.onReturnPressed: root.sendCurrent()
                    }
                    DesktopButton {
                        id: sendButton
                        objectName: "chatSend"
                        width: 90
                        height: 44
                        text: qsTr("Send")
                        primary: true
                        enabled: root.selectedPeer !== "" && composer.text.trim() !== ""
                        onClicked: root.sendCurrent()
                    }
                }
            }
        }
    }
}
