pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomePoster — a PS5-style activity card.
// =============================================================================
//
// The home rails are built from these cards. Visually the card is a full-bleed
// piece of key art with an editorial deck melted into its bottom edge, exactly
// like a PS5 activity tile: art first, metadata second, one obvious action.
//
// Structure (top to bottom in z-order):
//   1. entrance reveal       — cards fade/slide in staggered by index
//   2. elevation shadow      — grows with hover so the card feels lifted
//   3. artwork stack         — base colour, RoundedArtwork, loading shimmer,
//                              specular gloss
//   4. readability scrims    — bottom deck scrim + idle/active variants
//   5. corner badges         — NEW, favourite star, membership lock, session
//   6. metadata deck         — title, publisher, genre, last played, time meter
//   7. capability pills      — store launchers + RTX/HDR/Reflex/DLSS glyphs
//                              (shared DesktopGameLabels so home matches library)
//   8. play overlay          — title + Play button, slides up on highlight
//   9. focus ring            — keyboard/controller ring, pointer hover ring
//  10. label tooltip         — explains the pills for screen readers/newcomers
//  11. input handlers        — hover, tap, activateAt() hit-testing
//
// Contracts kept from the previous home design:
//   * objectName is "desktopHomePoster-<game id>" (acceptance tests look it up)
//   * `current` marks the focused card; `activateAt(point)` splits the click
//     between the Play button and the card body (details)
//   * the artwork itself never scales — only the card does, so key art is not
//     zoomed twice
// =============================================================================
Item {
    id: root

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    required property var game

    /// Rail-supplied card footprint. Rails compute these from available width so
    /// a row always fits an exact number of cards without a dangling gap.
    property int tileWidth: DesktopTokens.posterWidth
    property int tileHeight: DesktopTokens.posterHeight + DesktopTokens.px(46)

    /// True while this card is the focused one (keyboard, controller or hover).
    property bool current: false

    /// Optional corner badge text ("NEW", "TOP", a rank number, …).
    property string badgeText: ""

    /// Optional rank shown in the opposite corner (e.g. "01" in a top-10 rail).
    property string rankText: ""

    /// Entrance stagger: cards reveal in sequence when a rail first appears.
    property int revealIndex: 0
    property real revealProgress: 1

    /// "slide" lifts the card in, "fade" crossfades it, "none" skips the
    /// entrance entirely (used for rails that re-sort while visible).
    property string revealMode: "slide"

    /// Marks the card the hero is currently featuring, so a rail can echo the
    /// spotlight without owning any of the hero's state.
    property bool featured: false

    /// Hide the secondary meta lines on narrow cards.
    property bool compactMeta: tileWidth < DesktopTokens.px(120)

    /// Show the metadata deck. The library can hide labels entirely; home keeps
    /// them because a rail card is the only place the title is readable.
    property bool labelsEnabled: ShellStore.settings.showTileLabels !== false

    signal activated()
    signal playRequested()
    signal pointed()
    signal favoriteToggled()

    // -------------------------------------------------------------------------
    // Derived state
    // -------------------------------------------------------------------------
    readonly property bool pointerHover: hoverHandler.hovered
    readonly property bool navigationFocus: current && AppController.inputMode !== "pointer"
    readonly property bool highlighted: pointerHover || navigationFocus
    readonly property bool pressed: tapHandler.pressed
    readonly property bool motionOff: AppController.reducedMotion

    readonly property string artwork: DesktopTokens.artworkUrl(game, false)
    readonly property string heroArtwork: DesktopTokens.artworkUrl(game, true)
    readonly property bool isFavorite: ShellStore.isFavorite(game)
    readonly property bool locked: ShellStore.gameLockedByMembership(game)
    readonly property bool labelsVisible: labelsEnabled

    readonly property string titleText: game ? String(game.title || qsTr("Game")) : qsTr("Game")
    readonly property string publisherText: {
        if (!game)
            return ""
        const publisher = game.publisherName || game.publisher
        return publisher ? String(publisher) : qsTr("Ready to stream")
    }
    readonly property string genreText: {
        if (!game || !game.genres || !game.genres.length)
            return ""
        return DesktopTokens.genreLabel(String(game.genres[0]))
    }
    readonly property string lastPlayedText: DesktopTokens.relativeLastPlayed(
        game ? game.lastPlayed : "", Date.now())
    readonly property string metaText: {
        const parts = []
        if (lastPlayedText !== "")
            parts.push(lastPlayedText)
        if (genreText !== "")
            parts.push(genreText)
        return parts.join("  ·  ")
    }

    /// Playtime is the only progression signal the catalog exposes, so the meter
    /// shows "time invested" capped at 40 hours — enough to separate a game you
    /// sampled from one you live in, without inventing completion data.
    readonly property real playHours: {
        if (!game)
            return 0
        const hours = Number(game.hoursPlayed || 0)
        return isFinite(hours) && hours > 0 ? hours : 0
    }
    readonly property real playProgress: playHours <= 0 ? 0 : Math.max(0.08, Math.min(1, playHours / 40))
    readonly property string playTimeText: playHours <= 0
        ? ""
        : playHours < 1 ? qsTr("%1 min").arg(Math.max(1, Math.round(playHours * 60)))
                        : qsTr("%1 h").arg(Math.round(playHours))

    readonly property bool hasSession: {
        const session = ShellStore.resumableSession
        if (!session || !game)
            return false
        return String(ShellStore.sessionGameTitle(session) || "") === titleText
    }

    /// Morph values drive every animated property so the whole card reacts as
    /// one object instead of a pile of independent tweens.
    property real hoverMorph: highlighted && !motionOff ? 1 : 0
    property real pressMorph: pressed && !motionOff ? 1 : 0

    function activateAt(position) {
        const play = overlay.playButton
        if (overlay.visible && play.contains(play.mapFromItem(root, position.x, position.y)))
            root.playRequested()
        else
            root.activated()
    }

    function toggleFavorite() {
        if (!game)
            return
        ShellStore.toggleFavorite(game)
        root.favoriteToggled()
    }

    // -------------------------------------------------------------------------
    // Geometry / identity
    // -------------------------------------------------------------------------
    objectName: "desktopHomePoster-" + String(game && game.id || "")
    width: tileWidth
    height: tileHeight
    z: highlighted || visual.scale !== 1 ? 20 : 0
    opacity: revealProgress
    transform: Translate {
        y: root.motionOff || root.revealMode === "none"
            ? 0 : (1 - root.revealProgress) * (root.revealMode === "fade" ? DesktopTokens.px(4) : DesktopTokens.px(14))
    }

    Accessible.role: Accessible.Button
    Accessible.name: titleText
    Accessible.description: {
        const parts = [publisherText]
        if (metaText !== "")
            parts.push(metaText)
        if (playTimeText !== "")
            parts.push(qsTr("%1 played").arg(playTimeText))
        if (isFavorite)
            parts.push(qsTr("Pinned"))
        if (locked)
            parts.push(qsTr("Needs a paid membership"))
        if (labels.summary !== "")
            parts.push(labels.summary)
        return parts.filter(part => part !== "").join(". ")
    }
    Accessible.onPressAction: root.activated()

    Behavior on hoverMorph {
        NumberAnimation { duration: root.motionOff ? 0 : 260; easing.type: Easing.OutCubic }
    }
    Behavior on pressMorph {
        NumberAnimation { duration: root.motionOff ? 0 : 110; easing.type: Easing.OutCubic }
    }
    Behavior on revealProgress {
        NumberAnimation { duration: root.motionOff ? 0 : Theme.duration(320); easing.type: Easing.OutCubic }
    }

    // Staggered entrance. `revealIndex` is ignored under reduced motion so the
    // rail appears complete immediately.
    Component.onCompleted: {
        if (motionOff || !visible) {
            root.revealProgress = 1
            return
        }
        root.revealProgress = 0
        revealDelay.interval = Math.min(240, 24 * Math.max(0, root.revealIndex))
        revealDelay.start()
    }
    onVisibleChanged: if (visible && revealProgress < 1) root.revealProgress = 1

    Timer {
        id: revealDelay
        interval: 0
        onTriggered: root.revealProgress = 1
    }

    // =========================================================================
    // 1-9. Card visual stack
    // =========================================================================
    Item {
        id: visual
        anchors.fill: parent
        // Only the card scales; the artwork inside never scales a second time.
        scale: 1 + 0.03 * root.hoverMorph - 0.012 * root.pressMorph
        transform: Translate { y: -DesktopTokens.px(4) * root.hoverMorph }
        transformOrigin: Item.Center

        // ---------------------------------------------------------------------
        // 2. Elevation shadow
        // ---------------------------------------------------------------------
        Rectangle {
            x: DesktopTokens.px(1)
            y: DesktopTokens.px(6) + DesktopTokens.px(4) * root.hoverMorph
            width: parent.width - DesktopTokens.px(2)
            height: parent.height - DesktopTokens.px(4)
            radius: DesktopTokens.px(16)
            color: Theme.lightMode ? "#28445A78" : "#80000000"
            opacity: 0.5 + 0.3 * root.hoverMorph
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // ---------------------------------------------------------------------
        // 3. Artwork stack
        // ---------------------------------------------------------------------
        RoundedArtwork {
            id: artworkView
            x: 0
            y: 0
            width: root.tileWidth
            height: root.tileHeight
            artwork: root.artwork
            fallbackArtwork: root.heroArtwork
            fallbackColor: "#171B27"
            cornerRadius: 12 + 4 * root.hoverMorph
            // The scrim tightens on highlight so the deck stays readable while
            // the card is lifted against the bright home backdrop.
            scrimStart: root.highlighted ? 0.30 : 0.55
        }

        // Placeholder over the art slot while no artwork URL is known yet.
        Rectangle {
            id: shimmer
            x: 0
            y: 0
            width: root.tileWidth
            height: root.tileHeight
            radius: DesktopTokens.px(14)
            visible: root.artwork === ""
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1D2433" }
                GradientStop { position: 1.0; color: "#121826" }
            }

            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(24)
                height: DesktopTokens.px(24)
                icon: "desktop-nav-library.svg"
                opacity: 0.45
            }
        }

        // Specular gloss: a soft diagonal sheen that brightens on hover, giving
        // the card the lacquered PS5 tile feel.
        Rectangle {
            x: 0
            y: 0
            width: root.tileWidth
            height: root.tileHeight
            radius: DesktopTokens.px(14)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10 + 0.14 * root.hoverMorph)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10 + 0.08 * root.hoverMorph) }
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ---------------------------------------------------------------------
        // 4. Readability scrims
        // ---------------------------------------------------------------------
        Rectangle {
            visible: root.labelsVisible
            x: 0
            y: root.tileHeight - DesktopTokens.px(84)
            width: root.tileWidth
            height: DesktopTokens.px(84)
            radius: DesktopTokens.px(12)
            gradient: Gradient {
                GradientStop { position: 0.00; color: "transparent" }
                GradientStop { position: 0.30; color: "#A8060911" }
                GradientStop { position: 1.00; color: "#F2060911" }
            }
        }

        // Idle dim keeps unfocused cards from competing with the focused one.
        Rectangle {
            x: 0
            y: 0
            width: root.tileWidth
            height: root.tileHeight
            radius: DesktopTokens.px(14)
            color: "#060911"
            opacity: 0.22 * (1 - root.hoverMorph)
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ---------------------------------------------------------------------
        // 5. Corner badges
        // ---------------------------------------------------------------------
        Rectangle {
            visible: root.badgeText !== ""
            x: DesktopTokens.px(8)
            y: DesktopTokens.px(8)
            width: badgeLabel.implicitWidth + DesktopTokens.px(14)
            height: DesktopTokens.px(20)
            radius: DesktopTokens.px(10)
            color: "#E6FFFFFF"
            border.width: 1
            border.color: "#FFFFFFFF"

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.badgeText
                color: "#0B0F1A"
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
                font.letterSpacing: 0.8
            }
        }

        Rectangle {
            visible: root.rankText !== "" && root.badgeText === ""
            x: DesktopTokens.px(8)
            y: DesktopTokens.px(8)
            width: DesktopTokens.px(24)
            height: DesktopTokens.px(20)
            radius: DesktopTokens.px(10)
            color: "#C4060911"
            border.width: 1
            border.color: "#33FFFFFF"

            Text {
                anchors.centerIn: parent
                text: root.rankText
                color: "#E8FFFFFF"
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
            }
        }

        // Favourite star — doubles as a toggle button while the card is hot.
        Rectangle {
            id: favoriteBadge
            objectName: "desktopHomePosterFavorite"
            visible: root.isFavorite || root.highlighted
            x: root.tileWidth - DesktopTokens.px(30)
            y: DesktopTokens.px(8)
            width: DesktopTokens.px(22)
            height: DesktopTokens.px(22)
            radius: DesktopTokens.px(11)
            color: root.isFavorite ? DesktopTokens.ledAmber : "#A8060911"
            border.width: 1
            border.color: root.isFavorite ? "#FFE9C7" : "#33FFFFFF"
            opacity: root.isFavorite ? 1 : 0.85
            scale: favoriteHover.hovered ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }

            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(12)
                height: DesktopTokens.px(12)
                icon: "desktop-star.svg"
            }
            HoverHandler {
                id: favoriteHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.toggleFavorite()
            }
            Accessible.role: Accessible.Button
            Accessible.name: root.isFavorite ? qsTr("Unpin %1").arg(root.titleText)
                                             : qsTr("Pin %1").arg(root.titleText)
        }

        // Membership lock.
        Rectangle {
            visible: root.locked
            x: root.tileWidth - DesktopTokens.px(30)
            y: DesktopTokens.px(34)
            width: DesktopTokens.px(22)
            height: DesktopTokens.px(22)
            radius: DesktopTokens.px(11)
            color: "#D90B0F1A"
            border.width: 1
            border.color: "#24FFFFFF"

            Image {
                anchors.centerIn: parent
                width: DesktopTokens.px(11)
                height: DesktopTokens.px(11)
                source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-lock.svg"
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
            }
            Accessible.role: Accessible.Indicator
            Accessible.name: qsTr("Needs a paid membership")
        }

        // Live session marker: this exact game is running right now.
        Rectangle {
            visible: root.hasSession
            x: DesktopTokens.px(8)
            y: root.tileHeight - DesktopTokens.px(30)
            width: sessionRow.implicitWidth + DesktopTokens.px(14)
            height: DesktopTokens.px(20)
            radius: DesktopTokens.px(10)
            color: "#CC0B3B2A"
            border.width: 1
            border.color: "#6656E6A5"

            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: DesktopTokens.px(5)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(6)
                    height: DesktopTokens.px(6)
                    radius: DesktopTokens.px(3)
                    color: DesktopTokens.mint

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: !root.motionOff
                        NumberAnimation { from: 1; to: 0.35; duration: 900 }
                        NumberAnimation { from: 0.35; to: 1; duration: 900 }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("RUNNING")
                    color: DesktopTokens.mint
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.Bold
                    font.letterSpacing: 0.9
                }
            }
        }

        // ---------------------------------------------------------------------
        // 6. Metadata deck
        // ---------------------------------------------------------------------
        Column {
            id: deck
            visible: root.labelsVisible
            x: DesktopTokens.px(10)
            // The deck slides down slightly when the play overlay appears so
            // both stay readable instead of stacking on top of each other.
            y: root.tileHeight - DesktopTokens.px(66) + (overlay.visible ? DesktopTokens.px(2) : 0)
            width: root.tileWidth - DesktopTokens.px(20)
            spacing: DesktopTokens.px(1)
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Text {
                objectName: "desktopHomePosterTitle"
                width: parent.width
                text: root.titleText
                color: Theme.mediaForeground
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: root.publisherText
                color: Theme.mediaMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                visible: root.metaText !== "" && !root.compactMeta
                width: parent.width
                text: root.metaText
                color: Theme.mediaMuted
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.tinySize
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Time-invested meter.
            Item {
                visible: root.playProgress > 0
                width: parent.width
                height: DesktopTokens.px(9)

                Rectangle {
                    id: meterTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (meterValue.visible ? meterValue.width + DesktopTokens.px(5) : 0)
                    height: DesktopTokens.px(4)
                    radius: DesktopTokens.px(2)
                    color: "#33FFFFFF"

                    Rectangle {
                        width: Math.max(DesktopTokens.px(4), parent.width * root.playProgress)
                        height: parent.height
                        radius: DesktopTokens.px(2)
                        color: DesktopTokens.mint
                        Behavior on width {
                            NumberAnimation { duration: root.motionOff ? 0 : 320; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    id: meterValue
                    visible: root.playTimeText !== ""
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.playTimeText
                    color: "#CCFFFFFF"
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.tinySize
                    font.weight: Font.Bold
                }
            }
        }

        // ---------------------------------------------------------------------
        // 7. Capability pills (stores + video features)
        // ---------------------------------------------------------------------
        DesktopGameLabels {
            id: labels
            x: DesktopTokens.px(8)
            y: DesktopTokens.px(8)
            width: root.tileWidth - DesktopTokens.px(16)
            height: root.tileHeight - DesktopTokens.px(16)
            game: root.game
            liftedBottom: overlay.visible ? overlay.height + DesktopTokens.px(10) : 0
        }

        // ---------------------------------------------------------------------
        // 8. Play overlay
        // ---------------------------------------------------------------------
        DesktopPosterOverlay {
            id: overlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: DesktopTokens.px(9)
            anchors.rightMargin: DesktopTokens.px(9)
            anchors.bottomMargin: DesktopTokens.px(10)
            game: root.game
            visible: root.highlighted
            opacity: root.highlighted ? 1 : 0
            transform: Translate { y: (1 - root.hoverMorph) * DesktopTokens.px(8) }
            Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 180 } }

            Accessible.role: Accessible.Pane
            Accessible.name: qsTr("Play %1").arg(root.titleText)
        }

        // ---------------------------------------------------------------------
        // 8b. Featured echo + press ripple
        // ---------------------------------------------------------------------
        Rectangle {
            visible: root.featured
            x: -DesktopTokens.px(4)
            y: -DesktopTokens.px(4)
            width: root.tileWidth + DesktopTokens.px(8)
            height: root.tileHeight + DesktopTokens.px(8)
            radius: DesktopTokens.px(18)
            color: "transparent"
            border.width: DesktopTokens.px(2)
            border.color: Qt.rgba(DesktopTokens.mint.r, DesktopTokens.mint.g, DesktopTokens.mint.b, 0.35)
        }

        Rectangle {
            id: ripple
            anchors.centerIn: parent
            width: root.tileWidth * 1.4
            height: width
            radius: width / 2
            color: "#FFFFFF"
            opacity: 0
            visible: opacity > 0.01

            SequentialAnimation {
                id: rippleAnimation
                running: false
                ParallelAnimation {
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.24; to: 0; duration: 440 }
                    NumberAnimation { target: ripple; property: "scale"; from: 0.3; to: 1; duration: 440; easing.type: Easing.OutCubic }
                }
                PropertyAction { target: ripple; property: "scale"; value: 0.3 }
            }
        }

        // ---------------------------------------------------------------------
        // 9. Focus ring
        // ---------------------------------------------------------------------
        Rectangle {
            id: focusRing
            objectName: "desktopHomePosterRing"
            x: -DesktopTokens.cardOutlinePad
            y: -DesktopTokens.cardOutlinePad
            width: root.tileWidth + DesktopTokens.cardOutlinePad * 2
            height: root.tileHeight + DesktopTokens.cardOutlinePad * 2
            radius: 14 + 4 * root.hoverMorph
            color: "transparent"
            border.width: root.highlighted ? 2 : 1
            border.color: root.navigationFocus ? DesktopTokens.focus
                : root.pointerHover ? Qt.rgba(1, 1, 1, 0.65)
                : DesktopTokens.cardOutlineIdle
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
            Behavior on border.width { NumberAnimation { duration: 120 } }
        }

        // Outer halo for keyboard/controller focus so the ring reads over art.
        Rectangle {
            visible: root.navigationFocus
            x: focusRing.x - DesktopTokens.px(3)
            y: focusRing.y - DesktopTokens.px(3)
            width: focusRing.width + DesktopTokens.px(6)
            height: focusRing.height + DesktopTokens.px(6)
            radius: focusRing.radius + DesktopTokens.px(3)
            color: "transparent"
            border.width: DesktopTokens.px(2)
            border.color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.28)
        }
    }

    // =========================================================================
    // 10. Tooltip explaining the capability pills
    // =========================================================================
    DesktopGameLabelTip {
        x: 0
        y: 0
        width: root.tileWidth
        height: root.tileHeight
        game: root.game
        requested: root.highlighted
    }

    // =========================================================================
    // 11. Input
    // =========================================================================
    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) root.pointed()
    }

    TapHandler {
        id: tapHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus | PointerDevice.TouchScreen
        onPressedChanged: {
            // pressMorph is already bound to `pressed`; the ripple only needs
            // the release edge.
            if (!pressed && !root.motionOff)
                rippleAnimation.restart()
        }
        onTapped: eventPoint => root.activateAt(eventPoint.position)
    }

    // Right-click / long-press pins the game, matching the console's options
    // menu shortcut without adding a context-menu dependency to the rail.
    TapHandler {
        acceptedDevices: PointerDevice.Mouse
        acceptedButtons: Qt.RightButton
        onTapped: root.toggleFavorite()
    }
}
