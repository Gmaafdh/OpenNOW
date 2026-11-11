pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomeScreen — Home, rebuilt as a PS5-style library home.
// =============================================================================
//
// Concept
// -------
// The old home page was a stack of rails under a spotlight card. The new home
// behaves like a console: one full-bleed backdrop painted with the featured
// game's art, an editorial hero stage on top of it, a dock of game icons where
// the focused icon *is* the hero, and activity rails below for the ways you
// actually return to a library (continue, pinned, new, similar).
//
// Moving along the dock re-features the game everywhere at once — backdrop art,
// hero copy, up-next card — which is the single interaction that makes a PS5
// home feel alive.
//
// Focus model
// -----------
// Six zones, navigated with arrows:
//   0 hero actions      Play / Details / Library / Pin
//   1 dock              game icons, then Library and Store system tiles
//   2 Continue Playing  rail
//   3 Favourites        rail
//   4 New in Library    rail
//   5 More like this    rail (same genre as the featured game)
//
// Scroll contract (unchanged from the previous home and covered by tests):
// pointer hover updates the selection but never scrolls the page; only explicit
// keyboard/controller navigation reveals its target, and even then only the
// minimum distance — there is no jump back to the top.
// =============================================================================
FocusScope {
    id: root

    // -------------------------------------------------------------------------
    // Public API (the shell binds these)
    // -------------------------------------------------------------------------
    readonly property string pageTitle: qsTr("Home")
    readonly property string pageSubtitle: ShellStore.catalogTotalCount
        ? qsTr("%1 games").arg(ShellStore.catalogTotalCount)
        : qsTr("Your library")
    property bool active: true
    property int focusZone: 0
    property int focusIndex: 0
    property double lastPlayedNowMs: Date.now()

    signal routeRequested(string route)
    signal gameRequested(var game)
    signal playRequested(var game)
    signal searchRequested()

    anchors.fill: parent
    focus: active
    clip: true
    Accessible.role: Accessible.Pane
    Accessible.name: pageTitle
    Accessible.description: hasGames
        ? qsTr("%1 games. %2 featured.").arg(games.length).arg(showcaseGames.length)
        : qsTr("No games synced yet.")

    // =========================================================================
    // 1. Data model
    // =========================================================================
    readonly property var games: ShellStore.catalogGames || []
    readonly property bool motionOff: AppController.reducedMotion
    readonly property string catalogState: String(ShellStore.catalogState || "")
    readonly property bool syncing: catalogState === "loading" || catalogState === "refreshing"
    readonly property bool failed: catalogState === "error"
    readonly property bool signedIn: ShellStore.signedIn

    /// Hidden games stay hidden everywhere except the library's hidden filter.
    readonly property var visibleGames: {
        const list = []
        for (let index = 0; index < games.length; ++index) {
            if (!ShellStore.isHidden(games[index]))
                list.push(games[index])
        }
        return list
    }

    /// Most recently played first; games that were never played keep catalog
    /// order at the end because their timestamp is empty.
    readonly property var sortedRecent: {
        const list = visibleGames.slice()
        list.sort((left, right) => String(right.lastPlayed || "").localeCompare(String(left.lastPlayed || "")))
        return list
    }

    readonly property var heroGame: sortedRecent.length ? sortedRecent[0] : null
    readonly property var showcaseGames: takeGames(sortedRecent, 0, 6)
    readonly property var dockGames: takeGames(sortedRecent, 0, 12)
    readonly property var continueGames: takeGames(sortedRecent, 1, 12)
    readonly property var jumpGames: continueGames

    readonly property int favoriteCount: {
        let count = 0
        for (let index = 0; index < visibleGames.length; ++index) {
            if (ShellStore.isFavorite(visibleGames[index]))
                count += 1
        }
        return count
    }

    /// Pinned games first; when nothing is pinned yet the rail falls back to
    /// the start of the catalog so it never renders as a dead shelf.
    readonly property var favoriteGames: {
        const list = []
        for (let index = 0; index < visibleGames.length; ++index) {
            if (ShellStore.isFavorite(visibleGames[index]))
                list.push(visibleGames[index])
        }
        return list.length ? list : takeGames(visibleGames, 0, 12)
    }

    /// The catalog arrives in sync order, so the tail is what was added last.
    readonly property var newGames: takeGames(visibleGames, Math.max(0, visibleGames.length - 12), 12)

    /// "More like this" uses the featured game's primary genre. With no genre
    /// data the rail falls back to the most-played games so it still has a
    /// point of view instead of duplicating the continue rail.
    readonly property string heroGenre: {
        const game = showcase.currentGame || heroGame
        if (!game || !game.genres || !game.genres.length)
            return ""
        return String(game.genres[0])
    }
    readonly property var similarGames: {
        const hero = showcase.currentGame || heroGame
        const heroId = hero ? String(hero.id || "") : ""
        if (heroGenre !== "") {
            const list = []
            for (let index = 0; index < visibleGames.length; ++index) {
                const candidate = visibleGames[index]
                if (String(candidate.id || "") === heroId)
                    continue
                const genres = candidate.genres || []
                for (let genre = 0; genre < genres.length; ++genre) {
                    if (String(genres[genre]) === heroGenre) {
                        list.push(candidate)
                        break
                    }
                }
                if (list.length >= 12)
                    break
            }
            if (list.length)
                return list
        }
        const byHours = visibleGames.slice()
        byHours.sort((left, right) => Number(right.hoursPlayed || 0) - Number(left.hoursPlayed || 0))
        const fallback = []
        for (let index = 0; index < byHours.length && fallback.length < 12; ++index) {
            if (String(byHours[index].id || "") !== heroId)
                fallback.push(byHours[index])
        }
        return fallback
    }

    readonly property real totalHours: {
        let total = 0
        for (let index = 0; index < visibleGames.length; ++index) {
            const hours = Number(visibleGames[index].hoursPlayed || 0)
            if (isFinite(hours) && hours > 0)
                total += hours
        }
        return total
    }

    readonly property string memberTier: {
        if (ShellStore.subscription && ShellStore.subscription.membershipTier)
            return String(ShellStore.subscription.membershipTier).toUpperCase()
        if (signedIn && ShellStore.authSession && ShellStore.authSession.user
                && ShellStore.authSession.user.membershipTier)
            return String(ShellStore.authSession.user.membershipTier).toUpperCase()
        return signedIn ? qsTr("MEMBER") : ""
    }

    readonly property var resumableSession: ShellStore.resumableSession
    readonly property string sessionTitle: resumableSession
        ? String(ShellStore.sessionGameTitle(resumableSession) || "") : ""
    readonly property bool friendsAvailable: Boolean(ShellStore.socialCapabilities
        && ShellStore.socialCapabilities.friendsAvailable)

    readonly property bool hasGames: visibleGames.length > 0
    readonly property var backdropGame: showcase.currentGame || heroGame
    readonly property string lastSyncLabel: {
        const stamp = ShellStore.catalogLastCompleteAt
        if (!stamp)
            return ""
        const when = DesktopTokens.relativeLastPlayed(stamp, lastPlayedNowMs)
        return when !== "" ? qsTr("Synced %1").arg(when) : ""
    }
    /// Bare relative stamp for the header, which adds its own "synced" prefix.
    readonly property string lastSyncedAgo: {
        const stamp = ShellStore.catalogLastCompleteAt
        return stamp ? DesktopTokens.relativeLastPlayed(stamp, lastPlayedNowMs) : ""
    }

    // Rail geometry: an exact number of cards per row, no dangling gap.
    readonly property int railGap: DesktopTokens.px(14)
    readonly property int railInnerWidth: Math.max(240, contentFlick.width - DesktopTokens.px(48))
    readonly property int homeTileCount: {
        const fit = Math.max(1, Math.floor((railInnerWidth + railGap) / (DesktopTokens.px(132) + railGap)))
        return Math.max(1, Math.min(fit, 8))
    }
    readonly property int homeTileWidth: Math.max(112, Math.floor(
        (railInnerWidth - railGap * (homeTileCount - 1)) / homeTileCount))
    readonly property int homeTileHeight: Math.round(homeTileWidth * 1.62) + DesktopTokens.px(10)
    readonly property int dockTileCount: dockGames.length + 2

    // -- Backdrop + dock presentation state ----------------------------------
    /// An overlay (command palette, friends, icon guide) is on top of the page.
    /// The backdrop pulls its exposure down so the overlay reads as foreground.
    readonly property bool overlayOpen: AppController.overlay !== ""
    /// Short windows get the compact dock: same art ratio, tighter pitch, so
    /// the rails still get on-screen real estate.
    readonly property string dockDensity: height < DesktopTokens.px(720) ? "compact" : "comfortable"
    /// Game the pointer is inspecting in the dock, if any. Hover never moves
    /// focus, so this is kept apart from focusZone/focusIndex.
    property var hoveredDockGame: null
    /// The next hero slides, decoded ahead of time by the backdrop's warm cache.
    /// The hovered game jumps the queue so the swap after a click is instant.
    readonly property var warmGames: {
        const list = showcaseGames.slice()
        if (hoveredDockGame !== null && list.indexOf(hoveredDockGame) < 0)
            list.unshift(hoveredDockGame)
        return list
    }
    /// Where the hero art hands over to the rails. Pushed down a little in the
    /// compact density so the shorter dock does not cut the key art early.
    readonly property real heroSeam: dockDensity === "compact" ? 0.58 : 0.62
    /// Screen-reader copy describing the painted key art.
    readonly property string backdropDescription: {
        const game = backdropGame
        if (!game)
            return qsTr("Home background artwork.")
        return qsTr("Background artwork for %1.").arg(String(game.title || qsTr("the featured game")))
    }
    /// Stable seed for the generated fallback stage when a game has no art.
    readonly property string backdropSeed: String(backdropGame && (backdropGame.id || backdropGame.title) || "")
    /// The hero stage is "you are here" while focus sits in the actions or dock.
    readonly property bool heroFocused: focusZone === 0 || focusZone === 1
    /// Lifts the stage while a rail is focused so the artwork sits behind the
    /// cards instead of behind the hero title block.
    readonly property real stageOffset: focusZone >= 2 && !motionOff ? -DesktopTokens.px(10) : 0
    readonly property int zoneTotal: 6

    function takeGames(source, start, limit) {
        const list = source || []
        const result = []
        for (let index = start; index < list.length && result.length < limit; ++index)
            result.push(list[index])
        return result
    }

    /// Formats the hero's "last played · hours" line. Kept as a standalone
    /// function so the orchestration tests can exercise it in isolation.
    function heroMeta() {
        const game = root.heroGame
        if (!game)
            return qsTr("Sign in and sync your library to continue a game.")
        const last = DesktopTokens.relativeLastPlayed(game.lastPlayed, root.lastPlayedNowMs)
        const hours = game.hoursPlayed ? qsTr("%1 h played").arg(game.hoursPlayed) : ""
        if (last !== "" && hours !== "")
            return last + " · " + hours
        if (last !== "")
            return last
        if (hours !== "")
            return hours
        return qsTr("Ready to stream from your library")
    }

    /// Stream quality chip: resolution, frame rate and codec from settings.
    function streamChip() {
        const settings = ShellStore.settings || {}
        const res = String(settings.resolution || "")
        const fps = Number(settings.fps || 0)
        const codec = String(settings.codec || "auto").toUpperCase()
        const parts = []
        if (res.indexOf("x") > 0)
            parts.push(res.split("x")[1] + "p")
        if (fps > 0)
            parts.push(fps + " fps")
        if (codec !== "" && codec !== "AUTO")
            parts.push(codec)
        return parts.length ? parts.join(" · ") : qsTr("Stream ready")
    }

    function similarTitle() {
        return heroGenre !== ""
            ? qsTr("More like %1").arg(DesktopTokens.genreLabel(heroGenre))
            : qsTr("Most played")
    }

    // Clock for "last played" strings; only ticks while home is on screen.
    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.visible && Qt.application.state === Qt.ApplicationActive
        triggeredOnStart: true
        onTriggered: root.lastPlayedNowMs = Date.now()
    }

    // =========================================================================
    // 2. Focus zones
    // =========================================================================
    function zoneGames(zone) {
        if (zone === 1)
            return dockGames
        if (zone === 2)
            return continueGames
        if (zone === 3)
            return favoriteGames
        if (zone === 4)
            return newGames
        if (zone === 5)
            return similarGames
        return []
    }

    function zoneSize(zone) {
        if (zone === 0)
            return 4
        if (zone === 1)
            return dockTileCount
        return zoneGames(zone).length
    }

    function zoneItem(zone) {
        if (zone === 0)
            return showcase
        if (zone === 1)
            return dock
        if (zone === 2)
            return continueRail
        if (zone === 3)
            return favoriteRail
        if (zone === 4)
            return newRail
        return similarRail
    }

    function zoneName(zone) {
        if (zone === 0)
            return qsTr("Featured game actions")
        if (zone === 1)
            return qsTr("Game dock")
        if (zone === 2)
            return qsTr("Continue Playing")
        if (zone === 3)
            return qsTr("Favourites")
        if (zone === 4)
            return qsTr("New in Your Library")
        return similarTitle()
    }

    function currentGame() {
        if (focusZone === 0 || focusZone === 1)
            return showcase.currentGame || heroGame
        const list = zoneGames(focusZone)
        return focusIndex >= 0 && focusIndex < list.length ? list[focusIndex] : null
    }

    function setSelection(zone, index, revealSelection) {
        root.focusZone = Math.max(0, Math.min(root.zoneTotal - 1, zone))
        const count = root.zoneSize(root.focusZone)
        root.focusIndex = Math.max(0, Math.min(Math.max(0, count - 1), index))
        // Focusing a dock icon features that game in the hero and backdrop, the
        // way moving along the PS5 icon bar repaints the whole screen.
        if (root.focusZone === 1 && root.focusIndex < root.dockGames.length)
            showcase.showSlide(root.focusIndex)
        // Pointer hover can be retriggered when a hero crossfades beneath the
        // cursor. Only explicit keyboard/controller navigation may scroll.
        if (revealSelection === true)
            root.ensureSelectionVisible()
    }

    function ensureSelectionVisible() {
        const item = root.zoneItem(root.focusZone)
        if (!item)
            return
        const zoneTop = pageColumn.y + item.y
        const zoneBottom = zoneTop + item.height
        const viewTop = contentFlick.contentY
        const viewBottom = viewTop + contentFlick.height
        const margin = DesktopTokens.px(12)
        if (zoneTop < viewTop + margin)
            contentFlick.contentY = Math.max(0, zoneTop - margin)
        else if (zoneBottom > viewBottom - margin)
            contentFlick.contentY = Math.min(
                Math.max(0, contentFlick.contentHeight - contentFlick.height),
                zoneBottom - contentFlick.height + margin)
    }

    function moveHorizontal(delta) {
        const count = root.zoneSize(root.focusZone)
        if (count <= 0)
            return
        root.setSelection(root.focusZone, Math.max(0, Math.min(count - 1, root.focusIndex + delta)), true)
    }

    function moveVertical(delta) {
        // Skip rails that have nothing to show so Down never dead-ends.
        let nextZone = root.focusZone
        for (let step = 0; step < root.zoneTotal; ++step) {
            nextZone += delta
            if (nextZone < 0 || nextZone > root.zoneTotal - 1)
                return
            if (root.zoneSize(nextZone) > 0)
                break
        }
        if (nextZone === root.focusZone)
            return
        let nextIndex = root.focusIndex
        if (nextZone === 0)
            nextIndex = Math.min(3, Math.round(root.focusIndex / 3))
        else if (root.focusZone === 0 && nextZone === 1)
            nextIndex = Math.min(Math.max(0, root.dockTileCount - 1), root.focusIndex * 3)
        else if (root.focusZone === 1 && nextZone === 2)
            nextIndex = Math.min(Math.max(0, root.continueGames.length - 1), root.focusIndex)
        root.setSelection(nextZone, nextIndex, true)
    }

    function openGame(game) {
        if (!game)
            return
        root.gameRequested(game)
    }

    function launchGame(game) {
        const target = game || showcase.currentGame || heroGame
        if (!target)
            return
        ShellStore.selectedGame = target
        if (!ShellStore.signedIn) {
            AppController.navigate("sign-in")
            return
        }
        root.playRequested(target)
    }

    function toggleFavorite(game) {
        const target = game || root.currentGame()
        if (!target)
            return
        ShellStore.toggleFavorite(target)
    }

    function scrollToTop() {
        contentFlick.contentY = 0
    }

    function activateSelection() {
        if (root.focusZone === 0) {
            const action = root.focusIndex
            if (action === 0)
                root.launchGame(showcase.currentGame)
            else if (action === 1)
                root.openGame(showcase.currentGame)
            else if (action === 2)
                root.routeRequested("library")
            else
                root.toggleFavorite(showcase.currentGame)
            return
        }
        if (root.focusZone === 1) {
            if (root.focusIndex < root.dockGames.length)
                root.openGame(root.dockGames[root.focusIndex])
            else if (root.focusIndex === root.dockGames.length)
                root.routeRequested("library")
            else
                root.routeRequested("store")
            return
        }
        const selectedGames = root.zoneGames(root.focusZone)
        if (selectedGames.length > root.focusIndex)
            root.openGame(selectedGames[root.focusIndex])
    }

    // =========================================================================
    // 3. Input
    // =========================================================================
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) {
            root.moveHorizontal(-1)
        } else if (event.key === Qt.Key_Right) {
            root.moveHorizontal(1)
        } else if (event.key === Qt.Key_Up) {
            root.moveVertical(-1)
        } else if (event.key === Qt.Key_Down) {
            root.moveVertical(1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateSelection()
        } else if (event.key === Qt.Key_Space) {
            // Space always launches the selection instead of opening details.
            root.launchGame(root.currentGame())
        } else if (event.key === Qt.Key_F) {
            root.toggleFavorite(root.currentGame())
        } else if (event.key === Qt.Key_L) {
            root.routeRequested("library")
        } else if (event.key === Qt.Key_S) {
            root.routeRequested("store")
        } else if (event.key === Qt.Key_Home) {
            root.scrollToTop()
            root.setSelection(0, 0, false)
        } else {
            return
        }
        event.accepted = true
    }

    // =========================================================================
    // 4. Backdrop
    // =========================================================================
    DesktopHomeBackdrop {
        id: backdrop
        anchors.fill: parent
        game: root.backdropGame
        active: root.active && root.hasGames
        dim: root.hasGames ? 0 : 0.62
        accentStrength: root.hasGames ? 1 : 0.4
        artAlignment: root.backdropGame && root.backdropGame.heroImageUrl ? "right" : "center"
        artDescription: root.backdropDescription
        fallbackSeed: root.backdropSeed
        heroFocused: root.heroFocused && AppController.inputMode !== "pointer"
        stageOffset: root.stageOffset
        seamPosition: root.heroSeam
        warmGames: root.warmGames
        idleDrift: !root.overlayOpen
        grainEnabled: !root.overlayOpen
        // An overlay owns the pointer, so the stage stops following the cursor
        // and the idle dim takes over instead of competing with the modal.
        parallaxStrength: root.overlayOpen ? 0 : 1
        idleDimming: !root.overlayOpen
        // Pull the art down while an overlay owns the foreground, and deepen
        // the vignette in light themes where bright key art washes out text.
        exposure: root.overlayOpen ? 0.42 : root.heroFocused ? 1 : 0.86
        vignette: Theme.lightMode ? 1.25 : 1
        titleScrim: root.overlayOpen ? 0.7 : 1
        railScrim: root.overlayOpen ? 0.55 : 0.9
        headerScrim: root.overlayOpen ? 0.6 : 1
    }

    // =========================================================================
    // 5. Page
    // =========================================================================
    Flickable {
        id: contentFlick
        objectName: "desktopHomeScroll"
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, pageColumn.implicitHeight + DesktopTokens.px(28))
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5200
        maximumFlickVelocity: 2200
        Accessible.role: Accessible.Pane

        Column {
            id: pageColumn
            x: DesktopTokens.px(24)
            y: DesktopTokens.px(16)
            width: contentFlick.width - DesktopTokens.px(48)
            spacing: DesktopTokens.px(16)

            // -- Header -------------------------------------------------------
            DesktopHomeHeader {
                id: header
                width: parent.width
                totalGames: root.visibleGames.length
                favoriteCount: root.favoriteCount
                totalHours: root.totalHours
                streamLabel: root.streamChip()
                memberTier: root.memberTier
                signedIn: root.signedIn
                syncing: root.syncing
                friendsAvailable: root.friendsAvailable
                active: root.active
                activeTab: "games"
                density: root.dockDensity
                lastSyncedLabel: root.lastSyncedAgo
                nowPlayingTitle: root.sessionTitle
                onLibraryRequested: root.routeRequested("library")
                onStoreRequested: root.routeRequested("store")
                onGamesRequested: root.scrollToTop()
                onSearchRequested: root.searchRequested()
                onSyncRequested: ShellStore.refreshCatalog("")
                onFriendsRequested: AppController.showOverlay("friends")
            }

            // -- Hero stage ---------------------------------------------------
            DesktopHomeShowcase {
                id: showcase
                objectName: "desktopHomeShowcase"
                width: parent.width
                height: Math.max(DesktopTokens.px(330),
                                 Math.min(DesktopTokens.px(430), Math.round(contentFlick.height * 0.5)))
                visible: root.hasGames
                games: root.showcaseGames
                recentGames: root.sortedRecent
                totalGames: root.visibleGames.length
                favoriteCount: root.favoriteCount
                totalHours: root.totalHours
                active: root.active
                signedIn: root.signedIn
                streamLabel: root.streamChip()
                metaLine: root.heroMeta()
                lastPlayedNowMs: root.lastPlayedNowMs
                selectedAction: root.focusZone === 0 && AppController.inputMode !== "pointer" ? root.focusIndex : -1
                onPlayRequested: game => root.launchGame(game)
                onDetailsRequested: game => root.openGame(game)
                onLibraryRequested: root.routeRequested("library")
                onSignInRequested: AppController.navigate("sign-in")
                onFavoriteToggled: game => root.toggleFavorite(game)
                onActionPointed: index => root.setSelection(0, index)
                onSlidePointed: index => {
                    if (root.focusZone === 1 && index < root.dockGames.length)
                        root.setSelection(1, index)
                }
            }

            // -- Dock ---------------------------------------------------------
            DesktopHomeDock {
                id: dock
                objectName: "desktopHomeDock"
                width: parent.width
                visible: root.hasGames
                games: root.dockGames
                selectedIndex: root.focusZone === 1 ? root.focusIndex : showcase.currentIndex
                active: root.active
                loading: root.syncing
                recentCount: Math.min(5, root.dockGames.length)
                tileSize: DesktopTokens.px(76)
                density: root.dockDensity
                animatedScroll: !root.motionOff
                systemCaption: qsTr("OPENNOW")
                onGameHovered: game => root.hoveredDockGame = game
                onPointed: index => root.setSelection(1, index)
                onGamePointed: index => root.setSelection(1, index)
                onGameActivated: game => root.openGame(game)
                onGamePlayRequested: game => root.launchGame(game)
                onGameFavoriteToggled: game => root.toggleFavorite(game)
                onSystemActivated: route => root.routeRequested(route)
            }

            // -- Resume strip (only while a cloud session is live) ------------
            Rectangle {
                id: resumeStrip
                objectName: "desktopHomeResume"
                width: parent.width
                height: DesktopTokens.px(58)
                radius: DesktopTokens.px(16)
                visible: root.resumableSession !== null && root.sessionTitle !== ""
                color: Theme.lightMode ? "#E6F2F5FA" : "#D90B1320"
                border.width: 1
                border.color: "#3356E6A5"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: DesktopTokens.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: DesktopTokens.px(10)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(8)
                        height: DesktopTokens.px(8)
                        radius: DesktopTokens.px(4)
                        color: DesktopTokens.mint

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: !root.motionOff
                            NumberAnimation { from: 1; to: 0.35; duration: 900 }
                            NumberAnimation { from: 0.35; to: 1; duration: 900 }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            text: qsTr("SESSION RUNNING")
                            color: DesktopTokens.mint
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: DesktopTokens.microSize
                            font.weight: Font.Bold
                            font.letterSpacing: 1.1
                        }
                        Text {
                            text: root.sessionTitle
                            color: DesktopTokens.textHigh
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: DesktopTokens.captionSize
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                DesktopButton {
                    anchors.right: parent.right
                    anchors.rightMargin: DesktopTokens.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    primary: true
                    cornerRadius: 12
                    height: DesktopTokens.px(36)
                    glyph: "desktop-play-filled.svg"
                    text: qsTr("Resume")
                    onClicked: ShellStore.resumeActiveSession()
                }

                Accessible.role: Accessible.Pane
                Accessible.name: qsTr("Running session: %1").arg(root.sessionTitle)
            }

            // -- Rails --------------------------------------------------------
            DesktopHomeRail {
                id: continueRail
                objectName: "desktopHomeContinueRail"
                width: parent.width
                visible: root.hasGames
                railTitle: qsTr("Continue Playing")
                railSubtitle: qsTr("Pick up where you left off")
                railIcon: "desktop-clock.svg"
                games: root.continueGames
                currentIndex: root.focusZone === 2 ? root.focusIndex : -1
                spotlightTitle: root.backdropGame ? String(root.backdropGame.title || "") : ""
                active: root.active
                loading: root.syncing
                tileWidth: root.homeTileWidth
                tileHeight: root.homeTileHeight
                showIconGuide: true
                emptyText: qsTr("Games you play will show up here with your last session on top.")
                emptyActionLabel: qsTr("Browse the store")
                onPointed: index => root.setSelection(2, index)
                onActivated: game => root.openGame(game)
                onPlayRequested: game => root.launchGame(game)
                onFavoriteToggled: game => root.toggleFavorite(game)
                onSeeAllRequested: root.routeRequested("library")
                onIconGuideRequested: AppController.showOverlay("desktop-icon-guide")
                onEmptyActionRequested: root.routeRequested("store")
            }

            DesktopHomeRail {
                id: favoriteRail
                objectName: "desktopHomeFavoriteRail"
                width: parent.width
                visible: root.hasGames
                railTitle: qsTr("Favourites")
                railSubtitle: root.favoriteCount > 0
                    ? qsTr("%1 pinned for quick play").arg(root.favoriteCount)
                    : qsTr("Pin games to keep them one tap away")
                railIcon: "desktop-star.svg"
                games: root.favoriteGames
                currentIndex: root.focusZone === 3 ? root.focusIndex : -1
                spotlightTitle: root.backdropGame ? String(root.backdropGame.title || "") : ""
                active: root.active
                loading: root.syncing
                tileWidth: root.homeTileWidth
                tileHeight: root.homeTileHeight
                emptyText: qsTr("Star a game on any card and it lands here.")
                emptyActionLabel: qsTr("Open library")
                onPointed: index => root.setSelection(3, index)
                onActivated: game => root.openGame(game)
                onPlayRequested: game => root.launchGame(game)
                onFavoriteToggled: game => root.toggleFavorite(game)
                onSeeAllRequested: root.routeRequested("library")
                onEmptyActionRequested: root.routeRequested("library")
            }

            DesktopHomeRail {
                id: newRail
                objectName: "desktopHomeNewRail"
                width: parent.width
                visible: root.hasGames
                railTitle: qsTr("New in Your Library")
                railSubtitle: qsTr("The most recent additions to your collection")
                railIcon: "desktop-plus.svg"
                games: root.newGames
                currentIndex: root.focusZone === 4 ? root.focusIndex : -1
                spotlightTitle: root.backdropGame ? String(root.backdropGame.title || "") : ""
                active: root.active
                loading: root.syncing
                badgeMode: "new"
                newBadgeCount: 3
                tileWidth: root.homeTileWidth
                tileHeight: root.homeTileHeight
                emptyText: qsTr("Newly synced games appear here.")
                onPointed: index => root.setSelection(4, index)
                onActivated: game => root.openGame(game)
                onPlayRequested: game => root.launchGame(game)
                onFavoriteToggled: game => root.toggleFavorite(game)
                onSeeAllRequested: root.routeRequested("library")
            }

            DesktopHomeRail {
                id: similarRail
                objectName: "desktopHomeSimilarRail"
                width: parent.width
                visible: root.hasGames
                railTitle: root.similarTitle()
                railSubtitle: root.heroGenre !== ""
                    ? qsTr("Same genre as the featured game")
                    : qsTr("The games with the most hours on this account")
                railIcon: "desktop-gamepad.svg"
                games: root.similarGames
                currentIndex: root.focusZone === 5 ? root.focusIndex : -1
                spotlightTitle: root.backdropGame ? String(root.backdropGame.title || "") : ""
                active: root.active
                loading: root.syncing
                badgeMode: "rank"
                tileWidth: root.homeTileWidth
                tileHeight: root.homeTileHeight
                emptyText: qsTr("Play a few games and recommendations build from their genres.")
                onPointed: index => root.setSelection(5, index)
                onActivated: game => root.openGame(game)
                onPlayRequested: game => root.launchGame(game)
                onFavoriteToggled: game => root.toggleFavorite(game)
                onSeeAllRequested: root.routeRequested("library")
            }

            // -- Empty / syncing / error --------------------------------------
            DesktopHomeEmptyState {
                id: emptyState
                width: parent.width
                visible: !root.hasGames
                signedIn: root.signedIn
                syncing: root.syncing
                failed: root.failed
                errorMessage: root.failed ? String(ShellStore.catalogError || "") : ""
                active: root.active
                onLibraryRequested: root.routeRequested("library")
                onStoreRequested: root.routeRequested("store")
                onSignInRequested: AppController.navigate("sign-in")
                onRetryRequested: ShellStore.refreshCatalog("")
            }

            // -- Footer -------------------------------------------------------
            Item {
                width: parent.width
                height: DesktopTokens.px(34)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasGames
                    text: AppController.inputMode === "pointer"
                        ? [root.lastSyncLabel, qsTr("%1 games").arg(root.visibleGames.length)]
                            .filter(part => part !== "").join("  ·  ")
                        : qsTr("↑ ↓ ← → navigate · Enter open · Space play · F pin · L library · S store")
                    color: DesktopTokens.textFaint
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.tinySize
                    font.letterSpacing: 0.5
                    elide: Text.ElideRight
                    width: parent.width - DesktopTokens.px(160)
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasGames
                    text: root.streamChip()
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.tinySize
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                }
            }
        }
    }

    // =========================================================================
    // 6. Scroll affordances
    // =========================================================================
    // Thin progress track on the right edge so deep rails stay orientable.
    Rectangle {
        id: scrollTrack
        anchors.right: parent.right
        anchors.rightMargin: DesktopTokens.px(6)
        anchors.verticalCenter: parent.verticalCenter
        width: DesktopTokens.px(3)
        height: Math.min(DesktopTokens.px(180), parent.height * 0.28)
        radius: DesktopTokens.px(1.5)
        color: Theme.lightMode ? "#14040610" : "#1FFFFFFF"
        visible: contentFlick.contentHeight > contentFlick.height + 8

        Rectangle {
            id: scrollThumb
            width: parent.width
            radius: parent.radius
            color: DesktopTokens.mint
            height: Math.max(DesktopTokens.px(24),
                             parent.height * (contentFlick.height / Math.max(1, contentFlick.contentHeight)))
            y: (parent.height - height) * (contentFlick.contentY
                / Math.max(1, contentFlick.contentHeight - contentFlick.height))
        }
    }

    // Scroll-to-top button once the hero has scrolled away.
    Rectangle {
        id: toTopButton
        objectName: "desktopHomeScrollTop"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: DesktopTokens.px(18)
        anchors.bottomMargin: DesktopTokens.px(18)
        width: DesktopTokens.px(38)
        height: DesktopTokens.px(38)
        radius: DesktopTokens.px(19)
        color: toTopHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
        border.width: 1
        border.color: DesktopTokens.seam
        visible: contentFlick.contentY > DesktopTokens.px(120)
        opacity: visible ? 1 : 0
        scale: toTopTap.pressed ? 0.94 : 1
        z: 40
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: "↑"
            color: DesktopTokens.textHigh
            font.family: DesktopTokens.displayFont
            font.pixelSize: DesktopTokens.px(18)
            font.weight: Font.Black
        }

        HoverHandler { id: toTopHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: toTopTap
            onTapped: {
                root.scrollToTop()
                root.setSelection(0, 0, false)
            }
        }
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Back to top")
        Accessible.onPressAction: root.scrollToTop()
    }

    // =========================================================================
    // 7. Lifecycle
    // =========================================================================
    Component.onCompleted: {
        root.focusZone = 0
        root.focusIndex = Math.max(0, Math.min(3, ShellStore.focusIndex("desktop-home")))
        if (root.active)
            Qt.callLater(root.forceActiveFocus)
    }

    onActiveChanged: {
        if (active) {
            root.focusIndex = Math.max(0, Math.min(3, ShellStore.focusIndex("desktop-home")))
            Qt.callLater(root.forceActiveFocus)
        }
    }

    onFocusIndexChanged: ShellStore.rememberFocus("desktop-home", focusIndex)

    // Keep the selection valid when the catalog changes underneath it.
    onHasGamesChanged: {
        if (!hasGames)
            root.setSelection(0, 0, false)
    }

    onDockTileCountChanged: {
        if (root.focusZone === 1)
            root.setSelection(1, Math.min(root.focusIndex, Math.max(0, root.dockTileCount - 1)), false)
    }
}
