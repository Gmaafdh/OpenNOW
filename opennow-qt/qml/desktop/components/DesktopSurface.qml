import QtQuick
import OpenNOW

// The Halo surface: a translucent pane with a soft vertical light gradient, a
// single hairline, an optional top sheen, and an optional accent bloom strip.
// Every panel in the desktop shell is built from this so borders, corner radii
// and lighting stay consistent.
Rectangle {
    id: root

    property real corner: DesktopTokens.radiusLg
    property color fill: DesktopTokens.fill
    property color fillTop: DesktopTokens.fillTop
    property color fillBottom: DesktopTokens.fillBottom
    property bool gradientFill: true
    property color stroke: DesktopTokens.hairline
    property real strokeWidth: 1
    property bool sheen: true
    property color sheenColor: DesktopTokens.sheen
    property bool bloom: false
    property color bloomColor: DesktopTokens.focus
    property bool interactive: false
    property bool highlighted: false
    // Shell-tinted backing layer. Panels that sit on artwork raise this so type
    // stays readable no matter which key art is behind the glass.
    property real tint: 0
    property color tintColor: Qt.rgba(DesktopTokens.shell.r, DesktopTokens.shell.g,
                                      DesktopTokens.shell.b, root.tint)

    radius: corner
    color: "transparent"
    border.width: strokeWidth
    border.color: highlighted ? DesktopTokens.focus : stroke

    Behavior on border.color {
        ColorAnimation { duration: DesktopTokens.hoverDuration }
    }

    gradient: gradientFill ? gradientFillFace : null

    Gradient {
        id: gradientFillFace
        orientation: Gradient.Vertical
        GradientStop { position: 0; color: root.fillTop }
        GradientStop { position: 0.55; color: root.fill }
        GradientStop { position: 1; color: root.fillBottom }
    }

    Rectangle {
        visible: root.tint > 0
        anchors.fill: parent
        anchors.margins: root.strokeWidth
        radius: root.corner - root.strokeWidth
        color: root.tintColor
    }

    // A one-pixel highlight along the top edge sells the "glass" material.
    Rectangle {
        visible: root.sheen
        anchors.top: parent.top
        anchors.topMargin: root.strokeWidth
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - root.corner * 1.4)
        height: 1
        radius: 1
        color: root.sheenColor
        opacity: 0.75
    }

    // An accent bloom washing up from the bottom edge. Static (no shader), so
    // it renders identically on GPU and software scene graphs.
    Rectangle {
        visible: root.bloom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.strokeWidth
        height: Math.min(parent.height * 0.55, DesktopTokens.px(96))
        radius: root.corner - root.strokeWidth
        opacity: 0.5
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(root.bloomColor.r, root.bloomColor.g,
                                                       root.bloomColor.b, 0.16) }
        }
    }
}
