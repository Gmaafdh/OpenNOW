import QtQuick
import OpenNOW

// Rail heading: a tight display title, an optional count chip, and one quiet
// action on the trailing edge. Grouping lives in the type, not in boxes.
Item {
    id: root

    property string title: ""
    property string kicker: ""
    property int count: -1
    property string actionText: ""
    property string actionGlyph: ""
    property bool onMedia: false
    property real titleSize: DesktopTokens.sectionSize
    readonly property real actionLeftEdge: actionRow.visible ? actionRow.x : width

    signal actionClicked()

    implicitHeight: Math.max(titleText.implicitHeight, actionRow.implicitHeight)

    Text {
        id: kickerText
        visible: root.kicker !== ""
        y: -DesktopTokens.px(14)
        text: root.kicker
        color: root.onMedia ? Theme.mediaAccent : DesktopTokens.focus
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.microSize
        font.weight: Font.Bold
        font.letterSpacing: 1.1
        font.capitalization: Font.AllUppercase
    }

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: root.onMedia ? Theme.mediaForeground : DesktopTokens.textHigh
        font.family: DesktopTokens.displayFont
        font.pixelSize: root.titleSize
        font.weight: Font.Black
        font.letterSpacing: -0.35
    }

    DesktopChip {
        id: countChip
        visible: root.count >= 0
        anchors.left: titleText.right
        anchors.leftMargin: DesktopTokens.px(10)
        anchors.verticalCenter: parent.verticalCenter
        height: DesktopTokens.px(20)
        text: root.count >= 0 ? String(root.count) : ""
        onMedia: root.onMedia
        tone: DesktopTokens.focus
        textSize: DesktopTokens.microSize
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesktopTokens.px(6)
        visible: root.actionText !== ""

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.actionText
            color: actionHover.hovered ? (root.onMedia ? Theme.mediaForeground : DesktopTokens.textHigh)
                                       : (root.onMedia ? Theme.mediaMuted : DesktopTokens.textMuted)
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
            font.weight: Font.Bold
            Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
        }
        DesktopGlyph {
            anchors.verticalCenter: parent.verticalCenter
            width: DesktopTokens.px(11)
            height: width
            rotation: root.actionGlyph === "" ? -90 : 0
            icon: root.actionGlyph === "" ? "desktop-chevron-down.svg" : root.actionGlyph
            active: root.actionGlyph !== ""
            opacity: actionHover.hovered ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: DesktopTokens.hoverDuration } }
        }
        HoverHandler {
            id: actionHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.actionClicked()
        }
    }
}
