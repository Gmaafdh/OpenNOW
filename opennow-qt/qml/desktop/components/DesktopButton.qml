import QtQuick
import QtQuick.Controls
import OpenNOW

Button {
    id: root
    property bool primary: false
    property bool danger: false
    property bool onMediaBackground: false
    property string shortcutText: ""
    property string shortcutSequence: shortcutText
    property string glyph: ""
    property string themedGlyph: ""
    property int glyphSize: 16
    property int cornerRadius: 8
    height: 36
    implicitWidth: Math.max(68, contentRow.implicitWidth + leftPadding + rightPadding)
    leftPadding: 14
    rightPadding: 14
    focusPolicy: Qt.StrongFocus
    font.family: DesktopTokens.monoFont
    font.pixelSize: 11
    font.weight: Font.Bold
    font.letterSpacing: 0.6
    background: Rectangle {
        radius: root.cornerRadius
        color: root.primary ? Theme.focus
             : root.danger ? (root.hovered || root.activeFocus ? Qt.rgba(1,0.52,0.50,0.18) : Qt.rgba(1,0.52,0.50,0.10))
             : (root.hovered || root.activeFocus ? Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.10) : Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.06))
        border.width: root.primary ? 0 : 1
        border.color: root.primary ? "transparent" : root.danger ? Qt.rgba(1,0.52,0.50,0.42) : root.activeFocus ? Theme.focus : DesktopTokens.neonSeam
        scale: root.down && !AppController.reducedMotion ? 0.985 : 1
        Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
        Behavior on border.color { ColorAnimation { duration: DesktopTokens.quickDuration } }
        Behavior on scale { NumberAnimation { duration: DesktopTokens.quickDuration; easing.type: Easing.OutCubic } }
        // corner ticks for primary
        Canvas {
            anchors.fill: parent
            visible: root.primary
            opacity: 0.85
            onPaint: {
                const ctx=getContext("2d"); ctx.reset(); ctx.strokeStyle="#FFFFFF"; ctx.lineWidth=1.2
                const l=8, r=root.cornerRadius
                ctx.beginPath(); ctx.moveTo(1, r+l); ctx.lineTo(1, r); ctx.arc(r, r, r-1, Math.PI, 1.5*Math.PI); ctx.lineTo(r+l,1); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(width - r - l, height-1); ctx.lineTo(width - r, height-1); ctx.arc(width-r, height-r, r-1, 0.5*Math.PI, 0); ctx.lineTo(width-1, height - r - l); ctx.stroke()
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            color: "transparent"
            border.width: 1.4
            border.color: root.onMediaBackground ? Theme.mediaAccent : Theme.focus
            opacity: 0.42
            visible: root.activeFocus
        }
    }
    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: root.glyph !== "" || root.themedGlyph !== "" ? 11 : 8
            DesktopGlyph {
                visible: root.glyph !== "" && root.themedGlyph === ""
                anchors.verticalCenter: parent.verticalCenter
                width: root.glyphSize
                height: root.glyphSize
                icon: root.glyph
            }
            Loader {
                active: root.themedGlyph !== ""
                visible: active
                anchors.verticalCenter: parent.verticalCenter
                width: root.glyphSize; height: root.glyphSize
                sourceComponent: DesktopSettingsIcon {
                    glyph: root.themedGlyph
                    ink: root.primary ? Theme.faceText : root.onMediaBackground ? Theme.mediaForeground : Theme.label
                }
            }
            Text {
                visible: root.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.text.toUpperCase()
                color: root.primary ? Theme.faceText : root.danger ? "#FFB4AE"
                    : root.onMediaBackground ? Theme.mediaForeground : DesktopTokens.textHigh
                font: root.font
            }
            KeyboardGlyph {
                visible: root.shortcutText !== ""
                anchors.verticalCenter: parent.verticalCenter
                shortcut: root.shortcutSequence
                Accessible.name: root.shortcutText
                keySize: 20
                ink: root.primary ? Theme.faceText : root.onMediaBackground ? Theme.mediaMuted : DesktopTokens.textMuted
            }
        }
    }
}
