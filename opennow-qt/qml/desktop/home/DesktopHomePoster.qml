pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// Home rail tile. Artwork only: the title lives on the art in a bottom scrim so
// the rail reads as one continuous strip of posters rather than a wall of boxes.
Item {
    id: root

    required property var game
    property int tileWidth: DesktopTokens.posterWidth
    property int tileHeight: DesktopTokens.posterHeight + DesktopTokens.px(46)
    property bool current: false
    readonly property bool pointerHover: hoverHandler.hovered
    readonly property bool navigationFocus: current && AppController.inputMode !== "pointer"
    readonly property bool highlighted: pointerHover || navigationFocus
    readonly property string artwork: DesktopTokens.artworkUrl(game, false)
    readonly property int infoHeight: DesktopTokens.px(46)
    readonly property int artHeight: Math.max(1, tileHeight - infoHeight)
    readonly property var featureKeys: DesktopTokens.gameFeatures(game)
    property real hoverMorph: highlighted && !AppController.reducedMotion ? 1 : 0

    signal activated()
    signal playRequested()
    signal pointed()

    function activateAt(position) {
        const play = overlay.playButton
        if (overlay.visible && play.contains(play.mapFromItem(root, position.x, position.y)))
            root.playRequested()
        else
            root.activated()
    }

    objectName: "desktopHomePoster-" + String(game && game.id || "")
    width: tileWidth
    height: tileHeight
    z: highlighted || visual.scale !== 1 ? 20 : 0
    Accessible.role: Accessible.Button
    Accessible.name: game ? String(game.title || qsTr("Game")) : qsTr("Game")
    Accessible.description: labels.summary

    Behavior on hoverMorph {
        NumberAnimation { duration: AppController.reducedMotion ? 0 : 240; easing.type: Easing.OutCubic }
    }

    Item {
        id: visual
        anchors.fill: parent
        scale: 1 + 0.03 * root.hoverMorph
        transform: Translate { y: -DesktopTokens.px(6) * root.hoverMorph }
        transformOrigin: Item.Center

        // Contact shadow under the card.
        Rectangle {
            x: 2
            y: DesktopTokens.px(7)
            width: parent.width - 4
            height: parent.height - DesktopTokens.px(9)
            radius: DesktopTokens.radiusMd + 2
            color: Theme.lightMode ? "#241E293B" : "#8C000000"
            opacity: 0.5 + 0.3 * root.hoverMorph
        }

        RoundedArtwork {
            id: artworkView
            x: 0
            y: 0
            width: root.tileWidth
            height: root.height - DesktopTokens.px(2)
            artwork: root.artwork
            fallbackColor: "#171B27"
            cornerRadius: DesktopTokens.radiusMd + 2
            scrimStart: 1
        }

        // Bottom scrim carries the title and meta over the art.
        Rectangle {
            x: 0
            y: 0
            width: artworkView.width
            height: artworkView.height
            radius: artworkView.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0.42; color: "transparent" }
                GradientStop { position: 0.76; color: "#73070B14" }
                GradientStop { position: 1; color: "#E6070B14" }
            }
        }

        // Focus / hover ring, drawn outside the art so nothing is cropped.
        Rectangle {
            x: -DesktopTokens.cardOutlinePad
            y: -DesktopTokens.cardOutlinePad
            width: artworkView.width + DesktopTokens.cardOutlinePad * 2
            height: artworkView.height + DesktopTokens.cardOutlinePad * 2
            radius: artworkView.cornerRadius + DesktopTokens.cardOutlinePad
            color: "transparent"
            border.width: root.highlighted ? 2 : 1
            border.color: root.highlighted ? DesktopTokens.focus : (Theme.lightMode ? "#1A0B0F1A" : "#24FFFFFF")
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
        }

        // Title deck, on the artwork.
        Column {
            x: DesktopTokens.px(10)
            anchors.bottom: artworkView.bottom
            anchors.bottomMargin: DesktopTokens.px(10)
            width: artworkView.width - DesktopTokens.px(20)
            spacing: DesktopTokens.px(1)

            Text {
                width: parent.width
                text: root.game ? String(root.game.title || qsTr("Game")) : qsTr("Game")
                color: "#FFFFFF"
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.px(12)
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
                style: Text.Raised
                styleColor: "#80000000"
            }
            Row {
                spacing: DesktopTokens.px(5)
                width: parent.width
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(4)
                    height: width
                    radius: width / 2
                    color: DesktopTokens.focus
                    opacity: 0.65 + 0.35 * root.hoverMorph
                }
                Text {
                    width: Math.max(0, parent.width - DesktopTokens.px(10))
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.game && (root.game.publisherName || root.game.publisher)
                        ? String(root.game.publisherName || root.game.publisher)
                        : qsTr("Ready to stream")
                    color: Qt.rgba(1, 1, 1, 0.68)
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.tinySize
                    elide: Text.ElideRight
                }
            }
        }

        DesktopPosterOverlay {
            id: overlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: artworkView.bottom
            anchors.leftMargin: DesktopTokens.px(9)
            anchors.rightMargin: DesktopTokens.px(9)
            anchors.bottomMargin: DesktopTokens.px(46)
            game: root.game
            visible: root.highlighted
        }

        DesktopGameLabels {
            id: labels
            x: DesktopTokens.px(8)
            y: DesktopTokens.px(8)
            width: root.tileWidth - DesktopTokens.px(16)
            height: artworkView.height - DesktopTokens.px(16)
            game: root.game
            liftedBottom: overlay.visible ? overlay.height + DesktopTokens.px(46) : 0
        }
    }

    DesktopGameLabelTip {
        x: 0
        y: 0
        width: root.tileWidth
        height: artworkView.height
        game: root.game
        requested: root.highlighted
    }

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) root.pointed()
    }

    TapHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus | PointerDevice.TouchScreen
        onTapped: eventPoint => root.activateAt(eventPoint.position)
    }
}
