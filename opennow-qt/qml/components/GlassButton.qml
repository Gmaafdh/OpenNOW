import QtQuick
import QtQuick.Controls
import OpenNOW

Button {
    id: root
    property string glyph: "A"
    property string shortcutText: ""
    property bool primary: false
    property bool danger: false
    property bool currentItem: false
    highlighted: activeFocus || currentItem

    implicitHeight: 54
    leftPadding: 16
    rightPadding: 24
    focusPolicy: Qt.StrongFocus
    Accessible.name: I18n.source(text, I18n.revision) + (shortcutText !== "" ? " · " + shortcutText : "")
    Accessible.role: Accessible.Button

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat)
                root.click()
            event.accepted = true
        }
    }

    background: Rectangle {
        radius: 12
        // Cyber clipped corners via border styling
        color: root.primary ? Theme.focus
                            : root.danger ? Qt.rgba(1, 0.28, 0.3, root.activeFocus ? 0.28 : 0.14)
                                          : root.highlighted ? Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.16) : Theme.glassStrong
        border.color: root.primary ? Theme.focus : root.highlighted ? Theme.focus : root.danger ? Theme.coral : Theme.neonSeam
        border.width: root.highlighted ? 2 : 1
        Behavior on color { ColorAnimation { duration: Theme.focusDuration } }
        Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
        // Inner neon glow for primary
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, root.primary ? 0.55 : 0)
            visible: root.primary
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.42)
            visible: root.highlighted && !root.primary
        }
    }

    contentItem: Row {
        spacing: 12
        ControllerGlyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            glyph: root.glyph
            label: ""
            glyphSize: 26
            glyphColor: root.primary ? Theme.faceText : Theme.focus
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.source(root.text, I18n.revision)
            color: root.primary ? Theme.faceText : root.danger ? Theme.coral : Theme.label
            font.family: Theme.monoFont
            font.pixelSize: 14
            font.weight: Font.Bold
            font.letterSpacing: 0.6
        }
        KeyboardGlyph {
            visible: root.shortcutText !== ""
            anchors.verticalCenter: parent.verticalCenter
            shortcut: root.shortcutText
            keySize: 22
            ink: root.primary ? Theme.faceText : Theme.textMuted
        }
    }
}
