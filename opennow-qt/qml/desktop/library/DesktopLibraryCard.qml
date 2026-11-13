import QtQuick
import QtQuick.Controls
import QtQuick.Window
import OpenNOW

// A landscape library card: 16:9 key art with the play action over the artwork
// and a store/status chip beneath it. The view supplies the cell geometry; the
// label, tip and focus contracts stay inside the same interaction gutter.
ItemDelegate {
    id: root
    property var game: null
    property bool showTitle: true
    property int tileWidth: DesktopTokens.libraryCellWidth
    property int tileHeight: DesktopTokens.libraryCardHeight(tileWidth, showTitle)
    property int revealIndex: 0
    property real revealProgress: AppController.reducedMotion ? 1 : 0
    property real hoverMorph: 0
    property real pressMorph: 0
    readonly property int artGutter: DesktopTokens.libraryCardGutter
    readonly property int artWidth: DesktopTokens.libraryCardArtWidth(tileWidth)
    readonly property int artHeight: DesktopTokens.libraryCardArtHeight(tileWidth)
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
    readonly property bool ownedOnStore: {
        const variants = (root.game && root.game.variants) || []
        for (let i = 0; i < variants.length; ++i) {
            const variant = variants[i]
            if (!variant)
                continue
            if (variant.inLibrary === true
                || ["MANUAL", "PLATFORM_SYNC"].indexOf(String(variant.libraryStatus)) >= 0)
                return true
        }
        return false
    }
    readonly property bool freeToPlay: {
        const game = root.game
        if (!game)
            return false
        if (game.freeToPlay === true || game.isFree === true || game.storeFree === true)
            return true
        const price = String(game.storePrice || game.price || "").trim().toLowerCase()
        return price.indexOf("free") === 0
    }
    readonly property bool membershipLocked: ShellStore.gameLockedByMembership(game)
    readonly property bool comingSoon: {
        const state = String(root.game && root.game.playabilityState || "").toLowerCase()
        return state.indexOf("coming") >= 0 || state.indexOf("soon") >= 0 || state.indexOf("unreleased") >= 0
    }
    // One honest status line per card: what a player still needs before launch.
    readonly property string statusLabel: {
        if (!game)
            return qsTr("Ready to play")
        if (comingSoon)
            return qsTr("Coming soon")
        if (membershipLocked)
            return qsTr("Membership required")
        if (freeToPlay)
            return qsTr("Free to play")
        if (ownedOnStore)
            return qsTr("Ready to play")
        return qsTr("License required")
    }
    readonly property color statusColor: !game || comingSoon ? DesktopTokens.textFaint
        : membershipLocked ? (Theme.lightMode ? DesktopTokens.flightWarning : DesktopTokens.amber)
        : freeToPlay ? (Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.green)
        : ownedOnStore ? (Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.mint)
        : DesktopTokens.textBody
    signal contextRequested(real sceneX, real sceneY)
    signal playActivated()
    signal detailsActivated()
    Accessible.name: root.title
    Accessible.description: root.statusLabel + ". " + labels.summary
    width: tileWidth
    height: tileHeight
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    z: cardLifted || contentItem.scale !== 1 ? 20 : 1
    background: Item {}

    contentItem: Item {
        scale: AppController.reducedMotion ? 1 : 1 + 0.022 * root.hoverMorph - 0.024 * root.pressMorph
        opacity: root.revealProgress
        transform: Translate { y: DesktopTokens.px(14) * (1 - root.revealProgress) - DesktopTokens.px(4) * root.hoverMorph }
        transformOrigin: Item.Center

        // Two inexpensive offset surfaces create depth without a live blur on
        // every delegate in a large library grid.
        Rectangle {
            x: root.artGutter + 1
            y: root.artGutter + DesktopTokens.px(6)
            width: root.artWidth
            height: root.artHeight
            radius: DesktopTokens.px(18)
            color: Theme.lightMode ? "#24445A78" : "#70000000"
            opacity: 0.5 + 0.28 * root.hoverMorph
        }
        Rectangle {
            x: root.artGutter + 3
            y: root.artGutter + DesktopTokens.px(3)
            width: root.artWidth - 4
            height: root.artHeight - 2
            radius: DesktopTokens.px(17)
            color: Theme.lightMode ? "#18445A78" : "#48FFFFFF"
            opacity: Theme.lightMode ? 0.8 : 0.14
        }

        RoundedArtwork {
            id: art
            x: root.artGutter
            y: root.artGutter
            width: root.artWidth
            height: root.artHeight
            artwork: DesktopTokens.artworkUrl(root.game, true)
            cornerRadius: DesktopTokens.px(15 + 3 * root.hoverMorph)
            scrimStart: 0.52 - 0.1 * root.hoverMorph
            fallbackColor: "#1A2232"
        }

        // A quiet lower shade keeps the play action readable without hiding the
        // artwork or adding decorative objects on top of it.
        Rectangle {
            x: art.x
            y: art.y
            width: art.width
            height: art.height
            radius: art.cornerRadius
            opacity: 0.3 + 0.35 * root.hoverMorph
            gradient: Gradient {
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1; color: "#B0070C16" }
            }
        }
        Rectangle {
            x: art.x + 1
            y: art.y + 1
            width: art.width - 2
            height: 1
            color: "#44FFFFFF"
            opacity: 0.6
        }

        Rectangle {
            x: art.x - DesktopTokens.cardOutlinePad
            y: art.y - DesktopTokens.cardOutlinePad
            width: art.width + DesktopTokens.cardOutlinePad * 2
            height: art.height + DesktopTokens.cardOutlinePad * 2
            radius: DesktopTokens.px(17 + 3 * root.hoverMorph)
            color: "transparent"
            border.width: root.cardLifted ? 2 : 1
            border.color: root.cardLifted ? DesktopTokens.mint : DesktopTokens.cardOutlineIdle
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
        }

        Rectangle {
            anchors.right: art.right
            anchors.rightMargin: 10
            y: art.y + 10
            width: 24
            height: 24
            radius: 12
            visible: root.game && ShellStore.isFavorite(root.game)
                && !root.membershipLocked
            color: "#D90B1220"
            border.width: 1
            border.color: "#48FFFFFF"
            Image {
                anchors.centerIn: parent
                width: 13
                height: 13
                source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-star.svg"
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
            }
        }

        // Accent sweep from the theme focus colour toward violet: the same
        // treatment the full-screen detail view uses for its primary action.
        Rectangle {
            id: playPill
            objectName: "desktopLibraryCardPlay"
            x: art.x + DesktopTokens.px(12)
            y: art.y + art.height - height - DesktopTokens.px(12) - DesktopTokens.px(4) * root.hoverMorph
            width: Math.max(DesktopTokens.px(116), playRow.implicitWidth + DesktopTokens.px(28))
            height: DesktopTokens.px(38)
            radius: height / 2
            opacity: 0.9 + 0.1 * root.hoverMorph
            scale: playArea.pressed && !AppController.reducedMotion ? 0.97 : 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: playArea.pressed ? DesktopTokens.actionStartDown
                        : root.cardLifted ? DesktopTokens.actionStartHover : DesktopTokens.actionStart
                }
                GradientStop {
                    position: 1
                    color: playArea.pressed ? DesktopTokens.actionEndDown
                        : root.cardLifted ? DesktopTokens.actionEndHover : DesktopTokens.actionEnd
                }
            }
            Behavior on opacity { NumberAnimation { duration: DesktopTokens.quickDuration } }
            Behavior on scale { NumberAnimation { duration: DesktopTokens.quickDuration; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: parent.height * 0.46
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: "#3DFFFFFF" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 2
                border.color: DesktopTokens.focus
                visible: root.activeFocus && AppController.inputMode !== "pointer"
            }
            Row {
                id: playRow
                anchors.centerIn: parent
                spacing: DesktopTokens.px(8)
                DesktopGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(15)
                    height: DesktopTokens.px(15)
                    icon: "desktop-play-filled.svg"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("PLAY")
                    color: DesktopTokens.actionInk
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    font.weight: Font.Black
                    font.letterSpacing: 1.1
                }
            }
            Accessible.name: qsTr("Play %1").arg(root.title)
            MouseArea {
                id: playArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playActivated()
            }
        }

        Rectangle {
            id: detailsChip
            objectName: "desktopLibraryCardDetails"
            anchors.left: playPill.right
            anchors.leftMargin: DesktopTokens.px(8)
            y: playPill.y
            width: DesktopTokens.px(38)
            height: DesktopTokens.px(38)
            radius: DesktopTokens.px(13)
            // A narrow cell keeps the play pill alone rather than squeezing the
            // details chip over the artwork.
            visible: playPill.x + playPill.width + DesktopTokens.px(8) + width
                <= art.x + art.width - DesktopTokens.px(8)
            opacity: 0.86 + 0.14 * root.hoverMorph
            color: detailsArea.containsMouse ? "#E6161F2E" : "#CC0B1220"
            border.width: 1
            border.color: root.activeFocus && AppController.inputMode !== "pointer"
                ? DesktopTokens.focus : "#3EFFFFFF"
            Behavior on opacity { NumberAnimation { duration: DesktopTokens.quickDuration } }
            Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
            Image {
                anchors.centerIn: parent
                width: DesktopTokens.px(17)
                height: DesktopTokens.px(17)
                source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-expand.svg"
                sourceSize: Qt.size(Math.max(1, Math.round(width * Screen.devicePixelRatio)),
                                    Math.max(1, Math.round(height * Screen.devicePixelRatio)))
                fillMode: Image.PreserveAspectFit
            }
            Accessible.name: qsTr("View details for %1").arg(root.title)
            MouseArea {
                id: detailsArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detailsActivated()
            }
        }

        DesktopGameLabels {
            id: labels
            x: art.x + 10
            y: art.y + 8
            width: Math.max(1, art.width - 20)
            height: Math.max(1, art.height - 16)
            game: root.game
            liftedBottom: playPill.height + DesktopTokens.px(20)
        }

        Text {
            id: titleLabel
            visible: root.showTitle
            x: art.x + 2
            y: art.y + art.height + DesktopTokens.libraryCardTitleGap
            width: art.width - 4
            height: DesktopTokens.libraryCardTitleHeight
            text: root.title
            textFormat: Text.PlainText
            color: root.cardLifted ? DesktopTokens.textHigh : DesktopTokens.text
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 1
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.captionSize
            font.weight: Font.Bold
            Behavior on color { ColorAnimation { duration: Theme.focusDuration } }
        }

        // Status chip: the store the license comes from plus what still stands
        // between the player and a launch.
        Rectangle {
            id: statusChip
            objectName: "desktopLibraryCardStatus"
            x: art.x + 2
            y: root.showTitle ? titleLabel.y + titleLabel.height + DesktopTokens.libraryCardTitleSpacing
                                : art.y + art.height + DesktopTokens.libraryCardChipGap
            width: Math.min(art.width - 4, statusRow.implicitWidth + DesktopTokens.px(18))
            height: DesktopTokens.libraryCardChipHeight
            radius: height / 2
            color: Theme.lightMode ? "#E4EAF2" : "#8A131C2A"
            border.width: 1
            border.color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b,
                                  root.cardLifted ? 0.5 : 0.24)
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                x: DesktopTokens.px(9)
                spacing: DesktopTokens.px(6)
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(13)
                    height: DesktopTokens.px(13)
                    visible: source.toString() !== ""
                    source: root.membershipLocked && root.primaryStoreIcon === ""
                        ? "qrc:/qt/qml/OpenNOW/res/icons/desktop-lock.svg" : root.primaryStoreIcon
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.92
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.statusLabel
                    textFormat: Text.PlainText
                    color: root.statusColor
                    elide: Text.ElideRight
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.Bold
                }
            }
        }
    }

    DesktopGameLabelTip {
        x: root.artGutter
        y: root.artGutter
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
        PauseAnimation { duration: Math.min(root.revealIndex, 10) * 45 }
        NumberAnimation {
            target: root
            property: "revealProgress"
            from: 0
            to: 1
            duration: 380
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
