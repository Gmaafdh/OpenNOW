import QtQuick
import QtQuick.Controls
import OpenNOW

// Library artwork with a persistent information deck. The view supplies the
// cell geometry; decoration stays inside the six-pixel interaction gutter.
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
    readonly property int artGutter: 6
    readonly property int framePadding: 6
    readonly property int artWidth: Math.max(1, tileWidth - 2 * (artGutter + framePadding))
    readonly property int artHeight: Math.max(1, Math.round(artWidth * 198 / 132))
    readonly property bool cardLifted: hovered || activeFocus
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
    // Keep focus geometry inside the delegate so GridView clipping never cuts
    // off the top/left ring while the card scales up.
    width: tileWidth
    height: tileHeight
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    // Keep pointer/focus bounds stationary while only the card zooms.
    z: cardLifted || contentItem.scale !== 1 ? 20 : 1
    background: Item {}
    contentItem: Item {
        scale: AppController.reducedMotion ? 1 : root.down ? 0.985 : root.cardLifted ? DesktopTokens.cardHoverScale : 1
        opacity: root.revealProgress
        transform: Translate { y: DesktopTokens.px(12) * (1 - root.revealProgress) }
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Theme.focusDuration; easing.type: Easing.OutCubic } }

        Rectangle {
            id: cardFrame
            x: root.artGutter
            y: root.artGutter
            width: root.tileWidth - root.artGutter * 2
            height: root.tileHeight - root.artGutter * 2
            radius: DesktopTokens.px(16)
            color: Theme.glassStrong
            border.width: 1
            border.color: root.cardLifted
                ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.48)
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
            cornerRadius: DesktopTokens.px(12)
            scrimStart: root.cardLifted || root.showPlay ? 0.3 : 0.82
            fallbackColor: "#1A2232"
        }
        Rectangle {
            x: art.x - DesktopTokens.cardOutlinePad
            y: art.y - DesktopTokens.cardOutlinePad
            width: art.width + DesktopTokens.cardOutlinePad * 2
            height: art.height + DesktopTokens.cardOutlinePad * 2
            radius: DesktopTokens.px(14)
            color: "transparent"
            border.width: root.cardLifted ? 2 : 1
            border.color: root.cardLifted ? DesktopTokens.focus : DesktopTokens.cardOutlineIdle
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
        Column {
            id: titleColumn
            visible: root.showTitle
            x: art.x
            y: art.y + art.height + DesktopTokens.px(8)
            width: art.width
            height: Math.max(0, root.tileHeight - y - DesktopTokens.px(12))
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
                font.weight: Font.DemiBold
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
                    color: DesktopTokens.textMuted
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
        PauseAnimation { duration: Math.min(root.revealIndex, 8) * 35 }
        NumberAnimation {
            target: root
            property: "revealProgress"
            from: 0
            to: 1
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    Component.onCompleted: if (!AppController.reducedMotion) revealAnimation.start()
    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion) {
                revealAnimation.stop()
                root.revealProgress = 1
            }
        }
    }
}
