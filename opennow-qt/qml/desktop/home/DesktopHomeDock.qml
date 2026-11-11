pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomeDock — the PS5-style icon bar that drives the home hero.
// =============================================================================
//
// One horizontal row of game icons. The focused icon becomes the hero: the dock
// publishes `selectedIndex`, the screen points the showcase at that slide and
// the backdrop crossfades to that game's art. Two system tiles (Library, Store)
// close the row so the whole shell is reachable without leaving home.
//
// Scroll contract: the dock owns its own horizontal scrolling. Pointer hover
// updates the selection but never scrolls the page; explicit keyboard or
// controller navigation scrolls the dock just far enough to reveal the focused
// tile. The parent page is never moved by hover.
//
// Sections:
//   1. caption strip   — which group the focused tile belongs to + counts
//   2. tile row        — games, then system tiles, inside a Flickable
//   3. edge treatment  — fades and chevrons so tiles melt into the backdrop
//   4. skeleton state  — shimmering placeholders while the catalog syncs
//   5. hints           — keyboard/controller affordances and accessibility
// =============================================================================
Item {
    id: root
    objectName: "desktopHomeDock"

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    property var games: []
    property int selectedIndex: 0
    property bool active: true
    property bool showSystemTiles: true
    property bool loading: false
    /// How many leading games count as "recently played" for the caption.
    property int recentCount: 5
    /// Tile footprint shared with DesktopHomeDockTile.
    property int tileSize: DesktopTokens.px(76)

    /// "comfortable" is the console-like default; "compact" fits more icons on
    /// short windows without shrinking the art into mush.
    property string density: "comfortable"

    /// Publishes the hovered game so the screen can preview it without moving
    /// keyboard focus (the hero only follows real focus, never the cursor).
    property var hoveredGame: null

    /// Animate dock scrolling. Off under reduced motion.
    property bool animatedScroll: true

    /// Row label shown before the system tiles, mirroring the PS5 split between
    /// your games and the console's own entries.
    property string systemCaption: qsTr("OPENNOW")

    signal gameActivated(var game)
    signal gamePointed(int index)
    signal gamePlayRequested(var game)
    signal gameFavoriteToggled(var game)
    signal systemActivated(string route)
    signal pointed(int index)
    /// Emitted whenever the pointer moves on/off a game tile. Owners use it to
    /// warm artwork caches; it never implies a focus change.
    signal gameHovered(var game)

    // -------------------------------------------------------------------------
    // Derived geometry
    // -------------------------------------------------------------------------
    readonly property int gameCount: (games || []).length
    readonly property int systemCount: showSystemTiles ? 2 : 0
    readonly property int tileCount: gameCount + systemCount
    readonly property int tilePad: density === "compact" ? DesktopTokens.px(18) : DesktopTokens.px(26)
    readonly property int tileGap: density === "compact" ? DesktopTokens.px(6) : DesktopTokens.px(10)
    readonly property int tilePitch: tileSize + tilePad + tileGap
    readonly property int dockHeight: tileSize + DesktopTokens.px(density === "compact" ? 46 : 56)
    readonly property int skeletonCount: density === "compact" ? 12 : 9
    readonly property bool motionOff: AppController.reducedMotion
    /// How many tiles fit in the viewport, used for page stepping.
    readonly property int pageStep: Math.max(1, Math.floor(tileFlick.width / Math.max(1, tilePitch)))
    readonly property int pinnedCount: {
        let count = 0
        for (let index = 0; index < gameCount; ++index) {
            if (ShellStore.isFavorite(games[index]))
                count += 1
        }
        return count
    }

    /// Index of the first system tile; selections at or above it are not games.
    readonly property int systemStart: gameCount
    readonly property var selectedGame: selectedIndex >= 0 && selectedIndex < gameCount
        ? games[selectedIndex] : null
    readonly property string caption: {
        if (loading)
            return qsTr("SYNCING YOUR LIBRARY")
        if (gameCount === 0)
            return qsTr("YOUR LIBRARY")
        if (selectedIndex >= systemStart)
            return qsTr("OPENNOW")
        if (selectedIndex < recentCount)
            return qsTr("RECENTLY PLAYED")
        if (selectedGame && ShellStore.isFavorite(selectedGame))
            return qsTr("PINNED")
        return qsTr("YOUR LIBRARY")
    }
    readonly property string captionDetail: {
        if (gameCount === 0)
            return ""
        if (selectedIndex >= systemStart)
            return qsTr("System")
        return qsTr("%1 of %2").arg(selectedIndex + 1).arg(gameCount)
    }

    implicitHeight: dockHeight
    height: dockHeight
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Game dock")

    // -------------------------------------------------------------------------
    // Scroll management
    // -------------------------------------------------------------------------
    function tileX(index) {
        return index * root.tilePitch
    }

    /// Largest contentX the flickable can legally take.
    readonly property real scrollSpan: Math.max(0, tileFlick.contentWidth - tileFlick.width)

    /// True when programmatic scrolls may animate. A drag, a reduced-motion
    /// setting or an explicit caller override all force a snap so the dock never
    /// fights the user for the scrollbar.
    readonly property bool scrollAnimates: animatedScroll && !motionOff && !tileFlick.moving

    /// Single place that writes contentX. Keeping the clamp here means every
    /// caller can pass a rough target and still land inside the valid range.
    function setScroll(value) {
        const target = Math.max(0, Math.min(scrollSpan, value))
        if (Math.abs(target - tileFlick.contentX) < 0.5)
            return
        if (root.scrollAnimates) {
            scrollAnimation.stop()
            scrollAnimation.from = tileFlick.contentX
            scrollAnimation.to = target
            scrollAnimation.start()
        } else {
            scrollAnimation.stop()
            tileFlick.contentX = target
        }
    }

    NumberAnimation {
        id: scrollAnimation
        target: tileFlick
        property: "contentX"
        duration: 260
        easing.type: Easing.OutCubic
    }

    function ensureTileVisible(index) {
        if (index < 0 || index >= root.tileCount || tileFlick.width <= 0)
            return
        const tileLeft = root.tileX(index)
        const tileRight = tileLeft + root.tileSize + root.tilePad
        const viewLeft = tileFlick.contentX
        const viewRight = viewLeft + tileFlick.width
        const margin = DesktopTokens.px(12)
        if (tileLeft < viewLeft + margin)
            root.setScroll(tileLeft - margin)
        else if (tileRight > viewRight - margin)
            root.setScroll(tileRight - tileFlick.width + margin)
    }

    function nudge(direction) {
        const step = Math.max(1, pageStep)
        const target = Math.max(0, Math.min(tileCount - 1, selectedIndex + direction * step))
        root.pointed(target)
        root.ensureTileVisible(target)
    }

    function scrollToStart() {
        root.setScroll(0)
    }

    function scrollToEnd() {
        root.setScroll(scrollSpan)
    }

    function pageForward() {
        nudge(pageStep)
    }

    function pageBack() {
        nudge(-pageStep)
    }

    /// Centre a tile without changing the selection. Used when the hero slide
    /// auto-cycles so the dock follows the featured game.
    function centerOn(index) {
        if (index < 0 || index >= tileCount || tileFlick.width <= 0)
            return
        root.setScroll(root.tileX(index) + (tileSize + tilePad) / 2 - tileFlick.width / 2)
    }

    function publishHover(index) {
        const next = index >= 0 && index < gameCount ? games[index] : null
        if (next === hoveredGame)
            return
        hoveredGame = next
        root.gameHovered(next)
    }

    onSelectedIndexChanged: {
        if (AppController.inputMode !== "pointer")
            root.ensureTileVisible(root.selectedIndex)
    }
    onGamesChanged: Qt.callLater(root.ensureTileVisible, root.selectedIndex)
    onWidthChanged: Qt.callLater(root.ensureTileVisible, root.selectedIndex)

    readonly property bool canScrollLeft: tileFlick.contentX > 4
    readonly property bool canScrollRight: tileFlick.contentX + tileFlick.width < tileFlick.contentWidth - 4

    // =========================================================================
    // 1. Caption strip
    // =========================================================================
    Item {
        id: captionStrip
        x: 0
        y: 0
        width: parent.width
        height: DesktopTokens.px(22)

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: DesktopTokens.px(8)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(6)
                height: DesktopTokens.px(6)
                radius: DesktopTokens.px(3)
                color: root.loading ? DesktopTokens.ledAmber : DesktopTokens.mint

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.loading && !root.motionOff
                    NumberAnimation { from: 1; to: 0.3; duration: 700 }
                    NumberAnimation { from: 0.3; to: 1; duration: 700 }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.caption
                color: Theme.lightMode ? "#0B1220" : "#E8FFFFFF"
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
                font.letterSpacing: 1.3
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.captionDetail !== ""
                width: 1
                height: DesktopTokens.px(10)
                color: Theme.lightMode ? "#330B1220" : "#33FFFFFF"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.captionDetail !== ""
                text: root.captionDetail
                color: Theme.lightMode ? "#8A0B1220" : "#99FFFFFF"
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: AppController.inputMode !== "pointer"
            text: qsTr("← → choose · Enter open · Space play")
            color: Theme.lightMode ? "#8A0B1220" : "#80FFFFFF"
            font.family: DesktopTokens.monoFont
            font.pixelSize: DesktopTokens.microSize
            font.letterSpacing: 0.6
        }
    }

    // =========================================================================
    // 2. Tile row
    // =========================================================================
    Flickable {
        id: tileFlick
        objectName: "desktopHomeDockFlick"
        x: 0
        y: captionStrip.height + DesktopTokens.px(2)
        width: parent.width
        height: root.dockHeight - captionStrip.height
        contentWidth: Math.max(width, tileRow.implicitWidth + DesktopTokens.px(16))
        contentHeight: height
        clip: true
        interactive: !root.loading
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5200
        maximumFlickVelocity: 2200
        Accessible.role: Accessible.Pane
        Accessible.name: qsTr("Dock tiles")

        Behavior on contentX {
            NumberAnimation {
                duration: root.motionOff ? 0 : 220
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: tileRow
            x: DesktopTokens.px(8)
            y: 0
            spacing: root.tileGap

            Repeater {
                model: root.games
                DesktopHomeDockTile {
                    required property var modelData
                    required property int index
                    game: modelData
                    kind: "game"
                    tileSize: root.tileSize
                    tileIndex: index
                    selected: root.active && root.selectedIndex === index
                    // The dock keeps its own badges (favourite, lock, running
                    // session) inside the tile, so no rank badge is imposed here.
                    badgeText: ""
                    onPointed: {
                        root.pointed(index)
                        root.gamePointed(index)
                        root.publishHover(index)
                    }
                    onActivated: root.gameActivated(modelData)
                    onPlayRequested: root.gamePlayRequested(modelData)
                    onFavoriteToggled: root.gameFavoriteToggled(modelData)
                }
            }

            // Divider before the console-level entries, so the row reads as
            // "your games" then "OpenNOW".
            Item {
                visible: root.showSystemTiles && root.gameCount > 0
                width: DesktopTokens.px(26)
                height: root.tileSize + root.tilePad

                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: parent.height * 0.55
                    color: Theme.lightMode ? "#22040610" : "#24FFFFFF"
                }
            }

            DesktopHomeDockTile {
                visible: root.showSystemTiles
                game: null
                kind: "system"
                systemLabel: qsTr("Library")
                systemIcon: "desktop-nav-library.svg"
                systemRoute: "library"
                tileSize: root.tileSize
                tileIndex: root.systemStart
                selected: root.active && root.selectedIndex === root.systemStart
                onPointed: root.pointed(root.systemStart)
                onActivated: root.systemActivated("library")
            }

            DesktopHomeDockTile {
                visible: root.showSystemTiles
                game: null
                kind: "system"
                systemLabel: qsTr("Store")
                systemIcon: "desktop-nav-store.svg"
                systemRoute: "store"
                tileSize: root.tileSize
                tileIndex: root.systemStart + 1
                selected: root.active && root.selectedIndex === root.systemStart + 1
                onPointed: root.pointed(root.systemStart + 1)
                onActivated: root.systemActivated("store")
            }
        }
    }

    // -------------------------------------------------------------------------
    // Hover preview. A pointer-only affordance: it repeats what the hero shows
    // for the tile under the cursor so you can scan the dock without clicking.
    // -------------------------------------------------------------------------
    Rectangle {
        id: hoverPreview
        objectName: "desktopHomeDockPreview"
        anchors.left: parent.left
        anchors.bottom: parent.top
        anchors.bottomMargin: DesktopTokens.px(4)
        width: previewRow.implicitWidth + DesktopTokens.px(22)
        height: DesktopTokens.px(40)
        radius: DesktopTokens.px(12)
        color: "#E60A0E18"
        border.width: 1
        border.color: "#2EFFFFFF"
        visible: root.hoveredGame !== null && AppController.inputMode === "pointer"
        opacity: visible ? 1 : 0
        z: 50
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 160 } }

        Row {
            id: previewRow
            anchors.centerIn: parent
            spacing: DesktopTokens.px(8)

            RoundedArtwork {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(26)
                height: DesktopTokens.px(26)
                artwork: DesktopTokens.artworkUrl(root.hoveredGame, false)
                cornerRadius: DesktopTokens.px(7)
                scrimStart: 1
                fallbackColor: "#1A2232"
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: root.hoveredGame ? String(root.hoveredGame.title || qsTr("Game")) : ""
                    color: Theme.mediaForeground
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    text: {
                        if (!root.hoveredGame)
                            return ""
                        const publisher = root.hoveredGame.publisherName || root.hoveredGame.publisher
                        const last = DesktopTokens.relativeLastPlayed(root.hoveredGame.lastPlayed, Date.now())
                        return [publisher ? String(publisher) : "", last].filter(part => part !== "").join("  ·  ")
                    }
                    color: Theme.mediaMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }

    // =========================================================================
    // 3. Edge treatment
    // =========================================================================
    Rectangle {
        x: 0
        y: tileFlick.y
        width: DesktopTokens.px(40)
        height: tileFlick.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.lightMode ? "#F4F7FB" : "#060911" }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: root.canScrollLeft ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Rectangle {
        anchors.right: parent.right
        y: tileFlick.y
        width: DesktopTokens.px(40)
        height: tileFlick.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.lightMode ? "#F4F7FB" : "#060911" }
        }
        opacity: root.canScrollRight ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    component DockChevron: Rectangle {
        id: chevron
        property bool chevronRight: true
        width: DesktopTokens.px(32)
        height: DesktopTokens.px(32)
        radius: DesktopTokens.px(16)
        color: chevronHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
        border.width: 1
        border.color: DesktopTokens.seam
        scale: chevronTap.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: chevron.chevronRight ? "›" : "‹"
            color: DesktopTokens.textHigh
            font.family: DesktopTokens.displayFont
            font.pixelSize: DesktopTokens.px(19)
            font.weight: Font.Black
        }

        HoverHandler { id: chevronHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: chevronTap
            onTapped: root.nudge(chevron.chevronRight ? 1 : -1)
        }
        Accessible.role: Accessible.Button
        Accessible.name: chevron.chevronRight ? qsTr("Scroll dock right") : qsTr("Scroll dock left")
        Accessible.onPressAction: root.nudge(chevron.chevronRight ? 1 : -1)
    }

    DockChevron {
        anchors.right: parent.right
        anchors.rightMargin: DesktopTokens.px(8)
        y: tileFlick.y + (tileFlick.height - height) / 2
        chevronRight: true
        visible: root.canScrollRight
        z: 40
    }

    DockChevron {
        anchors.left: parent.left
        anchors.leftMargin: DesktopTokens.px(8)
        y: tileFlick.y + (tileFlick.height - height) / 2
        chevronRight: false
        visible: root.canScrollLeft
        z: 40
    }

    // =========================================================================
    // 4. Skeleton state while the catalog syncs
    // =========================================================================
    Row {
        id: skeletonRow
        x: tileFlick.x + DesktopTokens.px(8)
        y: tileFlick.y + DesktopTokens.px(6)
        spacing: root.tileGap
        visible: root.loading && root.gameCount === 0
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Repeater {
            model: root.skeletonCount
            Rectangle {
                required property int index
                width: root.tileSize + root.tilePad - DesktopTokens.px(10)
                height: width
                radius: DesktopTokens.px(18)
                color: Theme.lightMode ? "#14040610" : "#1AFFFFFF"
                opacity: 0.55

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: skeletonRow.visible && !root.motionOff
                    NumberAnimation { from: 0.35; to: 0.7; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.7; to: 0.35; duration: 800; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // =========================================================================
    // 5. Hints / accessibility summary
    // =========================================================================
    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        visible: root.gameCount > 0
        text: root.pinnedCount > 0
            ? qsTr("%1 games in the dock · %2 pinned").arg(root.gameCount).arg(root.pinnedCount)
            : qsTr("%1 games in the dock").arg(root.gameCount)
        color: Theme.lightMode ? "#8A0B1220" : "#66FFFFFF"
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.microSize
        font.letterSpacing: 0.5
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        visible: root.gameCount > 0
        text: root.systemCaption
        color: Theme.lightMode ? "#8A0B1220" : "#66FFFFFF"
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.microSize
        font.weight: Font.Bold
        font.letterSpacing: 1.1
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
}
