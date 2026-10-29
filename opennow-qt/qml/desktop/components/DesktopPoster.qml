import QtQuick
import QtQuick.Controls
import OpenNOW

// Gallery card for the desktop library. Artwork is the card: a single rounded
// image, a bottom scrim, and a type deck underneath with no heavy frame. Focus
// and reveal contracts stay inside the same interaction gutter.
ItemDelegate {
    id: root
    property var game: null
    property bool showTitle: false
    property bool showPlay: false
    property bool selected: activeFocus
    property int tileWidth: DesktopTokens.libraryCellWidth
    property int tileHeight: showTitle ? artHeight + DesktopTokens.px(126) : DesktopTokens.libraryCellHeight
    property int revealIndex: 0
    property real revealProgress: AppController.reducedMotion ? 1 : 0
    property real hoverMorph: 0
    property real pressMorph: 0
    readonly property int artGutter: 5
    readonly property int framePadding: 0
    readonly property int artWidth: Math.max(1, tileWidth - 2 * artGutter)
    readonly property int artHeight: Math.max(1, Math.round(artWidth * 198 / 132))
    readonly property bool cardLifted: hovered || activeFocus
    onDownChanged: {
        pressAnimation.stop()
        if (AppController.reducedMotion) {
            pressMorph = 0
        } else {
            pressAnimation.from = pressMorph
            pressAnimation.to = down ? 1 : 0
            pressAnimation.start()
        }
    }
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
        if (game.publisherName || game.publisher)
            return String(game.publisherName || game.publisher)
        if (game.genres && game.genres.length)
            return DesktopTokens.genreLabel(game.genres[0])
        return qsTr("GeForce NOW")
    }
    readonly property string primaryStore: {
        if (!game)
            return ""
        const stores = game.availableStores || []
        if (stores.length)
            return String(stores[0])
        const variants = game.variants || []
        for (let i = 0; i < variants.length; ++i) {
            if (variants[i] && variants[i].store)
                return String(variants[i].store)
        }
        return ""
    }
    readonly property string primaryStoreIcon: DesktopTokens.storeIconUrl(primaryStore)
    readonly property var featureKeys: DesktopTokens.gameFeatures(game)
    readonly property bool favorite: game && ShellStore.isFavorite(game)
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
        scale: AppController.reducedMotion ? 1 : 1 + 0.028 * root.hoverMorph - 0.03 * root.pressMorph
        opacity: root.revealProgress
        transform: Translate { y: DesktopTokens.px(16) * (1 - root.revealProgress) - DesktopTokens.px(5) * root.hoverMorph }
        transformOrigin: Item.Center

        // Contact shadow: one soft offset layer, no live blur per delegate.
        Rectangle {
            x: root.artGutter
            y: root.artGutter + DesktopTokens.px(8)
            width: root.artWidth
            height: root.artHeight
            radius: DesktopTokens.radiusMd + 2
            color: Theme.lightMode ? "#1F1E293B" : "#80000000"
            opacity: 0.5 + 0.3 * root.hoverMorph
        }

        RoundedArtwork {
            id: art
            x: root.artGutter
            y: root.artGutter
            width: root.artWidth
            height: root.artHeight
            artwork: DesktopTokens.artworkUrl(root.game, false)
            cornerRadius: DesktopTokens.radiusMd + 2
            scrimStart: 1
            fallbackColor: "#1A2232"
        }

        // Bottom shade inside the artwork: seats the hover action and the
        // store badge without hiding the key art.
        Rectangle {
            x: art.x
            y: art.y
            width: art.width
            height: art.height
            radius: art.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0.44; color: "transparent" }
                GradientStop { position: 1; color: "#CC070B14" }
            }
        }
        // Hairline that turns accent when the card is lifted.
        Rectangle {
            x: art.x
            y: art.y
            width: art.width
            height: art.height
            radius: art.cornerRadius
            color: "transparent"
            border.width: root.cardLifted ? 2 : 1
            border.color: root.cardLifted
                ? DesktopTokens.focus
                : (Theme.lightMode ? "#1F0B0F1A" : "#2BFFFFFF")
            Behavior on border.color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
        }

        // Store badge, top-left.
        Rectangle {
            x: art.x + DesktopTokens.px(9)
            y: art.y + DesktopTokens.px(9)
            width: root.primaryStoreIcon !== "" ? DesktopTokens.px(26) : DesktopTokens.px(40)
            height: DesktopTokens.px(23)
            radius: DesktopTokens.radiusPill
            color: Qt.rgba(0, 0, 0, 0.46)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)
            Image {
                anchors.centerIn: parent
                visible: root.primaryStoreIcon !== ""
                width: DesktopTokens.px(14)
                height: width
                source: root.primaryStoreIcon
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
            }
            Text {
                anchors.centerIn: parent
                visible: root.primaryStoreIcon === ""
                text: "GFN"
                color: DesktopTokens.mint
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.px(8)
                font.weight: Font.Black
                font.letterSpacing: 0.8
            }
        }

        // Feature pips, bottom-left of the artwork.
        Row {
            x: art.x + DesktopTokens.px(9)
            anchors.bottom: art.bottom
            anchors.bottomMargin: DesktopTokens.px(9)
            spacing: DesktopTokens.px(4)
            visible: root.featureKeys.length > 0

            Repeater {
                model: root.featureKeys
                delegate: Rectangle {
                    id: featurePip
                    required property string modelData
                    width: DesktopTokens.px(20)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.46)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    Image {
                        anchors.centerIn: parent
                        width: DesktopTokens.px(11)
                        height: width
                        source: DesktopTokens.featureIconUrl(featurePip.modelData)
                        sourceSize: Qt.size(24, 24)
                        fillMode: Image.PreserveAspectFit
                    }
                    ToolTip.visible: pipHover.hovered
                    ToolTip.text: DesktopTokens.featureTip(featurePip.modelData)
                    ToolTip.delay: 320
                    HoverHandler { id: pipHover }
                }
            }
        }

        // Favourite marker, top-right.
        Rectangle {
            anchors.right: art.right
            anchors.rightMargin: DesktopTokens.px(9)
            y: art.y + DesktopTokens.px(9)
            width: DesktopTokens.px(22)
            height: width
            radius: width / 2
            visible: root.favorite && !ShellStore.gameLockedByMembership(root.game)
            color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.86)
            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(11)
                height: width
                icon: "desktop-star.svg"
            }
        }

        DesktopPosterOverlay {
            id: posterOverlay
            x: art.x + DesktopTokens.px(9)
            anchors.bottom: art.bottom
            anchors.bottomMargin: DesktopTokens.px(10)
            width: Math.max(0, art.width - DesktopTokens.px(18))
            game: root.game
            visible: root.cardLifted && root.showPlay
        }
        DesktopGameLabels {
            id: labels
            x: art.x + DesktopTokens.px(8)
            y: art.y + DesktopTokens.px(8)
            width: Math.max(1, art.width - DesktopTokens.px(16))
            height: Math.max(1, art.height - DesktopTokens.px(16))
            game: root.game
            liftedBottom: posterOverlay.visible ? posterOverlay.height + DesktopTokens.px(10) : 0
        }

        // Type deck: title, publisher, then a live meta line.
        Column {
            id: titleColumn
            visible: root.showTitle
            x: art.x + DesktopTokens.px(3)
            y: art.y + art.height + DesktopTokens.px(11)
            width: art.width - DesktopTokens.px(6)
            height: Math.max(0, root.tileHeight - y - DesktopTokens.px(8))
            spacing: DesktopTokens.px(3)

            Text {
                width: parent.width
                text: root.title
                textFormat: Text.PlainText
                color: root.cardLifted ? DesktopTokens.textHigh : DesktopTokens.textBody
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Bold
                lineHeight: 1.12
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
            Row {
                width: parent.width
                height: DesktopTokens.px(18)
                spacing: DesktopTokens.px(5)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(5)
                    height: width
                    radius: width / 2
                    color: root.cardLifted ? DesktopTokens.mint : DesktopTokens.green
                    opacity: root.cardLifted ? 1 : 0.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - DesktopTokens.px(22))
                    text: root.game && root.game.price ? String(root.game.price) : qsTr("Ready to play")
                    color: root.cardLifted ? DesktopTokens.mint : DesktopTokens.textMuted
                    elide: Text.ElideRight
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.3
                }
                DesktopGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(11)
                    height: width
                    visible: root.cardLifted
                    opacity: 0.9
                    rotation: -90
                    icon: "desktop-chevron-down.svg"
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
            duration: 420
            easing.type: Easing.OutCubic
        }
    }
    NumberAnimation {
        id: pressAnimation
        target: root
        property: "pressMorph"
        duration: 90
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: morphAnimation
        target: root
        property: "hoverMorph"
        duration: 240
        easing.type: Easing.OutCubic
    }
    Component.onCompleted: if (!AppController.reducedMotion) revealAnimation.start()
    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion) {
                revealAnimation.stop()
                morphAnimation.stop()
                pressAnimation.stop()
                root.revealProgress = 1
                root.hoverMorph = 0
                root.pressMorph = 0
            }
        }
    }
}
