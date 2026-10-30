import QtQuick
import QtQuick.Effects
import OpenNOW

Item {
    id: root
    property string artwork: ""
    property string fallbackArtwork: ""
    property color fallbackColor: Theme.cartSteam
    property real cornerRadius: 34
    property real scrimStart: 0.28
    // Wide hero surfaces use a contained foreground over a soft cover backdrop.
    // This keeps key art intact instead of enlarging it until faces disappear.
    property bool cinematicFit: false
    property bool alignArtworkRight: false

    property bool loadStarted: false
    readonly property string normalizedArtwork: DesktopTokens.decodeArtworkUrl(root.artwork)
    readonly property string normalizedFallback: DesktopTokens.decodeArtworkUrl(root.fallbackArtwork)
    onNormalizedArtworkChanged: if (!visible) loadStarted = false
    onNormalizedFallbackChanged: if (!visible) loadStarted = false
    // Retained popups keep their resolved artwork between opens, avoiding a
    // fallback flash and another image fade every time visibility changes.
    onVisibleChanged: if (visible) loadStarted = true
    Component.onCompleted: if (visible)
        loadStarted = true

    ArtworkSource {
        id: artworkSource
        sourceUrl: root.normalizedArtwork
        active: root.loadStarted
        requestActive: root.visible
    }
    ArtworkSource {
        id: fallbackSource
        sourceUrl: root.normalizedFallback
        active: root.loadStarted && root.normalizedFallback !== ""
        requestActive: root.visible
    }

    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: Theme.radius(root.cornerRadius)
        color: "white"
        visible: false
        layer.enabled: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundedMask
            maskThresholdMin: 0.25
            maskSpreadAtMin: 0.2
        }

        Rectangle { anchors.fill: parent; color: root.fallbackColor }
        Image {
            id: cinematicBackdrop
            objectName: "roundedArtworkCinematicBackdrop"
            anchors.fill: parent
            visible: root.cinematicFit
            source: root.cinematicFit ? (artworkImage.status === Image.Ready ? artworkSource.resolvedUrl : fallbackSource.resolvedUrl) : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 0.58 : 0
            layer.enabled: visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.65
                blurMax: 48
                saturation: 0.72
            }
            Behavior on opacity { NumberAnimation { duration: Theme.heroDuration } }
        }
        Image {
            id: artworkImage
            objectName: "roundedArtworkPrimary"
            anchors.fill: parent
            source: artworkSource.resolvedUrl
            fillMode: root.cinematicFit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            horizontalAlignment: root.cinematicFit && root.alignArtworkRight ? Image.AlignRight : Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            sourceSize: root.cinematicFit ? Qt.size(-1, Math.ceil(height)) : Qt.size(Math.ceil(width), Math.ceil(height))
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.heroDuration } }
        }
        Image {
            id: fallbackImage
            objectName: "roundedArtworkFallback"
            anchors.fill: parent
            source: fallbackSource.resolvedUrl
            fillMode: root.cinematicFit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            horizontalAlignment: root.cinematicFit && root.alignArtworkRight ? Image.AlignRight : Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            sourceSize: root.cinematicFit ? Qt.size(-1, Math.ceil(height)) : Qt.size(Math.ceil(width), Math.ceil(height))
            asynchronous: true
            cache: true
            opacity: status === Image.Ready && artworkImage.status !== Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.heroDuration } }
        }
        Rectangle {
            anchors.fill: parent
            visible: root.scrimStart < 1
            gradient: Gradient {
                GradientStop { position: Math.max(0, Math.min(0.99, root.scrimStart)); color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.82) }
            }
        }
    }
}
