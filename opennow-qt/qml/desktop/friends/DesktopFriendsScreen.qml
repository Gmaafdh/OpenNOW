import QtQuick
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopFriendsComingSoon"
    anchors.fill: parent
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Friends")

    // Placeholder card: the shelf exists in the shell already, so the empty
    // state speaks in the same Halo language instead of a bare heading.
    DesktopSurface {
        anchors.centerIn: parent
        width: Math.min(root.width - DesktopTokens.px(48), DesktopTokens.px(520))
        height: content.implicitHeight + DesktopTokens.px(72)
        corner: DesktopTokens.radiusXl
        tint: Theme.lightMode ? 0.62 : 0.42
        bloom: true

        Column {
            id: content
            anchors.centerIn: parent
            width: parent.width - DesktopTokens.px(56)
            spacing: DesktopTokens.px(14)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: DesktopTokens.px(56)
                height: width
                radius: DesktopTokens.radiusLg
                color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.14)
                border.width: 1
                border.color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.30)
                DesktopGlyph {
                    anchors.centerIn: parent
                    width: DesktopTokens.px(26)
                    height: width
                    icon: "desktop-nav-friends.svg"
                    active: true
                }
            }

            Text {
                width: content.width
                text: qsTr("Coming soon")
                horizontalAlignment: Text.AlignHCenter
                color: DesktopTokens.textHigh
                font.family: Theme.displayFont
                font.pixelSize: DesktopTokens.px(26)
                font.weight: Font.Black
                font.letterSpacing: -0.5
            }

            Text {
                width: content.width
                text: qsTr("Presence, invites and party voice are in the works. Your friends list will appear here as soon as it ships.")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: DesktopTokens.textBody
                font.family: Theme.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                lineHeightMode: Text.FixedHeight
                lineHeight: DesktopTokens.px(19)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: badgeRow.implicitWidth + DesktopTokens.px(24)
                height: DesktopTokens.px(24)
                radius: DesktopTokens.radiusPill
                color: DesktopTokens.fill
                border.width: 1
                border.color: DesktopTokens.hairlineSoft

                Row {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(7)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(6)
                        height: width
                        radius: width / 2
                        color: DesktopTokens.amber
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("IN DEVELOPMENT")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                        font.letterSpacing: 0.9
                    }
                }
            }
        }
    }
}
