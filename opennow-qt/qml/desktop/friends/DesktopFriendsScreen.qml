import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopFriendsScreen"
    anchors.fill: parent
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Friends")
    property string endpointDraft: SocialClient.serviceUrl
    property string usernameDraft: ""
    property string passwordDraft: ""
    property string nvidiaNameDraft: ""
    property string friendLookupDraft: ""
    property string pendingFriendLookupDraft: ""
    property bool sendingFriendRequest: false
    property string messageDraft: ""
    property string pendingMessageDraft: ""
    property string pendingMessageRecipient: ""
    property bool sendingChatMessage: false
    property string nvidiaDisplayNameDraft: ""
    property string selectedSection: "friends"
    property string statusMessage: ""
    property bool sharePresenceDraft: false
    property bool shareActivityDraft: false
    property bool shareHistoryDraft: false

    function loadPrivacyDraft() {
        sharePresenceDraft = SocialClient.privacy.sharePresence === true
        shareActivityDraft = SocialClient.privacy.shareActivity === true
        shareHistoryDraft = SocialClient.privacy.shareHistory === true
    }
    function gameTime(milliseconds) {
        const minutes = Math.floor(Number(milliseconds || 0) / 60000)
        if (minutes >= 60)
            return qsTr("%1 h %2 min").arg(Math.floor(minutes / 60)).arg(minutes % 60)
        return qsTr("%1 min").arg(minutes)
    }
    function lastPlayed(milliseconds) {
        const value = Number(milliseconds || 0)
        return value > 0 ? new Date(value).toLocaleDateString() : qsTr("Recently")
    }
    function selectedFriend() {
        const list = SocialClient.friends || []
        for (let i = 0; i < list.length; ++i) {
            if (String(list[i].id) === SocialClient.selectedFriendId)
                return list[i]
        }
        return null
    }

    Component.onCompleted: {
        endpointDraft = SocialClient.serviceUrl
        loadPrivacyDraft()
    }
    Connections {
        target: SocialClient
        function onPrivacyChanged() { root.loadPrivacyDraft() }
        function onProfileChanged() { root.nvidiaDisplayNameDraft = SocialClient.profile.nvidiaDisplayName || "" }
        function onOperationFinished(operation, success, message) {
            if (success) root.statusMessage = message
            if (operation === "friend-request") {
                root.sendingFriendRequest = false
                if (success && root.friendLookupDraft === root.pendingFriendLookupDraft)
                    root.friendLookupDraft = ""
                root.pendingFriendLookupDraft = ""
            }
            if (operation === "send-message") {
                root.sendingChatMessage = false
                if (success && root.messageDraft === root.pendingMessageDraft
                        && SocialClient.selectedFriendId === root.pendingMessageRecipient)
                    root.messageDraft = ""
                root.pendingMessageDraft = ""
                root.pendingMessageRecipient = ""
            }
        }
        function onAuthenticatedChanged() {
            root.passwordDraft = ""
            root.statusMessage = ""
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: Math.max(520, scroll.availableWidth - DesktopTokens.px(40))
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: DesktopTokens.px(18)
            Item { Layout.preferredHeight: DesktopTokens.px(4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: qsTr("Friends")
                        color: Theme.label
                        font.family: Theme.displayFont
                        font.pixelSize: DesktopTokens.px(28)
                        font.weight: Font.Bold
                    }
                    Text {
                        text: qsTr("Chat and share your OpenNOW gaming activity across devices.")
                        color: DesktopTokens.textMuted
                        font.family: Theme.bodyFont
                        font.pixelSize: DesktopTokens.px(13)
                        wrapMode: Text.Wrap
                    }
                }
                Rectangle {
                    radius: 12
                    color: "#1425E0A1"
                    border.color: "#3425E0A1"
                    implicitWidth: platformLabel.implicitWidth + 24
                    implicitHeight: 32
                    Text {
                        id: platformLabel
                        anchors.centerIn: parent
                        text: qsTr("OPENNOW SOCIAL")
                        color: "#85EFC4"
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: DesktopTokens.px(14)
                color: Theme.lightMode ? "#ECF1F7" : "#C9101724"
                border.width: 1
                border.color: Theme.lightMode ? "#283B4B60" : "#1FFFFFFF"
                implicitHeight: serverContent.implicitHeight + 28
                ColumnLayout {
                    id: serverContent
                    anchors.fill: parent
                    anchors.margins: DesktopTokens.px(14)
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: SocialClient.authenticated
                                ? qsTr("Connected to %1").arg(SocialClient.serviceUrl)
                                : qsTr("Self-hosted service")
                            color: Theme.label
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            elide: Text.ElideMiddle
                        }
                        DesktopButton {
                            visible: SocialClient.authenticated
                            text: qsTr("Sign out")
                            onClicked: SocialClient.signOut()
                        }
                    }
                    RowLayout {
                        visible: !SocialClient.authenticated
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            id: endpointField
                            Layout.fillWidth: true
                            text: root.endpointDraft
                            placeholderText: qsTr("https://social.your-domain.example")
                            selectByMouse: true
                            color: Theme.label
                            placeholderTextColor: DesktopTokens.textMuted
                            onTextEdited: root.endpointDraft = text
                            onEditingFinished: SocialClient.serviceUrl = text
                            background: Rectangle {
                                radius: 8
                                color: Theme.lightMode ? "#FFFFFFFF" : "#161C2A"
                                border.color: endpointField.activeFocus ? DesktopTokens.mint : "#253FFFFFFF"
                            }
                        }
                        DesktopButton {
                            text: qsTr("Use server")
                            primary: true
                            onClicked: SocialClient.serviceUrl = root.endpointDraft
                        }
                    }
                    Text {
                        visible: !SocialClient.authenticated
                        Layout.fillWidth: true
                        text: qsTr("Both people must use the same publicly reachable service. Use HTTPS for public connections; localhost only works on this computer.")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                visible: !SocialClient.authenticated
                Layout.fillWidth: true
                radius: DesktopTokens.px(16)
                color: Theme.lightMode ? "#EEF2F8" : "#D9101724"
                border.width: 1
                border.color: Theme.lightMode ? "#263B4B60" : "#22FFFFFF"
                implicitHeight: accountLayout.implicitHeight + 36
                ColumnLayout {
                    id: accountLayout
                    anchors.fill: parent
                    anchors.margins: DesktopTokens.px(18)
                    spacing: 12
                    Text {
                        text: qsTr("Create or sign in to your OpenNOW account")
                        color: Theme.label
                        font.family: Theme.displayFont
                        font.pixelSize: DesktopTokens.px(18)
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("This is an OpenNOW identity, separate from NVIDIA. Your password is sent only to the service URL above; OpenNOW does not search or verify NVIDIA accounts.")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        DesktopButton {
                            text: qsTr("Sign in")
                            primary: root.selectedSection === "friends"
                            onClicked: root.selectedSection = "friends"
                        }
                        DesktopButton {
                            text: qsTr("Create account")
                            primary: root.selectedSection === "create"
                            onClicked: root.selectedSection = "create"
                        }
                        Item { Layout.fillWidth: true }
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: root.usernameDraft
                        placeholderText: qsTr("OpenNOW username")
                        maximumLength: 20
                        selectByMouse: true
                        color: Theme.label
                        placeholderTextColor: DesktopTokens.textMuted
                        onTextEdited: root.usernameDraft = text
                        onAccepted: passwordField.forceActiveFocus()
                        background: Rectangle { radius: 8; color: Theme.lightMode ? "white" : "#161C2A"; border.color: parent.activeFocus ? DesktopTokens.mint : "#253FFFFFFF" }
                    }
                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        text: root.passwordDraft
                        placeholderText: root.selectedSection === "create" ? qsTr("Password (at least 12 characters)") : qsTr("Password")
                        echoMode: TextInput.Password
                        maximumLength: 256
                        selectByMouse: true
                        color: Theme.label
                        placeholderTextColor: DesktopTokens.textMuted
                        onTextEdited: root.passwordDraft = text
                        onAccepted: root.submitAccount()
                        background: Rectangle { radius: 8; color: Theme.lightMode ? "white" : "#161C2A"; border.color: parent.activeFocus ? DesktopTokens.mint : "#253FFFFFFF" }
                    }
                    TextField {
                        visible: root.selectedSection === "create"
                        Layout.fillWidth: true
                        text: root.nvidiaNameDraft
                        placeholderText: qsTr("Optional NVIDIA display name (unverified)")
                        maximumLength: 40
                        selectByMouse: true
                        color: Theme.label
                        placeholderTextColor: DesktopTokens.textMuted
                        onTextEdited: root.nvidiaNameDraft = text
                        background: Rectangle { radius: 8; color: Theme.lightMode ? "white" : "#161C2A"; border.color: parent.activeFocus ? DesktopTokens.mint : "#253FFFFFFF" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        DesktopButton {
                            primary: true
                            enabled: !SocialClient.busy && root.usernameDraft.trim() !== "" && root.passwordDraft !== ""
                            text: root.selectedSection === "create" ? qsTr("Create OpenNOW account") : qsTr("Sign in")
                            onClicked: root.submitAccount()
                        }
                        Item { Layout.fillWidth: true }
                        BusyIndicator { running: SocialClient.busy; visible: running; implicitWidth: 26; implicitHeight: 26 }
                    }
                    Text {
                        visible: SocialClient.error !== "" || root.statusMessage !== ""
                        Layout.fillWidth: true
                        text: SocialClient.error !== "" ? SocialClient.error : root.statusMessage
                        color: SocialClient.error !== "" ? "#FF9A91" : "#8BE4B9"
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }

            RowLayout {
                visible: SocialClient.authenticated
                Layout.fillWidth: true
                Layout.preferredHeight: DesktopTokens.px(570)
                spacing: DesktopTokens.px(14)

                Rectangle {
                    Layout.preferredWidth: Math.min(340, root.width * 0.34)
                    Layout.fillHeight: true
                    radius: DesktopTokens.px(16)
                    color: Theme.lightMode ? "#EEF2F8" : "#D9101724"
                    border.width: 1
                    border.color: Theme.lightMode ? "#263B4B60" : "#22FFFFFF"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: DesktopTokens.px(14)
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: SocialClient.displayName; color: Theme.label; font.family: Theme.displayFont; font.pixelSize: 17; font.weight: Font.Bold; elide: Text.ElideRight }
                                Text { text: "@" + SocialClient.username; color: DesktopTokens.textMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 10 }
                            }
                            DesktopButton { text: qsTr("Copy code"); onClicked: SocialClient.copyFriendCode() }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Your friend code: %1").arg(SocialClient.friendCode)
                            color: DesktopTokens.mint
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightMode ? "#263B4B60" : "#22FFFFFF" }
                        Text { text: qsTr("ADD A FRIEND"); color: DesktopTokens.textMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 10; font.weight: Font.Bold }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            TextField {
                                id: addFriendField
                                Layout.fillWidth: true
                                text: root.friendLookupDraft
                                placeholderText: qsTr("Username or ON- friend code")
                                selectByMouse: true
                                color: Theme.label
                                placeholderTextColor: DesktopTokens.textMuted
                                onTextEdited: root.friendLookupDraft = text
                                onAccepted: root.addFriend()
                                background: Rectangle { radius: 8; color: Theme.lightMode ? "white" : "#161C2A"; border.color: addFriendField.activeFocus ? DesktopTokens.mint : "#253FFFFFFF" }
                            }
                            DesktopButton { text: root.sendingFriendRequest ? qsTr("Sending…") : qsTr("Add"); primary: true; enabled: root.friendLookupDraft.trim() !== "" && !root.sendingFriendRequest; onClicked: root.addFriend() }
                        }
                        Text { text: qsTr("REQUESTS"); color: DesktopTokens.textMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 10; font.weight: Font.Bold }
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 132)
                            clip: true
                            model: SocialClient.friendRequests
                            spacing: 5
                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                height: 62
                                radius: 9
                                color: Theme.lightMode ? "#FFFFFF" : "#15202D"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 5
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text { text: modelData.displayName || modelData.username; color: Theme.label; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight }
                                        Text { text: "@" + modelData.username; color: DesktopTokens.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                                    }
                                    DesktopButton { text: qsTr("Accept"); onClicked: SocialClient.respondToFriendRequest(modelData.id, true) }
                                    DesktopButton { text: qsTr("×"); onClicked: SocialClient.respondToFriendRequest(modelData.id, false) }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: SocialClient.friendRequests.length === 0
                                text: qsTr("No pending requests")
                                color: DesktopTokens.textMuted
                                font.pixelSize: 11
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightMode ? "#263B4B60" : "#22FFFFFF" }
                        Text { text: qsTr("FRIENDS · %1").arg(SocialClient.friends.length); color: DesktopTokens.textMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 10; font.weight: Font.Bold }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: SocialClient.friends
                            spacing: 5
                            delegate: Button {
                                id: friendRow
                                required property var modelData
                                width: ListView.view.width
                                height: 58
                                padding: 9
                                onClicked: SocialClient.selectFriend(modelData.id)
                                background: Rectangle {
                                    radius: 9
                                    color: SocialClient.selectedFriendId === friendRow.modelData.id
                                        ? (Theme.lightMode ? "#DBE9E6" : "#2425E0A1")
                                        : (friendRow.hovered ? (Theme.lightMode ? "#F8FAFC" : "#202A3A") : "transparent")
                                    border.width: SocialClient.selectedFriendId === friendRow.modelData.id ? 1 : 0
                                    border.color: "#5038D9A5"
                                }
                                contentItem: RowLayout {
                                    spacing: 9
                                    Rectangle {
                                        width: 9; height: 9; radius: 5
                                        color: friendRow.modelData.online ? "#55D99A" : "#657080"
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: friendRow.modelData.displayName || friendRow.modelData.username; color: Theme.label; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight }
                                        Text {
                                            Layout.fillWidth: true
                                            text: friendRow.modelData.activity ? friendRow.modelData.activity.gameName
                                                : friendRow.modelData.online
                                                    ? (friendRow.modelData.status === "away" ? qsTr("Away") : qsTr("Online"))
                                                    : qsTr("Offline")
                                            color: DesktopTokens.textMuted
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: SocialClient.friends.length === 0
                                width: parent.width - 20
                                text: qsTr("No friends yet. Add someone with their OpenNOW username or friend code.")
                                color: DesktopTokens.textMuted
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: DesktopTokens.px(16)
                    color: Theme.lightMode ? "#EEF2F8" : "#D9101724"
                    border.width: 1
                    border.color: Theme.lightMode ? "#263B4B60" : "#22FFFFFF"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: DesktopTokens.px(14)
                        spacing: 9
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text {
                                    text: root.selectedFriend() ? (root.selectedFriend().displayName || root.selectedFriend().username) : qsTr("Your conversations")
                                    color: Theme.label
                                    font.family: Theme.displayFont
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: root.selectedFriend() !== null
                                    text: {
                                        const friend = root.selectedFriend()
                                        if (!friend) return ""
                                        if (friend.activity) return qsTr("Playing %1").arg(friend.activity.gameName)
                                        return friend.online ? qsTr("Online") : qsTr("Offline")
                                    }
                                    color: root.selectedFriend() && root.selectedFriend().online ? DesktopTokens.mint : DesktopTokens.textMuted
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                visible: root.selectedFriend() && root.selectedFriend().nvidiaDisplayName !== ""
                                text: root.selectedFriend() && root.selectedFriend().nvidiaDisplayName
                                    ? qsTr("NVIDIA name: %1 · unverified").arg(root.selectedFriend().nvidiaDisplayName) : ""
                                color: DesktopTokens.textMuted
                                font.pixelSize: 10
                                wrapMode: Text.Wrap
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightMode ? "#263B4B60" : "#22FFFFFF" }
                        RowLayout {
                            visible: root.selectedFriend() !== null && root.selectedFriend().recentGames.length > 0
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: qsTr("PLAY HISTORY"); color: DesktopTokens.textMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 9; font.weight: Font.Bold }
                            Repeater {
                                model: root.selectedFriend() ? root.selectedFriend().recentGames.slice(0, 3) : []
                                delegate: Rectangle {
                                    required property var modelData
                                    radius: 7
                                    color: Theme.lightMode ? "#DCE5EE" : "#182231"
                                    implicitWidth: historyText.implicitWidth + 14
                                    implicitHeight: 25
                                    Text {
                                        id: historyText
                                        anchors.centerIn: parent
                                        text: qsTr("%1 · %2 · %3").arg(modelData.gameName)
                                            .arg(root.gameTime(modelData.playTimeMs)).arg(root.lastPlayed(modelData.lastPlayedAt))
                                        color: Theme.label
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            ListView {
                                id: chatList
                                anchors.fill: parent
                                clip: true
                                spacing: 7
                                model: SocialClient.messages
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool mine: String(modelData.senderId) === String(SocialClient.profile.id)
                                    width: Math.min(chatList.width * 0.82, messageText.implicitWidth + 28)
                                    height: messageText.implicitHeight + 30
                                    anchors.right: mine ? parent.right : undefined
                                    radius: 12
                                    color: mine ? (Theme.lightMode ? "#CDE9DD" : "#2425A977") : (Theme.lightMode ? "#FFFFFF" : "#1A2433")
                                    Text {
                                        id: messageText
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        text: modelData.text
                                        color: Theme.label
                                        font.family: DesktopTokens.bodyFont
                                        font.pixelSize: 12
                                        wrapMode: Text.Wrap
                                    }
                                }
                                onCountChanged: Qt.callLater(positionViewAtEnd, ListView.End)
                                Text {
                                    anchors.centerIn: parent
                                    visible: SocialClient.selectedFriendId === ""
                                    text: qsTr("Choose a friend to open chat, presence, and play history.")
                                    color: DesktopTokens.textMuted
                                    width: parent.width - 36
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: SocialClient.selectedFriendId !== ""
                            TextField {
                                id: chatInput
                                Layout.fillWidth: true
                                text: root.messageDraft
                                placeholderText: qsTr("Write a message…")
                                maximumLength: 2000
                                selectByMouse: true
                                color: Theme.label
                                placeholderTextColor: DesktopTokens.textMuted
                                onTextEdited: root.messageDraft = text
                                onAccepted: root.sendChatMessage()
                                background: Rectangle { radius: 8; color: Theme.lightMode ? "white" : "#161C2A"; border.color: chatInput.activeFocus ? DesktopTokens.mint : "#253FFFFFFF" }
                            }
                            DesktopButton { text: root.sendingChatMessage ? qsTr("Sending…") : qsTr("Send"); primary: true; enabled: root.messageDraft.trim() !== "" && !root.sendingChatMessage; onClicked: root.sendChatMessage() }
                        }
                    }
                }
            }

            Rectangle {
                visible: SocialClient.authenticated
                Layout.fillWidth: true
                radius: DesktopTokens.px(14)
                color: Theme.lightMode ? "#ECF1F7" : "#C9101724"
                border.width: 1
                border.color: Theme.lightMode ? "#283B4B60" : "#1FFFFFFF"
                implicitHeight: privacyContent.implicitHeight + 28
                ColumnLayout {
                    id: privacyContent
                    anchors.fill: parent
                    anchors.margins: DesktopTokens.px(14)
                    spacing: 7
                    Text { text: qsTr("PRIVACY & SHARING"); color: Theme.label; font.family: DesktopTokens.monoFont; font.pixelSize: 10; font.weight: Font.Bold }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Sharing is off by default. OpenNOW Social presence and play history come only from this app's connection; they are not fetched from NVIDIA.")
                        color: DesktopTokens.textMuted
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: nvidiaNameField
                            Layout.fillWidth: true
                            text: root.nvidiaDisplayNameDraft
                            placeholderText: qsTr("Optional NVIDIA display name · user-provided, unverified")
                            maximumLength: 40
                            selectByMouse: true
                            color: Theme.label
                            placeholderTextColor: DesktopTokens.textMuted
                            onTextEdited: root.nvidiaDisplayNameDraft = text
                            background: Rectangle { radius: 8; color: Theme.lightMode ? "white" : "#161C2A"; border.color: nvidiaNameField.activeFocus ? DesktopTokens.mint : "#253FFFFFFF" }
                        }
                        DesktopButton {
                            text: qsTr("Save name")
                            onClicked: SocialClient.setNvidiaDisplayName(root.nvidiaDisplayNameDraft)
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        CheckBox { text: qsTr("Share online status"); checked: root.sharePresenceDraft; onToggled: root.sharePresenceDraft = checked }
                        CheckBox { text: qsTr("Share current game"); checked: root.shareActivityDraft; onToggled: root.shareActivityDraft = checked }
                        CheckBox { text: qsTr("Share play history"); checked: root.shareHistoryDraft; onToggled: root.shareHistoryDraft = checked }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        DesktopButton {
                            text: qsTr("Save privacy choices")
                            onClicked: SocialClient.setPrivacy(root.sharePresenceDraft, root.shareActivityDraft, root.shareHistoryDraft)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: SocialClient.error !== "" ? SocialClient.error : root.statusMessage
                            color: SocialClient.error !== "" ? "#FF9A91" : "#8BE4B9"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: DesktopTokens.px(18) }
        }
    }

    function submitAccount() {
        SocialClient.clearError()
        SocialClient.serviceUrl = endpointDraft
        if (SocialClient.serviceUrl === ""
                || SocialClient.serviceUrl !== endpointDraft.trim().replace(/\/+$/, "")) return
        if (selectedSection === "create")
            SocialClient.registerAccount(usernameDraft, passwordDraft, nvidiaNameDraft)
        else
            SocialClient.signIn(usernameDraft, passwordDraft)
    }
    function addFriend() {
        if (friendLookupDraft.trim() === "" || sendingFriendRequest) return
        pendingFriendLookupDraft = friendLookupDraft
        sendingFriendRequest = true
        SocialClient.sendFriendRequest(friendLookupDraft)
    }
    function sendChatMessage() {
        if (messageDraft.trim() === "" || sendingChatMessage) return
        pendingMessageDraft = messageDraft
        pendingMessageRecipient = SocialClient.selectedFriendId
        sendingChatMessage = true
        SocialClient.sendMessage(messageDraft)
    }
}
