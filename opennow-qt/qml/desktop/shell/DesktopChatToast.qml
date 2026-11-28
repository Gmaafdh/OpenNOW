import QtQuick
import OpenNOW

// Short-lived notice when a chat message or friend request arrives.
Rectangle {
    id: root
    property bool active: true
    property string currentTitle: ""
    property string currentPreview: ""

    width: toastRow.implicitWidth + 36
    height: 54
    radius: 16
    color: Theme.lightMode ? "#F2F5FA" : "#E60B1320"
    border.width: 1
    border.color: DesktopTokens.seam
    visible: active && currentTitle !== ""
    opacity: visible ? 1 : 0
    Accessible.name: currentTitle === "" ? "" : currentTitle + " " + currentPreview
    Accessible.role: Accessible.AlertMessage

    function shortPreview(text) {
        const oneLine = String(text || "").replace(/\s+/g, " ").trim()
        return oneLine.length > 72 ? oneLine.slice(0, 72) + "…" : oneLine
    }
    function show(title, preview) {
        currentTitle = title
        currentPreview = shortPreview(preview)
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 4000
        onTriggered: {
            root.currentTitle = ""
            root.currentPreview = ""
        }
    }

    Connections {
        target: ShellStore
        function onChatMessageReceived(peerName, preview) {
            root.show(qsTr("Message from %1").arg(peerName), preview)
        }
        function onChatFriendRequestReceived(peerName) {
            root.show(qsTr("Friend request"), qsTr("%1 wants to chat").arg(peerName))
        }
    }

    Row {
        id: toastRow
        anchors.centerIn: parent
        spacing: 10
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5
            color: DesktopTokens.mint
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentTitle
            color: DesktopTokens.textHigh
            font.family: DesktopTokens.bodyFont
            font.pixelSize: 13
            font.weight: Font.ExtraBold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.currentPreview !== ""
            text: root.currentPreview
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: 13
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 360)
        }
    }
}
