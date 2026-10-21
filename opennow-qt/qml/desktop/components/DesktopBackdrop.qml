import QtQuick
import OpenNOW

Item {
    id: root
    objectName: root.signIn ? "signInBackdrop" : "desktopBackdrop"
    property string artwork: ShellStore.catalogGames.length
        ? DesktopTokens.artworkUrl(ShellStore.catalogGames[0], true) : ""
    property bool signIn: false
    readonly property bool customBackground: !root.signIn && ShellStore.settings.desktopBackground === "custom"
    readonly property string normalizedArtwork: root.artwork !== ""
        ? DesktopTokens.decodeArtworkUrl(root.artwork)
        : root.signIn ? "qrc:/qt/qml/OpenNOW/res/brand/signin-hero.jpg" : "qrc:/qt/qml/OpenNOW/res/brand/desktop-renew.jpg"

    ArtworkSource {
        id: artworkSource
        sourceUrl: root.normalizedArtwork
        active: root.visible && (root.signIn || String(ShellStore.settings.desktopBackground || "art") === "art")
    }

    // Base cyber void
    Rectangle { anchors.fill: parent; color: root.signIn ? Theme.shell : DesktopTokens.shellDeep }

    // Artwork layer with cyber treatment
    Item {
        anchors.fill: parent
        clip: true
        Image {
            id: art
            width: parent.width
            height: parent.height * (root.signIn ? 1.18 : 1.08)
            y: root.signIn ? -parent.height * 0.12 : -parent.height * 0.04
            source: artworkSource.resolvedUrl
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(1440, 900)
            opacity: status === Image.Ready && (root.signIn || String(ShellStore.settings.desktopBackground || "art") === "art") ? 0.52 : 0
            Behavior on opacity { NumberAnimation { duration: DesktopTokens.revealDuration } }
        }
        // Cyber duotone wash
        Rectangle {
            anchors.fill: parent
            visible: art.opacity > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.19) }
                GradientStop { position: 0.55; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.04) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.13) }
            }
        }
    }

    Image {
        objectName: "customDesktopBackground"
        anchors.fill: parent
        source: root.visible && root.customBackground ? String(ShellStore.settings.desktopBackgroundImage || "") : ""
        sourceSize: Qt.size(1920, 1080)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        opacity: status === Image.Ready ? Number(ShellStore.settings.desktopBackgroundOpacity ?? 30) / 100 : 0
    }

    // === CYBER GRID — horizontal perspective grid at bottom ===
    Canvas {
        id: cyberGrid
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: Math.min(420, parent.height * 0.52)
        visible: !root.signIn
        opacity: Theme.lightMode ? 0.18 : 0.42
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const horizon = 2
            const accent = Theme.focus
            // subtle horizontal lines converging
            ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.18)
            ctx.lineWidth = 1
            for (let i = 0; i < 14; i++) {
                const t = i / 13
                const y = horizon + Math.pow(t, 1.75) * (h - horizon)
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(w, y)
                ctx.stroke()
            }
            // vertical perspective lines
            const vCount = 28
            const vanishX = w / 2
            for (let i = 0; i <= vCount; i++) {
                const xBottom = (w / vCount) * i
                const xTop = vanishX + (xBottom - vanishX) * 0.02
                ctx.beginPath()
                ctx.moveTo(xTop, horizon)
                ctx.lineTo(xBottom, h)
                ctx.stroke()
            }
            // horizon glow
            const grad = ctx.createLinearGradient(0, horizon, 0, horizon + 26)
            grad.addColorStop(0, Qt.rgba(accent.r, accent.g, accent.b, 0.32))
            grad.addColorStop(1, "transparent")
            ctx.fillStyle = grad
            ctx.fillRect(0, horizon, w, 26)
        }
        onVisibleChanged: requestPaint()
        Connections { target: Theme; function onFocusChanged() { cyberGrid.requestPaint() } }
    }

    // Scanlines
    Canvas {
        anchors.fill: parent
        opacity: Theme.lightMode ? 0.04 : 0.09
        visible: !root.signIn
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            ctx.strokeStyle = Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 1)
            ctx.lineWidth = 1
            for (let y = 0; y < h; y += 4) {
                ctx.beginPath()
                ctx.moveTo(0, y + 0.5)
                ctx.lineTo(w, y + 0.5)
                ctx.stroke()
            }
        }
    }

    // Vignette + neon edge glow
    Rectangle {
        visible: root.signIn
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.18) }
            GradientStop { position: 0.4; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.55) }
            GradientStop { position: 1; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.82) }
        }
    }

    // Ambient neon orbs
    Rectangle {
        visible: !root.signIn && !root.customBackground
        x: parent.width * 0.62; y: -parent.height * 0.12
        width: parent.width * 0.55; height: width; radius: width/2
        color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, Theme.lightMode ? 0.08 : 0.11)
        layer.enabled: true
    }
    Rectangle {
        visible: !root.signIn && !root.customBackground
        x: -parent.width * 0.18; y: parent.height * 0.42
        width: parent.width * 0.48; height: width; radius: width/2
        color: Qt.rgba(Theme.mint.r, Theme.mint.g, Theme.mint.b, Theme.lightMode ? 0.06 : 0.09)
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.signIn && !root.customBackground && String(ShellStore.settings.desktopBackground || "art") !== "solid"
        z: String(ShellStore.settings.desktopBackground || "art") === "gradient" ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Theme.focus.r,Theme.focus.g,Theme.focus.b,
                String(ShellStore.settings.desktopBackground || "art") === "gradient" ? 0.24 : 0.08) }
            GradientStop { position: 0.4; color: "transparent" }
        }
    }
    // Cyber scrim: left solid, right fades to transparent letting grid breathe
    Rectangle {
        visible: !root.signIn
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, root.customBackground ? 0.88 : 0.94) }
            GradientStop { position: 0.38; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, root.customBackground ? 0.28 : 0.78) }
            GradientStop { position: 1; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, root.customBackground ? 0.42 : 0.86) }
        }
    }
    Rectangle {
        visible: !root.signIn
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, root.customBackground ? 0.20 : 0.52) }
        }
    }
    // Top neon hairline
    Rectangle {
        anchors.top: parent.top; width: parent.width; height: 1
        visible: !root.signIn
        color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.38)
        opacity: 0.9
    }
}
