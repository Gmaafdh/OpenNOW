import QtQuick
import QtQuick.Controls
import OpenNOW

Button {
    id: root
    property bool primary: false
    property bool danger: false
    property string glyph: ""
    property bool currentItem: false
    property real cornerRadius: 12
    property real labelSize: 16
    property int labelWeight: Font.Bold
    property real glyphSize: 26
    property real contentSpacing: 14
    readonly property bool ringVisible: activeFocus || currentItem
    readonly property color fillColor: primary ? Theme.focus
        : danger ? Qt.rgba(Theme.coral.r, Theme.coral.g, Theme.coral.b, 0.12)
        : Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.84)
    readonly property color dangerInk: Theme.coral
    readonly property color inkColor: primary ? Theme.faceText : danger ? dangerInk : Theme.label

    implicitHeight: 64
    implicitWidth: Math.max(160, labelMetrics.advanceWidth + (glyph !== "" ? glyphSize + contentSpacing : 0) + leftPadding + rightPadding + 2)
    leftPadding: glyph !== "" ? 16 : 20
    rightPadding: 20
    topPadding: 0
    bottomPadding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: text

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return
        event.accepted = true
        if (!event.isAutoRepeat && root.enabled)
            root.clicked()
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            event.accepted = true
    }

    background: Item {
        Rectangle {
            id: halo
            anchors.fill: parent
            anchors.margins: -3
            radius: root.cornerRadius + 3
            color: "transparent"
            border.width: 1.6
            border.color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.42)
            opacity: root.ringVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.focusDuration; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: root.fillColor
            opacity: root.enabled ? 1 : 0.42
            border.width: root.ringVisible ? 1.6 : root.danger ? 1.4 : 1
            border.color: root.ringVisible ? Theme.focus
                : root.danger ? Qt.rgba(root.dangerInk.r, root.dangerInk.g, root.dangerInk.b, 0.55)
                : root.primary ? Theme.focus : Theme.neonSeam
            Behavior on color { ColorAnimation { duration: Theme.focusDuration } }
            // top shine
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; radius: parent.radius; color: Qt.rgba(1,1,1,0.09) }
        }
        // corner accents
        Canvas {
            anchors.fill: parent
            opacity: root.ringVisible || root.primary ? 0.85 : 0
            onPaint: {
                const ctx=getContext("2d"); ctx.reset(); ctx.strokeStyle=Theme.focus; ctx.lineWidth=1.2
                const l=10, r=root.cornerRadius
                // top-left bracket
                ctx.beginPath(); ctx.moveTo(1, r+ l); ctx.lineTo(1, r); ctx.arc(r, r, r-1, Math.PI, 1.5*Math.PI); ctx.lineTo(r+l,1); ctx.stroke()
                // bottom-right
                ctx.beginPath(); ctx.moveTo(width - r - l, height-1); ctx.lineTo(width - r, height-1); ctx.arc(width-r, height-r, r-1, 0.5*Math.PI, 0); ctx.lineTo(width-1, height - r - l); ctx.stroke()
            }
        }
    }

    TextMetrics {
        id: labelMetrics
        text: root.text
        font.family: Theme.monoFont
        font.pixelSize: root.labelSize
        font.weight: root.labelWeight
    }

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight
        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.contentSpacing
            opacity: root.enabled ? 1 : 0.5
            ControllerGlyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph !== ""
                glyph: root.glyph
                label: ""
                glyphSize: root.glyphSize
                glyphColor: root.primary ? Theme.faceText : root.danger ? Theme.coral : Theme.focus
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(labelMetrics.advanceWidth + 4, root.availableWidth - (root.glyph !== "" ? root.glyphSize + root.contentSpacing : 0)))
                text: root.text
                color: root.inkColor
                elide: Text.ElideRight
                font.family: Theme.monoFont
                font.pixelSize: root.labelSize
                font.weight: root.labelWeight
                font.letterSpacing: 0.7
            }
        }
    }
}
