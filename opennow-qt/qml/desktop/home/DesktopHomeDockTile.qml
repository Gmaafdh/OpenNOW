pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomeDockTile — one icon in the PS5-style home dock.
// =============================================================================
//
// The PS5 home bar is a row of square icons where the focused icon grows, gains
// a ring and reveals its name underneath. This tile reproduces that behaviour
// for OpenNOW games and for the two system entries (Library, Store) that keep
// the whole shell reachable from one row.
//
// Structure:
//   1. ambient glow          — theme accent bloom behind the focused tile
//   2. elevation shadow      — lifts with selection
//   3. tile face             — RoundedArtwork for games, glass + glyph for
//                              system entries, with a placeholder while loading
//   4. surface finish        — specular gloss, inner seam, hover tint
//   5. selection ring        — white over art, accent over glass, plus halo
//   6. status badges         — favourite star, membership lock, running session
//   7. playtime arc          — Canvas arc showing hours invested (focused only)
//   8. play affordance       — circular Play button revealed on highlight
//   9. label + meta          — title and publisher revealed on highlight
//  10. input + accessibility — hover, tap, press feedback, screen-reader data
// =============================================================================
Item {
    id: root
    objectName: "desktopHomeDockTile"

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    /// Game payload for game tiles; null for system tiles.
    property var game: null

    /// "game" renders artwork, "system" renders a glyph on glass.
    property string kind: "game"

    /// System tile chrome.
    property string systemLabel: ""
    property string systemIcon: ""
    property string systemRoute: ""

    /// Selection state driven by the dock (and by the hero for auto-cycle).
    property bool selected: false

    /// Tile footprint. The dock sizes all tiles identically so the row reads as
    /// one bar; the selected tile grows from this base.
    property int tileSize: DesktopTokens.px(76)

    /// Optional corner badge ("NEW", a rank, …).
    property string badgeText: ""

    /// Position in the dock, used for the accessible description and stagger.
    property int tileIndex: 0

    /// Rank text drawn in the corner for ranked rails ("01", "02", …).
    property string rankText: ""

    /// Show the store launcher dots under the label while selected.
    property bool showLaunchers: true

    /// Caption drawn under the label for the featured tile.
    property string featuredCaption: ""

    /// Press feedback strength (0..1), animated by the tap handler.
    property real pressMorph: 0

    signal activated()
    signal pointed()
    signal playRequested()
    signal favoriteToggled()

    // -------------------------------------------------------------------------
    // Derived state
    // -------------------------------------------------------------------------
    readonly property bool isGame: kind === "game" && game !== null
    readonly property bool motionOff: AppController.reducedMotion
    readonly property bool pointerHover: tileHover.hovered
    readonly property bool highlighted: selected || pointerHover
    readonly property bool pressed: tileTap.pressed

    readonly property string artwork: isGame ? DesktopTokens.artworkUrl(game, false) : ""
    readonly property string heroArtwork: isGame ? DesktopTokens.artworkUrl(game, true) : ""
    readonly property string titleText: isGame
        ? String(game.title || qsTr("Game"))
        : (systemLabel !== "" ? systemLabel : qsTr("Open"))
    readonly property string subtitleText: {
        if (!isGame)
            return systemRoute !== "" ? qsTr("Open %1").arg(systemLabel) : ""
        const publisher = game.publisherName || game.publisher
        if (publisher)
            return String(publisher)
        const last = DesktopTokens.relativeLastPlayed(game.lastPlayed, Date.now())
        return last !== "" ? last : qsTr("Ready to stream")
    }
    readonly property bool isFavorite: isGame && ShellStore.isFavorite(game)
    readonly property bool locked: isGame && ShellStore.gameLockedByMembership(game)
    readonly property bool hasSession: {
        const session = ShellStore.resumableSession
        if (!session || !isGame)
            return false
        return String(ShellStore.sessionGameTitle(session) || "") === titleText
    }
    readonly property real playHours: {
        if (!isGame)
            return 0
        const hours = Number(game.hoursPlayed || 0)
        return isFinite(hours) && hours > 0 ? hours : 0
    }
    readonly property real arcProgress: playHours <= 0 ? 0 : Math.max(0.06, Math.min(0.98, playHours / 40))
    readonly property string lastPlayedText: isGame
        ? DesktopTokens.relativeLastPlayed(game.lastPlayed, Date.now()) : ""
    /// Store launchers that actually have an icon, in the store order the rest
    /// of the desktop shell uses.
    readonly property var launchers: isGame && showLaunchers
        ? ConsoleStores.launchers(game).filter(item => DesktopTokens.storeIconUrl(item.store) !== "").slice(0, 3)
        : []
    readonly property string playTimeText: playHours <= 0 ? ""
        : playHours < 1 ? qsTr("%1 min played").arg(Math.max(1, Math.round(playHours * 60)))
                        : qsTr("%1 h played").arg(Math.round(playHours))

    /// Grown size while selected: the PS5 icon expands noticeably.
    readonly property real grow: selected ? 1 : 0
    readonly property real hoverLift: pointerHover && !selected ? 1 : 0
    readonly property real faceSize: tileSize + DesktopTokens.px(16) * grow + DesktopTokens.px(4) * hoverLift
    readonly property real faceRadius: DesktopTokens.px(18) + DesktopTokens.px(6) * grow

    width: tileSize + DesktopTokens.px(26)
    height: tileSize + DesktopTokens.px(44)
    z: selected ? 30 : (pointerHover ? 20 : 0)

    Accessible.role: Accessible.Button
    Accessible.name: titleText
    Accessible.description: {
        const parts = [subtitleText]
        if (lastPlayedText !== "")
            parts.push(qsTr("Last played %1").arg(lastPlayedText))
        if (playHours > 0)
            parts.push(qsTr("%1 hours played").arg(Math.round(playHours)))
        if (isFavorite)
            parts.push(qsTr("Pinned"))
        if (locked)
            parts.push(qsTr("Needs a paid membership"))
        if (hasSession)
            parts.push(qsTr("Session running"))
        return parts.filter(part => part !== "").join(". ")
    }
    Accessible.onPressAction: root.activated()

    // -------------------------------------------------------------------------
    // 1. Ambient glow behind the focused tile
    // -------------------------------------------------------------------------
    Rectangle {
        id: glow
        anchors.centerIn: face
        width: face.width + DesktopTokens.px(34)
        height: face.height + DesktopTokens.px(34)
        radius: width / 2
        color: root.isGame ? Theme.focus : DesktopTokens.mint
        opacity: 0.30 * root.grow + 0.10 * root.hoverLift
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 220 } }
        Behavior on width { NumberAnimation { duration: root.motionOff ? 0 : 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: root.motionOff ? 0 : 220; easing.type: Easing.OutCubic } }
    }

    // Secondary bloom so the glow reads against bright artwork.
    Rectangle {
        anchors.centerIn: face
        width: face.width + DesktopTokens.px(18)
        height: face.height + DesktopTokens.px(18)
        radius: width / 2
        color: "#FFFFFF"
        opacity: 0.10 * root.grow
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 220 } }
    }

    // -------------------------------------------------------------------------
    // 2. Elevation shadow
    // -------------------------------------------------------------------------
    Rectangle {
        x: face.x + DesktopTokens.px(1)
        y: face.y + DesktopTokens.px(7) + DesktopTokens.px(3) * root.grow
        width: face.width
        height: face.height
        radius: root.faceRadius + DesktopTokens.px(6)
        color: Theme.lightMode ? "#28445A78" : "#8C000000"
        opacity: 0.45 + 0.30 * root.grow
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on radius { NumberAnimation { duration: root.motionOff ? 0 : 220 } }
    }

    // -------------------------------------------------------------------------
    // 3-8. Tile face
    // -------------------------------------------------------------------------
    Item {
        id: face
        x: (root.width - face.width) / 2
        y: DesktopTokens.px(6)
        width: root.faceSize
        height: root.faceSize
        scale: 1 - 0.02 * root.pressMorph
        transformOrigin: Item.Center
        Behavior on width { NumberAnimation { duration: root.motionOff ? 0 : 240; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: root.motionOff ? 0 : 240; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.motionOff ? 0 : 110; easing.type: Easing.OutCubic } }

        // Game artwork.
        RoundedArtwork {
            id: gameArt
            visible: root.isGame
            anchors.fill: parent
            artwork: root.artwork
            fallbackArtwork: root.heroArtwork
            fallbackColor: "#171B27"
            cornerRadius: root.faceRadius
            // Keep most of the art bright; the dock sits on a dark scrim.
            scrimStart: root.selected ? 0.55 : 0.9
        }

        // Placeholder while a game has no artwork URL.
        Rectangle {
            visible: root.isGame && root.artwork === ""
            anchors.fill: parent
            radius: root.faceRadius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1D2433" }
                GradientStop { position: 1.0; color: "#121826" }
            }
            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(24)
                height: DesktopTokens.px(24)
                icon: "desktop-nav-library.svg"
                opacity: 0.5
            }
        }

        // System tile face (Library / Store).
        Rectangle {
            id: systemFace
            visible: !root.isGame
            anchors.fill: parent
            radius: root.faceRadius
            color: root.selected ? (Theme.lightMode ? "#111827" : "#FFFFFF") : DesktopTokens.raisedStrong
            border.width: 1
            border.color: root.selected ? "transparent" : DesktopTokens.seam
            Behavior on color { ColorAnimation { duration: 180 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, root.selected ? 0.0 : 0.10)
            }

            DesktopGlyph {
                id: systemGlyph
                anchors.centerIn: parent
                width: DesktopTokens.px(28)
                height: DesktopTokens.px(28)
                icon: root.systemIcon
                scale: 1 + 0.06 * root.grow
                Behavior on scale { NumberAnimation { duration: root.motionOff ? 0 : 220; easing.type: Easing.OutCubic } }
            }
        }

        // ---------------------------------------------------------------------
        // 4. Surface finish
        // ---------------------------------------------------------------------
        Rectangle {
            anchors.fill: parent
            radius: root.faceRadius
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.14 + 0.10 * root.grow) }
                GradientStop { position: 0.42; color: "transparent" }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.10) }
            }
        }

        // Idle dim so unfocused tiles recede behind the hero.
        Rectangle {
            anchors.fill: parent
            radius: root.faceRadius
            color: "#060911"
            opacity: 0.30 * (1 - root.grow) * (1 - 0.5 * root.hoverLift)
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ---------------------------------------------------------------------
        // 5. Selection ring
        // ---------------------------------------------------------------------
        Rectangle {
            id: ring
            anchors.fill: parent
            anchors.margins: -DesktopTokens.px(3)
            radius: root.faceRadius + DesktopTokens.px(3)
            color: "transparent"
            border.width: root.selected ? DesktopTokens.px(3) : 1
            border.color: root.selected
                ? (root.isGame ? "#FFFFFF" : Theme.focus)
                : (root.pointerHover ? Qt.rgba(1, 1, 1, 0.55) : DesktopTokens.cardOutlineIdle)
            Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
            Behavior on border.width { NumberAnimation { duration: 140 } }
        }

        Rectangle {
            visible: root.selected
            anchors.fill: ring
            anchors.margins: -DesktopTokens.px(3)
            radius: ring.radius + DesktopTokens.px(3)
            color: "transparent"
            border.width: DesktopTokens.px(2)
            border.color: root.isGame ? "#59FFFFFF" : Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.35)
        }

        // ---------------------------------------------------------------------
        // 6. Status badges
        // ---------------------------------------------------------------------
        Rectangle {
            id: favoriteBadge
            objectName: "desktopDockTileFavorite"
            visible: root.isFavorite || root.highlighted
            x: parent.width - DesktopTokens.px(24)
            y: -DesktopTokens.px(6)
            width: DesktopTokens.px(22)
            height: DesktopTokens.px(22)
            radius: DesktopTokens.px(11)
            color: root.isFavorite ? DesktopTokens.ledAmber : "#B8060911"
            border.width: 1
            border.color: root.isFavorite ? "#FFE9C7" : "#33FFFFFF"
            scale: favoriteHover.hovered ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }

            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(12)
                height: DesktopTokens.px(12)
                icon: "desktop-star.svg"
            }
            HoverHandler { id: favoriteHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (root.isGame)
                        root.favoriteToggled()
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: root.isFavorite ? qsTr("Unpin %1").arg(root.titleText)
                                             : qsTr("Pin %1").arg(root.titleText)
        }

        Rectangle {
            visible: root.locked && !root.isFavorite
            x: parent.width - DesktopTokens.px(24)
            y: -DesktopTokens.px(6)
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
        }

        Rectangle {
            visible: root.hasSession
            x: -DesktopTokens.px(6)
            y: -DesktopTokens.px(6)
            width: DesktopTokens.px(22)
            height: DesktopTokens.px(22)
            radius: DesktopTokens.px(11)
            color: "#E60B3B2A"
            border.width: 1
            border.color: "#8056E6A5"

            Rectangle {
                anchors.centerIn: parent
                width: DesktopTokens.px(8)
                height: DesktopTokens.px(8)
                radius: DesktopTokens.px(4)
                color: DesktopTokens.mint
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: !root.motionOff
                    NumberAnimation { from: 1; to: 0.4; duration: 800 }
                    NumberAnimation { from: 0.4; to: 1; duration: 800 }
                }
            }
            Accessible.role: Accessible.Indicator
            Accessible.name: qsTr("Session running")
        }

        // Press ripple: a soft circle that expands from the tile centre once
        // per tap, so touch and click both get confirmation.
        Rectangle {
            id: ripple
            anchors.centerIn: parent
            width: parent.width * 1.6
            height: width
            radius: width / 2
            color: "#FFFFFF"
            opacity: 0
            visible: opacity > 0.01

            SequentialAnimation {
                id: rippleAnimation
                running: false
                ParallelAnimation {
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.30; to: 0; duration: 420 }
                    NumberAnimation { target: ripple; property: "scale"; from: 0.35; to: 1; duration: 420; easing.type: Easing.OutCubic }
                }
                PropertyAction { target: ripple; property: "scale"; value: 0.35 }
            }
        }

        Rectangle {
            visible: root.rankText !== "" && root.badgeText === ""
            x: -DesktopTokens.px(4)
            y: parent.height - DesktopTokens.px(16)
            width: DesktopTokens.px(24)
            height: DesktopTokens.px(18)
            radius: DesktopTokens.px(9)
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

        Rectangle {
            visible: root.badgeText !== ""
            x: -DesktopTokens.px(4)
            y: parent.height - DesktopTokens.px(16)
            width: badgeLabel.implicitWidth + DesktopTokens.px(12)
            height: DesktopTokens.px(18)
            radius: DesktopTokens.px(9)
            color: "#E6FFFFFF"

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.badgeText
                color: "#0B0F1A"
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
                font.letterSpacing: 0.6
            }
        }

        // ---------------------------------------------------------------------
        // 7. Playtime arc (focused game tiles only)
        // ---------------------------------------------------------------------
        Loader {
            id: playArcLoader
            anchors.fill: parent
            anchors.margins: -DesktopTokens.px(8)
            // Only the selected tile pays for a canvas; the rest stay empty.
            active: root.isGame && root.selected && root.arcProgress > 0
            sourceComponent: Canvas {
                id: playArc
                property real progress: root.arcProgress
                anchors.fill: parent
                antialiasing: true
                onProgressChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const cx = width / 2
                    const cy = height / 2
                    const radius = Math.min(width, height) / 2 - 2
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    // Track.
                    ctx.beginPath()
                    ctx.strokeStyle = "rgba(255,255,255,0.18)"
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                    ctx.stroke()
                    // Progress from 12 o'clock clockwise.
                    ctx.beginPath()
                    ctx.strokeStyle = "#56E6A5"
                    ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress)
                    ctx.stroke()
                }
            }
        }

        // ---------------------------------------------------------------------
        // 8. Play affordance
        // ---------------------------------------------------------------------
        Rectangle {
            id: playBadge
            objectName: "desktopDockTilePlay"
            visible: root.isGame && root.highlighted
            anchors.centerIn: parent
            width: DesktopTokens.px(34)
            height: DesktopTokens.px(34)
            radius: DesktopTokens.px(17)
            color: "#E6FFFFFF"
            border.width: 1
            border.color: "#FFFFFFFF"
            opacity: root.highlighted ? 1 : 0
            scale: playHover.hovered ? 1.1 : 1
            Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 160 } }
            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(16)
                height: DesktopTokens.px(16)
                icon: "desktop-play-filled.svg"
            }
            HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (root.isGame)
                        root.playRequested()
                    else
                        root.activated()
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Play %1").arg(root.titleText)
        }
    }

    // -------------------------------------------------------------------------
    // 9. Label + meta under the tile
    // -------------------------------------------------------------------------
    Column {
        id: labelBlock
        anchors.top: face.bottom
        anchors.topMargin: DesktopTokens.px(7)
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width
        spacing: 0
        opacity: root.selected ? 1 : (root.pointerHover ? 0.8 : 0)
        transform: Translate { y: (1 - root.grow) * DesktopTokens.px(4) }
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 180 } }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.titleText
            color: Theme.mediaForeground
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
            font.weight: Font.ExtraBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.selected && root.subtitleText !== ""
            text: root.subtitleText
            color: Theme.mediaMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.tinySize
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.selected && root.playTimeText !== ""
            text: root.playTimeText
            color: DesktopTokens.mint
            font.family: DesktopTokens.monoFont
            font.pixelSize: DesktopTokens.microSize
            font.weight: Font.Bold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // Store launcher dots: which connected stores can actually launch this
        // game. Mirrors the pills on the rail cards at dock scale.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.selected && root.launchers.length > 0
            spacing: DesktopTokens.px(4)

            Repeater {
                model: root.launchers
                Image {
                    required property var modelData
                    width: DesktopTokens.px(12)
                    height: DesktopTokens.px(12)
                    source: DesktopTokens.storeIconUrl(modelData.store)
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                    opacity: modelData.owned ? 1 : 0.55
                    Accessible.role: Accessible.Indicator
                    Accessible.name: modelData.owned
                        ? qsTr("Owned on %1").arg(DesktopTokens.storeLabel(modelData.store))
                        : DesktopTokens.storeLabel(modelData.store)
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.selected && root.featuredCaption !== ""
            width: featuredLabel.implicitWidth + DesktopTokens.px(12)
            height: DesktopTokens.px(16)
            radius: DesktopTokens.px(8)
            color: "#1F4BD49D"
            border.width: 1
            border.color: "#554BD49D"

            Text {
                id: featuredLabel
                anchors.centerIn: parent
                text: root.featuredCaption
                color: DesktopTokens.mint
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
                font.letterSpacing: 0.9
            }
        }
    }

    // -------------------------------------------------------------------------
    // 10. Input
    // -------------------------------------------------------------------------
    HoverHandler {
        id: tileHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered)
                root.pointed()
        }
    }

    TapHandler {
        id: tileTap
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus | PointerDevice.TouchScreen
        onPressedChanged: {
            root.pressMorph = pressed ? 1 : 0
            if (!pressed && !root.motionOff)
                rippleAnimation.restart()
        }
        onTapped: root.activated()
    }

    Behavior on pressMorph {
        NumberAnimation { duration: root.motionOff ? 0 : 110; easing.type: Easing.OutCubic }
    }
}
