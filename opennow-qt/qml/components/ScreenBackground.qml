import QtQuick
import OpenNOW

Rectangle {
    id: root
    property string artwork: ""
    property color tint: Theme.focus
    readonly property color scrimMid: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.62)
    readonly property color scrimFar: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.90)
    anchors.fill: parent
    color: Theme.shellDeep

    ArtworkSource {
        id: artworkSource
        sourceUrl: DesktopTokens.decodeArtworkUrl(root.artwork)
        active: root.visible
    }

    Image {
        anchors.fill: parent
        source: artworkSource.resolvedUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        asynchronous: true
        opacity: status === Image.Ready ? 0.44 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.enterDuration } }
    }
    // Neon duotone
    Rectangle {
        anchors.fill: parent
        opacity: artworkSource.resolvedUrl !== "" ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.16) }
            GradientStop { position: 1; color: Qt.rgba(Theme.mint.r, Theme.mint.g, Theme.mint.b, 0.08) }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.shellDeep }
            GradientStop { position: 0.46; color: root.scrimMid }
            GradientStop { position: 1; color: root.scrimFar }
        }
    }
    // Cyber grid overlay
    Canvas {
        anchors.fill: parent
        opacity: 0.055
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            ctx.strokeStyle = Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 1)
            ctx.lineWidth = 1
            for (let x = 0; x < w; x += 36) { ctx.beginPath(); ctx.moveTo(x+0.5,0); ctx.lineTo(x+0.5,h); ctx.stroke() }
            for (let y = 0; y < h; y += 36) { ctx.beginPath(); ctx.moveTo(0,y+0.5); ctx.lineTo(w,y+0.5); ctx.stroke() }
        }
    }
    // Top neon wash
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: Math.round(parent.height * 0.38)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.10) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    // Scanlines
    Canvas {
        anchors.fill: parent
        opacity: 0.045
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "#FFFFFF"
            ctx.lineWidth = 1
            for (let y=0;y<height;y+=3) { ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(width,y); ctx.stroke() }
        }
    }
}
