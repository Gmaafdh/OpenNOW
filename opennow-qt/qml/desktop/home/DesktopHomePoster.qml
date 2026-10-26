pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

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
        NumberAnimation { duration: 320; easing.type: Easing.OutBack }
    }

    Item {
        id: visual
        anchors.fill: parent
        scale: 1 + 0.045 * root.hoverMorph
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Theme.focusDuration; easing.type: Easing.OutCubic } }

        RoundedArtwork {
            id: artworkView
            x: 0
            y: 0
            width: root.tileWidth
            height: root.artHeight
            artwork: root.artwork
            fallbackColor: "#171B27"
            cornerRadius: 12 + 8 * root.hoverMorph
            scrimStart: root.highlighted ? 0.3 : 0.86
            scale: 1 + 0.045 * root.hoverMorph
            transformOrigin: Item.Center
        }

        Rectangle {
            id: infoDeck
            x: 0
            y: root.artHeight - 1
            width: root.tileWidth
            height: root.infoHeight + 1
            radius: 12 + 8 * root.hoverMorph
            color: Theme.lightMode ? "#F0F3F8" : "#E617202D"
            border.width: 1
            border.color: root.highlighted ? DesktopTokens.focus : DesktopTokens.cardOutlineIdle
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }

            Rectangle {
                x: 1
                y: 0
                width: parent.width - 2
                height: 12
                color: parent.color
            }
            Text {
                x: 10
                y: 7
                width: parent.width - 20
                text: root.game ? String(root.game.title || qsTr("Game")) : qsTr("Game")
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                x: 10
                y: 27
                width: parent.width - 48
                text: root.game && (root.game.publisherName || root.game.publisher)
                    ? String(root.game.publisherName || root.game.publisher)
                    : qsTr("Ready to stream")
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.tinySize
                elide: Text.ElideRight
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 6 + 8 * root.hoverMorph
                height: 6 + 8 * root.hoverMorph
                radius: width / 2
                color: DesktopTokens.focus
                opacity: 0.45 + 0.55 * root.hoverMorph
            }
        }

        Rectangle {
            x: -DesktopTokens.cardOutlinePad
            y: -DesktopTokens.cardOutlinePad
            width: root.tileWidth + DesktopTokens.cardOutlinePad * 2
            height: root.tileHeight + DesktopTokens.cardOutlinePad * 2
            radius: 14 + 8 * root.hoverMorph
            color: "transparent"
            border.width: root.highlighted ? 2 : 1
            border.color: root.highlighted ? DesktopTokens.focus : DesktopTokens.cardOutlineIdle
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
        }

        DesktopPosterOverlay {
            id: overlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: artworkView.bottom
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.bottomMargin: 12
            game: root.game
            visible: root.highlighted
        }

        DesktopGameLabels {
            id: labels
            x: 8
            y: 8
            width: root.tileWidth - 16
            height: root.artHeight - 16
            game: root.game
            liftedBottom: overlay.visible ? overlay.height + 10 : 0
        }
    }

    DesktopGameLabelTip {
        x: 0
        y: 0
        width: root.tileWidth
        height: root.artHeight
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
