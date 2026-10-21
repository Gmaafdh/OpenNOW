import QtQuick
import OpenNOW

Rectangle {
    id: root
    property bool strong: false
    property real panelRadius: 18
    property bool neon: false

    color: strong ? Theme.glassStrong : Theme.glass
    border.color: neon ? Theme.neonSeam : Theme.seam
    border.width: neon ? 1.4 : 1
    radius: panelRadius

    // Neon outer glow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, neon ? 0.16 : 0.0)
        visible: neon
        opacity: 0.9
    }
    // Top highlight
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 1
        radius: parent.radius
        color: Qt.rgba(1,1,1, Theme.lightMode ? 0.10 : 0.11)
    }
}
