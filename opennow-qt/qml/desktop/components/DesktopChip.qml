import QtQuick
import OpenNOW

// Small pill used for status, counts, and feature labels. Always pairs its
// colour with text so state never depends on colour alone.
Rectangle {
    id: root

    property string text: ""
    property string glyph: ""
    property color tone: DesktopTokens.focus
    property bool solid: false
    property bool dot: false
    property bool onMedia: false
    property real textSize: DesktopTokens.smallSize
    property real corner: DesktopTokens.radiusPill

    readonly property bool quiet: !root.solid
    implicitWidth: content.implicitWidth + DesktopTokens.px(root.dot ? 20 : 18)
    implicitHeight: DesktopTokens.px(24)
    width: implicitWidth
    height: implicitHeight
    radius: corner

    color: root.solid
        ? Qt.rgba(root.tone.r, root.tone.g, root.tone.b, root.onMedia ? 0.92 : 0.86)
        : Qt.rgba(root.tone.r, root.tone.g, root.tone.b, root.onMedia ? 0.22 : 0.14)
    border.width: 1
    border.color: root.solid
        ? Qt.rgba(1, 1, 1, 0.28)
        : Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.34)

    Row {
        id: content
        anchors.centerIn: parent
        spacing: DesktopTokens.px(6)

        Rectangle {
            visible: root.dot
            width: DesktopTokens.px(5)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.solid ? DesktopTokens.inkOnAccent : root.tone
        }
        DesktopGlyph {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: DesktopTokens.px(12)
            height: width
            icon: root.glyph
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            visible: root.text !== ""
            color: root.solid ? DesktopTokens.inkOnAccent
                : root.onMedia ? Theme.mediaForeground : DesktopTokens.textHigh
            font.family: DesktopTokens.monoFont
            font.pixelSize: root.textSize
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
            font.capitalization: Font.AllUppercase
        }
    }
}
