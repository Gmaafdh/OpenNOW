import QtQuick
import QtQuick.Controls
import OpenNOW

// A gallery card for the desktop library. The view supplies the cell geometry;
// the label and focus contracts stay inside the same interaction gutter.
ItemDelegate {
    id: root
    property var game: null
    property bool showTitle: false
    property bool showPlay: false
    property bool selected: activeFocus
    property int tileWidth: DesktopTokens.libraryCellWidth
    property int tileHeight: showTitle ? DesktopTokens.px(300) : DesktopTokens.libraryCellHeight
    property int revealIndex: 0
    property real revealProgress: AppController.reducedMotion ? 1 : 0
    property real hoverMorph: 0
    readonly property int artGutter: 6
    readonly property int framePadding: 6
    readonly property int artWidth: Math.max(1, tileWidth - 2 * (artGutter + framePadding))
    readonly property int artHeight: Math.max(1, Math.round(artWidth * 198 / 132))
    readonly property bool cardLifted: hovered || activeFocus
    onCardLiftedChanged: {
        morphAnimation.stop()
        if (AppController.reducedMotion) {
            hoverMorph = 0
        } else {
            morphAnimation.from = hoverMorph
            morphAnimation.to = cardLifted ? 1 : 0
            morphAnimation.start()
        }
    }
    readonly property string title: game ? String(game.title || qsTr("Game")) : qsTr("Game")
    readonly property string secondaryLabel: {
        if (!game)
            return qsTr("GeForce NOW")
        if (game.publisherName)
            return String(game.publisherName)
        if (game.genres && game.genres.length)
            return DesktopTokens.genreLabel(game.genres[0])
        return qsTr("GeForce NOW")
    }
    signal contextRequested(real sceneX, real sceneY)
    Accessible.name: root.title
    Accessible.description: labels.summary
    width: tileWidth
    height: tileHeight
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    z: cardLifted || contentItem.scale !== 1 ? 20 : 1
    background: Item {}

    contentItem: Item {
        scale: AppController.reducedMotion ? 1 : root.down ? 0.98
            : (0.94 + 0.06 * root.revealProgress) * (1 + 0.035 * root.hoverMorph)
        opacity: root.revealProgress
        transform: Translate { y: DesktopTokens.px(22) * (1 - root.revealProgress) - DesktopTokens.px(6) * root.hoverMorph }
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Theme.focusDuration; easing.type: Easing.OutCubic } }

        Rectangle {
            id: cardFrame
            x: root.artGutter
            y: root.artGutter
            width: root.tileWidth - root.artGutter * 2
            height: root.tileHeight - root.artGutter * 2
            radius: DesktopTokens.px(18 + 4 * root.hoverMorph)
            color: Theme.lightMode ? "#F0F3F8" : "#D9141D2B"
            border.width: 1
            border.color: root.cardLifted
                ? Qt.rgba(DesktopTokens.mint.r, DesktopTokens.mint.g, DesktopTokens.mint.b, 0.68)
                : DesktopTokens.seamSoft
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
        }

        RoundedArtwork {
            id: art
            x: root.artGutter + root.framePadding
            y: root.artGutter + root.framePadding
            width: root.artWidth
            height: root.artHeight
            artwork: DesktopTokens.artworkUrl(root.game, false)
            cornerRadius: DesktopTokens.px(14 + 4 * root.hoverMorph)
            scrimStart: root.showPlay ? 0.42 : 0.68 - 0.22 * root.hoverMorph
            fallbackColor: "#1A2232"
            scale: 1 + 0.025 * root.hoverMorph
            transformOrigin: Item.Center
        }

        // A quiet lower shade keeps the hover action readable without hiding
        // the artwork or adding decorative objects on top of it.
        Rectangle {
            x: art.x
            y: art.y
            width: art.width
            height: art.height
            radius: art.cornerRadius
            opacity: 0.42 + 0.28 * root.hoverMorph
            gradient: Gradient {
                GradientStop { position: 0.38; color: "transparent" }
                GradientStop { position: 1; color: "#B80B1220" }
            }
        }
        Rectangle {
            x: art.x + 1
            y: art.y + 1
            width: art.width - 2
            height: 1
            color: "#44FFFFFF"
            opacity: 0.65
        }

        Rectangle {
            x: art.x + 10
            y: art.y + 10
            width: 40
            height: 20
            radius: 6
            color: "#B80B1220"
            border.width: 1
            border.color: "#38FFFFFF"
            Text {
                anchors.centerIn: parent
                text: "GFN"
                color: DesktopTokens.mint
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.Black
                font.letterSpacing: 1
            }
        }
        Rectangle {
            anchors.right: art.right
            anchors.rightMargin: 10
            y: art.y + 10
            width: 24
            height: 24
            radius: 12
            visible: root.game && ShellStore.isFavorite(root.game)
                && !ShellStore.gameLockedByMembership(root.game)
            color: "#D90B1220"
            border.width: 1
            border.color: "#48FFFFFF"
            DesktopGlyph {
                anchors.centerIn: parent
                width: 13
                height: 13
                icon: "desktop-star.svg"
            }
        }

        Rectangle {
            x: art.x - DesktopTokens.cardOutlinePad
            y: art.y - DesktopTokens.cardOutlinePad
            width: art.width + DesktopTokens.cardOutlinePad * 2
            height: art.height + DesktopTokens.cardOutlinePad * 2
            radius: DesktopTokens.px(16 + 4 * root.hoverMorph)
            color: "transparent"
            border.width: root.cardLifted ? 2 : 1
            border.color: root.cardLifted ? DesktopTokens.mint : DesktopTokens.cardOutlineIdle
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
        }

        DesktopPosterOverlay {
            id: posterOverlay
            x: art.x + 9
            anchors.bottom: art.bottom
            anchors.bottomMargin: DesktopTokens.px(12)
            width: Math.max(0, art.width - 18)
            game: root.game
            visible: root.cardLifted
        }
        DesktopGameLabels {
            id: labels
            x: art.x + 8
            y: art.y + 8
            width: Math.max(1, art.width - 16)
            height: Math.max(1, art.height - 16)
            game: root.game
            liftedBottom: posterOverlay.visible ? posterOverlay.height + 10 : 0
        }

        Rectangle {
            id: infoDeck
            visible: root.showTitle
            x: art.x
            y: art.y + art.height + 6
            width: art.width
            height: Math.max(0, root.tileHeight - y - 12)
            radius: 10
            color: Theme.lightMode ? "#E8EDF4" : "#701F2A3A"
            border.width: 1
            border.color: root.cardLifted ? "#38FFFFFF" : DesktopTokens.seamSoft
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
        }
        Column {
            id: titleColumn
            visible: root.showTitle
            x: art.x + 10
            y: art.y + art.height + 12
            width: art.width - 20
            height: Math.max(0, root.tileHeight - y - 12)
            spacing: DesktopTokens.px(4)

            Text {
                width: parent.width
                height: DesktopTokens.px(34)
                text: root.title
                textFormat: Text.PlainText
                color: DesktopTokens.textHigh
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Bold
                verticalAlignment: Text.AlignTop
            }
            Text {
                width: parent.width
                text: root.secondaryLabel
                textFormat: Text.PlainText
                color: DesktopTokens.textMuted
                elide: Text.ElideRight
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
            }
            Item {
                width: parent.width
                height: DesktopTokens.px(18)
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - DesktopTokens.px(22))
                    text: root.game && root.game.price ? String(root.game.price) : qsTr("Available")
                    color: root.cardLifted ? DesktopTokens.mint : DesktopTokens.textMuted
                    elide: Text.ElideRight
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.DemiBold
                }
                DesktopGlyph {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(14)
                    height: width
                    visible: root.cardLifted
                    icon: "desktop-play.svg"
                }
            }
        }
    }

    DesktopGameLabelTip {
        x: root.artGutter + root.framePadding
        y: root.artGutter + root.framePadding
        width: root.artWidth
        height: root.artHeight
        game: root.game
        requested: root.hovered || (root.activeFocus && AppController.inputMode !== "pointer")
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: point => {
            const scene = root.mapToItem(null, point.position.x, point.position.y)
            root.contextRequested(scene.x, scene.y)
        }
    }
    SequentialAnimation {
        id: revealAnimation
        PauseAnimation { duration: Math.min(root.revealIndex, 10) * 55 }
        NumberAnimation {
            target: root
            property: "revealProgress"
            from: 0
            to: 1
            duration: 540
            easing.type: Easing.OutBack
        }
    }
    NumberAnimation {
        id: morphAnimation
        target: root
        property: "hoverMorph"
        duration: 420
        easing.type: Easing.OutBack
    }
    Component.onCompleted: if (!AppController.reducedMotion) revealAnimation.start()
    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion) {
                revealAnimation.stop()
                morphAnimation.stop()
                root.revealProgress = 1
                root.hoverMorph = 0
            }
        }
    }
}
