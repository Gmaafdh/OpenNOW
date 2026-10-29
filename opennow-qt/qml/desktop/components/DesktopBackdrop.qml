import QtQuick
import OpenNOW

// Ambience layer. Key art is the star; the shell adds depth with layered
// vignettes, an accent aurora at the top corners, and a soft horizon glow so
// glass panels always have something to sit on.
Item {
    id: root
    objectName: root.signIn ? "signInBackdrop" : "desktopBackdrop"
    property string artwork: ShellStore.catalogGames.length
        ? DesktopTokens.artworkUrl(ShellStore.catalogGames[0], true) : ""
    property bool signIn: false
    readonly property bool customBackground: !root.signIn && ShellStore.settings.desktopBackground === "custom"
    readonly property bool artBackground: root.signIn || String(ShellStore.settings.desktopBackground || "art") === "art"
    readonly property string normalizedArtwork: root.artwork !== ""
        ? DesktopTokens.decodeArtworkUrl(root.artwork)
        : root.signIn ? "qrc:/qt/qml/OpenNOW/res/brand/signin-hero.jpg" : "qrc:/qt/qml/OpenNOW/res/brand/desktop-renew.jpg"

    ArtworkSource {
        id: artworkSource
        sourceUrl: root.normalizedArtwork
        active: root.visible && root.artBackground
    }

    Rectangle {
        anchors.fill: parent
        color: root.signIn ? Theme.shell : DesktopTokens.shell
    }

    // Base tone: a vertical wash so the top of the window is darker than the
    // middle, which keeps the header readable over any artwork.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(DesktopTokens.shell.r, DesktopTokens.shell.g, DesktopTokens.shell.b, 0.98)
            }
            GradientStop {
                position: 0.5
                color: Qt.rgba(DesktopTokens.shell.r, DesktopTokens.shell.g, DesktopTokens.shell.b, 0.90)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(DesktopTokens.shell.r, DesktopTokens.shell.g, DesktopTokens.shell.b, 1)
            }
        }
    }

    Item {
        anchors.fill: parent
        clip: true
        Image {
            id: art
            width: parent.width
            height: parent.height * (root.signIn ? 1.18 : 1)
            y: root.signIn ? -parent.height * 0.12 : 0
            source: artworkSource.resolvedUrl
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(1440, 900)
            opacity: status === Image.Ready && root.artBackground ? (root.signIn ? 1 : 0.72) : 0
            Behavior on opacity { NumberAnimation { duration: DesktopTokens.revealDuration } }
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

    Rectangle {
        visible: root.signIn
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#B80B0F1A" }
            GradientStop { position: 0.4; color: "#990B0F1A" }
            GradientStop { position: 1; color: "#D60B0F1A" }
        }
    }
    Rectangle {
        visible: root.signIn
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#F2070A11" }
            GradientStop { position: 0.5; color: "#00000000" }
            GradientStop { position: 1; color: "#F2070A11" }
        }
    }

    // Aurora: two wide accent washes pinned to the top corners. They never sit
    // behind body copy, only behind chrome and cards.
    Item {
        anchors.fill: parent
        visible: !root.customBackground || root.signIn
        clip: true

        Rectangle {
            width: parent.width * 0.62
            height: DesktopTokens.px(420)
            x: -parent.width * 0.14
            y: -DesktopTokens.px(210)
            rotation: -9
            opacity: 0.55
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.20) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            width: parent.width * 0.5
            height: DesktopTokens.px(380)
            x: parent.width * 0.62
            y: -DesktopTokens.px(190)
            rotation: 7
            opacity: 0.4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(Theme.violet.r, Theme.violet.g, Theme.violet.b, 0.20) }
            }
        }
        // Slow drift keeps the shell alive without stealing attention.
        SequentialAnimation on opacity {
            running: root.visible && !AppController.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { to: 0.75; duration: 9000; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1; duration: 9000; easing.type: Easing.InOutQuad }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.signIn
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b,
                               root.customBackground ? 0.86 : 0.94)
            }
            GradientStop {
                position: 0.3
                color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b,
                               root.customBackground ? 0.20 : 0.72)
            }
            GradientStop {
                position: 0.72
                color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b,
                               root.customBackground ? 0.36 : 0.80)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b,
                               root.customBackground ? 0.30 : 0.94)
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.signIn
        gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 0.62; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.24) }
            GradientStop { position: 1; color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.86) }
        }
    }
    // Corner vignette: darkens the frame and pushes focus inward.
    Rectangle {
        anchors.fill: parent
        visible: !root.signIn
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#3D000000" }
            GradientStop { position: 0.18; color: "#00000000" }
            GradientStop { position: 0.82; color: "#00000000" }
            GradientStop { position: 1; color: "#3D000000" }
        }
    }
}
