"""Contracts for the PS5-style desktop Home redesign.

Home is built from nine components that each own one job:

    DesktopHomeScreen      focus zones, data model, page composition
    DesktopHomeBackdrop    full-bleed art that follows the featured game
    DesktopHomeHeader      greeting, tabs, library stats, quick actions
    DesktopHomeShowcase    hero stage: title, meta chips, actions, slides
    DesktopHomeDock        the icon bar whose focus drives the hero
    DesktopHomeDockTile    one dock icon
    DesktopHomeRail        one activity shelf of cards
    DesktopHomePoster      one activity card
    DesktopHomeEmptyState  signed-out / syncing / error / no-games

These tests pin the behaviour that makes the design work as a whole: the dock
re-features the hero, pointer hover never scrolls the page, artwork is decoded
once per layer, and the shell-facing API is unchanged.
"""

from pathlib import Path
import json
import re
import unittest


QT_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = QT_ROOT.parent

HOME_COMPONENTS = [
    "DesktopHomeBackdrop",
    "DesktopHomeDock",
    "DesktopHomeDockTile",
    "DesktopHomeEmptyState",
    "DesktopHomeHeader",
    "DesktopHomePoster",
    "DesktopHomeRail",
    "DesktopHomeScreen",
    "DesktopHomeShowcase",
]


def qml(path: str) -> str:
    return (QT_ROOT / "qml" / path).read_text(encoding="utf-8")


def home(name: str) -> str:
    return qml("desktop/home/%s.qml" % name)


def function_body(source: str, name: str) -> str:
    pattern = r"    function " + re.escape(name) + r"\([^\n]*\) \{.*?\n    \}"
    match = re.search(pattern, source, re.DOTALL)
    if match is None:
        raise AssertionError("function %s was not found" % name)
    return match.group(0)


def multi_arg_calls(source: str):
    """Yield (line, snippet) for every .arg(...) with a top-level comma.

    QML's String.arg takes a single value; passing two throws
    "String.arg(): Invalid arguments" at runtime, which the Windows smoke test
    treats as a page failure. A regex cannot tell a two-argument call from a
    one-argument call whose value contains a comma, so this walks the parens.
    """
    index = 0
    while True:
        found = source.find(".arg(", index)
        if found < 0:
            return
        cursor = found + len(".arg(")
        depth = 1
        quote = None
        while cursor < len(source) and depth:
            char = source[cursor]
            if quote:
                if char == "\\":
                    cursor += 2
                    continue
                if char == quote:
                    quote = None
            elif char in "\"'":
                quote = char
            elif char in "([{":
                depth += 1
            elif char in ")]}":
                depth -= 1
                if depth == 0:
                    break
            elif char == "," and depth == 1:
                yield (source[:found].count("\n") + 1, source[found:cursor + 1])
                break
            cursor += 1
        index = found + len(".arg(")


def qobject_components() -> set:
    """Component names whose root object is a QtObject.

    Those cannot be Repeater or ListView delegates: the view requires an Item and
    warns "Delegate must be of Item type" at runtime, which the Windows smoke
    test treats as a failure.
    """
    names = set()
    for path in (QT_ROOT / "qml").rglob("*.qml"):
        text = path.read_text(encoding="utf-8")
        body = text.split("\n", 1)[1] if text.startswith("pragma") else text
        stripped = [line for line in body.splitlines()
                    if line.strip() and not line.strip().startswith(("//", "/*", "*", "import"))]
        if stripped and stripped[0].strip().startswith("QtObject {"):
            names.add(path.stem)
    return names


def repeater_delegates(source: str):
    """Yield (line, type) for every component instantiated inside a Repeater."""
    qtobjects = qobject_components()
    for match in re.finditer(r"\bRepeater\s*{", source):
        cursor = match.end()
        depth = 1
        while cursor < len(source) and depth:
            char = source[cursor]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
            cursor += 1
        block = source[match.end():cursor]
        offset = source[:match.end()].count("\n") + 1
        for nested in re.finditer(r"(?m)^\s*([A-Z]\w*)\s*{", block):
            name = nested.group(1)
            if name in ("Repeater", "Component"):
                continue
            if name in qtobjects:
                yield (offset + block[:nested.start()].count("\n"), name)


class HomeRegistrationContracts(unittest.TestCase):
    def test_every_home_component_is_registered_with_the_qml_module(self) -> None:
        module = (QT_ROOT / "cmake" / "QmlModule.cmake").read_text(encoding="utf-8")
        for component in HOME_COMPONENTS:
            self.assertIn("qml/desktop/home/%s.qml" % component, module, component)

    def test_home_components_exist_and_are_substantial(self) -> None:
        for component in HOME_COMPONENTS:
            path = QT_ROOT / "qml" / "desktop" / "home" / ("%s.qml" % component)
            self.assertTrue(path.is_file(), component)
            lines = path.read_text(encoding="utf-8").splitlines()
            self.assertGreater(len(lines), 250, "%s is only %d lines" % (component, len(lines)))

    def test_home_components_declare_bound_component_behavior(self) -> None:
        # Delegates capture their own model data; the pragma makes that explicit
        # and stops context-property leaks between rails.
        for component in HOME_COMPONENTS:
            self.assertIn("pragma ComponentBehavior: Bound", home(component), component)


class HomeShellApiContracts(unittest.TestCase):
    def test_screen_keeps_the_shell_facing_api(self) -> None:
        screen = home("DesktopHomeScreen")
        self.assertIn("property bool active: true", screen)
        self.assertIn("signal routeRequested(string route)", screen)
        self.assertIn("signal gameRequested(var game)", screen)
        self.assertIn("signal playRequested(var game)", screen)
        self.assertIn("readonly property var games: ShellStore.catalogGames || []", screen)

    def test_app_wires_every_home_signal(self) -> None:
        app = qml("desktop/shell/DesktopApp.qml")
        component = re.search(
            r"Component \{\n        id: homeComponent\n(.*?)\n    \}", app, re.DOTALL)
        self.assertIsNotNone(component)
        body = component.group(1)
        self.assertIn("DesktopHomeScreen", body)
        self.assertIn("onRouteRequested:", body)
        self.assertIn("onGameRequested:", body)
        self.assertIn("onPlayRequested:", body)
        self.assertIn("onSearchRequested: root.commandOpen = true", body)

    def test_launching_from_home_goes_through_the_shell_store(self) -> None:
        screen = home("DesktopHomeScreen")
        launch = function_body(screen, "launchGame")
        self.assertIn("ShellStore.selectedGame = target", launch)
        self.assertIn('AppController.navigate("sign-in")', launch)
        self.assertIn("root.playRequested(target)", launch)

    def test_hero_metadata_formatter_is_unchanged(self) -> None:
        # tst_embeddedorchestration.cpp extracts this function by name and runs
        # it against fixtures, so its shape is part of the contract.
        screen = home("DesktopHomeScreen")
        self.assertIn("    function heroMeta() {", screen)
        body = function_body(screen, "heroMeta")
        self.assertIn("DesktopTokens.relativeLastPlayed(game.lastPlayed, root.lastPlayedNowMs)", body)
        self.assertIn('qsTr("Sign in and sync your library to continue a game.")', body)
        self.assertIn('qsTr("Ready to stream from your library")', body)


class HomeFocusContracts(unittest.TestCase):
    def test_home_has_six_navigation_zones(self) -> None:
        screen = home("DesktopHomeScreen")
        self.assertIn("readonly property int zoneTotal: 6", screen)
        self.assertIn("function zoneSize(zone) {", screen)
        self.assertIn("function zoneItem(zone) {", screen)
        for zone_item in ("showcase", "dock", "continueRail", "favoriteRail", "newRail", "similarRail"):
            self.assertIn("return %s" % zone_item, function_body(screen, "zoneItem"))

    def test_focus_memory_is_scoped_to_home(self) -> None:
        screen = home("DesktopHomeScreen")
        self.assertIn('ShellStore.focusIndex("desktop-home")', screen)
        self.assertIn('ShellStore.rememberFocus("desktop-home", focusIndex)', screen)

    def test_keyboard_covers_navigation_launch_and_pinning(self) -> None:
        screen = home("DesktopHomeScreen")
        for key in ("Qt.Key_Left", "Qt.Key_Right", "Qt.Key_Up", "Qt.Key_Down",
                    "Qt.Key_Return", "Qt.Key_Space", "Qt.Key_F", "Qt.Key_L",
                    "Qt.Key_S", "Qt.Key_Home"):
            self.assertIn(key, screen, key)
        self.assertIn("event.accepted = true", screen)

    def test_pointer_hover_never_scrolls_the_page(self) -> None:
        screen = home("DesktopHomeScreen")
        pointed = re.findall(r"(?m)^\s*onPointed:\s*(?:index\s*=>\s*)?root\.setSelection\(([^\n]+)\)", screen)
        self.assertEqual(len(pointed), 5, pointed)
        self.assertTrue(all("true" not in call for call in pointed))
        self.assertNotIn("contentY = 0", function_body(screen, "setSelection"))
        self.assertNotIn("contentY = 0", function_body(screen, "ensureSelectionVisible"))
        # Each rail and the dock scroll themselves, and only for keyboard focus.
        for component in ("DesktopHomeDock", "DesktopHomeRail"):
            source = home(component)
            self.assertIn('AppController.inputMode !== "pointer"', source, component)
            self.assertIn("function ensure", source, component)


class HomeHeroContracts(unittest.TestCase):
    def test_focusing_the_dock_refeatures_the_hero(self) -> None:
        screen = home("DesktopHomeScreen")
        selection = function_body(screen, "setSelection")
        self.assertIn("showcase.showSlide(root.focusIndex)", selection)
        self.assertIn("root.focusZone === 1", selection)

    def test_backdrop_hero_and_dock_share_one_featured_game(self) -> None:
        screen = home("DesktopHomeScreen")
        self.assertIn("readonly property var backdropGame: showcase.currentGame || heroGame", screen)
        self.assertIn("game: root.backdropGame", screen)
        self.assertIn("selectedIndex: root.focusZone === 1 ? root.focusIndex : showcase.currentIndex", screen)

    def test_showcase_owns_the_slide_cycle(self) -> None:
        showcase = home("DesktopHomeShowcase")
        self.assertIn("function showSlide(index) {", showcase)
        self.assertIn("function nextSlide() {", showcase)
        self.assertIn("function previousSlide() {", showcase)
        self.assertIn("id: progressTicker", showcase)
        # Hovering the stage holds the auto-cycle so copy stays readable.
        self.assertIn("!heroHover.hovered", showcase)
        self.assertIn("!motionOff", showcase)

    def test_showcase_actions_include_play_details_library_and_pin(self) -> None:
        showcase = home("DesktopHomeShowcase")
        self.assertIn('objectName: index === 0 ? "desktopHeroPlay"', showcase)
        self.assertIn('"desktopHeroDetails"', showcase)
        self.assertIn('"desktopHeroLibrary"', showcase)
        self.assertIn('"desktopHeroPin"', showcase)
        self.assertIn("signal playRequested(var game)", showcase)
        self.assertIn("signal detailsRequested(var game)", showcase)
        self.assertIn("signal favoriteToggled(var game)", showcase)
        self.assertIn("selectedAction: root.selectedAction", showcase)
        self.assertIn("onActionPointed: index => root.actionPointed(index)", showcase)

    def test_showcase_explains_a_signed_out_library(self) -> None:
        showcase = home("DesktopHomeShowcase")
        self.assertIn("visible: !root.signedIn", showcase)
        self.assertIn("signal signInRequested()", showcase)


class HomeBackdropContracts(unittest.TestCase):
    def test_backdrop_crossfades_between_exactly_two_layers(self) -> None:
        backdrop = home("DesktopHomeBackdrop")
        self.assertIn("component ArtLayer: Item {", backdrop)
        self.assertIn("id: layerA", backdrop)
        self.assertIn("id: layerB", backdrop)
        self.assertIn("function promoteHiddenLayer() {", backdrop)
        self.assertIn("property bool topIsA: true", backdrop)
        # A stalled download must not leave the old game on screen forever.
        self.assertIn("id: swapFallback", backdrop)

    def test_backdrop_decodes_art_at_quarter_resolution(self) -> None:
        backdrop = home("DesktopHomeBackdrop")
        self.assertIn("Math.ceil(width / 4)", backdrop)
        self.assertIn("asynchronous: true", backdrop)
        self.assertIn("fillMode: Image.PreserveAspectCrop", backdrop)

    def test_backdrop_motion_is_disabled_under_reduced_motion(self) -> None:
        backdrop = home("DesktopHomeBackdrop")
        self.assertIn("readonly property bool motionOff: AppController.reducedMotion", backdrop)
        self.assertIn("running: root.active && !root.motionOff", backdrop)
        self.assertIn("if (root.motionOff || root.firstPaint) {", backdrop)

    def test_backdrop_scrims_are_theme_aware(self) -> None:
        backdrop = home("DesktopHomeBackdrop")
        self.assertIn("root.lightMode ?", backdrop)
        self.assertIn("Theme.shell", backdrop)


class HomeRailContracts(unittest.TestCase):
    def test_rails_read_their_content_from_the_store(self) -> None:
        screen = home("DesktopHomeScreen")
        for binding in ("games: root.continueGames", "games: root.favoriteGames",
                        "games: root.newGames", "games: root.similarGames"):
            self.assertIn(binding, screen, binding)
        self.assertIn("ShellStore.isFavorite(visibleGames[index])", screen)
        self.assertIn("ShellStore.isHidden(games[index])", screen)

    def test_similar_rail_falls_back_to_most_played(self) -> None:
        screen = home("DesktopHomeScreen")
        similar = re.search(
            r"readonly property var similarGames: \{.*?\n    \}", screen, re.DOTALL)
        self.assertIsNotNone(similar)
        body = similar.group(0)
        self.assertIn("heroGenre", body)
        self.assertIn("Number(right.hoursPlayed || 0) - Number(left.hoursPlayed || 0)", body)

    def test_rail_card_geometry_comes_from_the_available_width(self) -> None:
        screen = home("DesktopHomeScreen")
        self.assertIn("readonly property int homeTileCount: {", screen)
        self.assertIn("readonly property int homeTileWidth:", screen)
        self.assertIn("readonly property int homeTileHeight:", screen)
        self.assertIn("tileWidth: root.homeTileWidth", screen)
        self.assertIn("tileHeight: root.homeTileHeight", screen)

    def test_rail_and_dock_scroll_themselves(self) -> None:
        rail = home("DesktopHomeRail")
        self.assertIn("id: shelfFlick", rail)
        self.assertIn("function ensureIndexVisible(index) {", rail)
        self.assertIn("function nudge(direction) {", rail)
        dock = home("DesktopHomeDock")
        self.assertIn("id: tileFlick", dock)
        self.assertIn("function ensureTileVisible(index) {", dock)
        self.assertIn("function nudge(direction) {", dock)

    def test_rails_have_empty_and_loading_states(self) -> None:
        rail = home("DesktopHomeRail")
        self.assertIn("id: emptyState", rail)
        self.assertIn("id: skeletonRow", rail)
        self.assertIn("property string emptyText: \"\"", rail)
        self.assertIn("signal emptyActionRequested()", rail)


class HomePosterContracts(unittest.TestCase):
    def test_poster_keeps_the_details_and_play_hit_testing(self) -> None:
        poster = home("DesktopHomePoster")
        self.assertIn('objectName: "desktopHomePoster-" + String(game && game.id || "")', poster)
        self.assertIn("function activateAt(position) {", poster)
        self.assertIn("overlay.playButton", poster)
        self.assertIn("root.playRequested()", poster)
        self.assertIn("root.activated()", poster)
        self.assertIn('id: overlay', poster)
        self.assertIn("visible: root.highlighted", poster)

    def test_poster_does_not_double_zoom_artwork(self) -> None:
        poster = home("DesktopHomePoster")
        self.assertIn("scale: 1 + 0.03 * root.hoverMorph", poster)
        artwork = re.search(r"RoundedArtwork\s*\{(.*?)\n        \}", poster, re.DOTALL)
        self.assertIsNotNone(artwork)
        self.assertNotIn("scale:", artwork.group(1))

    def test_poster_surfaces_playtime_and_pinning(self) -> None:
        poster = home("DesktopHomePoster")
        self.assertIn("readonly property real playProgress:", poster)
        self.assertIn('objectName: "desktopHomePosterFavorite"', poster)
        self.assertIn("ShellStore.toggleFavorite(game)", poster)
        self.assertIn("Qt.RightButton", poster)
        self.assertIn("Accessible.onPressAction: root.activated()", poster)

    def test_dock_tile_reports_session_and_membership_state(self) -> None:
        tile = home("DesktopHomeDockTile")
        self.assertIn("ShellStore.resumableSession", tile)
        self.assertIn("ShellStore.gameLockedByMembership(game)", tile)
        self.assertIn('objectName: "desktopDockTilePlay"', tile)
        self.assertIn('objectName: "desktopDockTileFavorite"', tile)


class HomeHeaderContracts(unittest.TestCase):
    def test_header_reports_library_totals(self) -> None:
        header = home("DesktopHomeHeader")
        self.assertIn("property int totalGames: 0", header)
        self.assertIn("property int favoriteCount: 0", header)
        self.assertIn("property real totalHours: 0", header)
        self.assertIn("property string streamLabel: \"\"", header)

    def test_header_tabs_mirror_the_sidebar_routes(self) -> None:
        header = home("DesktopHomeHeader")
        self.assertIn('signal libraryRequested()', header)
        self.assertIn('signal storeRequested()', header)
        self.assertIn('signal gamesRequested()', header)
        self.assertIn("function activateTab(index) {", header)
        self.assertIn('{ id: "games", label: qsTr("Games")', header)

    def test_header_can_refresh_the_catalog(self) -> None:
        header = home("DesktopHomeHeader")
        self.assertIn("signal syncRequested()", header)
        screen = home("DesktopHomeScreen")
        self.assertIn('onSyncRequested: ShellStore.refreshCatalog("")', screen)


class HomeEmptyStateContracts(unittest.TestCase):
    def test_empty_state_covers_every_no_games_reason(self) -> None:
        empty = home("DesktopHomeEmptyState")
        self.assertIn('readonly property string uiState: !signedIn ? "signed-out"', empty)
        # QQuickItem owns `state`, so the component must not shadow it.
        self.assertNotIn("readonly property string state:", empty)
        for state in ('"signed-out"', '"syncing"', '"error"', '"empty"'):
            self.assertIn(state, empty, state)
        self.assertIn("signal signInRequested()", empty)
        self.assertIn("signal retryRequested()", empty)
        self.assertIn("signal libraryRequested()", empty)
        self.assertIn("signal storeRequested()", empty)

    def test_screen_switches_between_hero_and_empty_state(self) -> None:
        screen = home("DesktopHomeScreen")
        self.assertIn("readonly property bool hasGames: visibleGames.length > 0", screen)
        self.assertIn("visible: root.hasGames", screen)
        self.assertIn("visible: !root.hasGames", screen)
        self.assertIn("dim: root.hasGames ? 0 : 0.62", screen)


class HomeScrollContracts(unittest.TestCase):
    """One writer per shelf, so animation and reduced motion cannot disagree."""

    def test_dock_and_rail_scroll_through_a_single_helper(self) -> None:
        for name in ("DesktopHomeDock", "DesktopHomeRail"):
            with self.subTest(component=name):
                source = home(name)
                self.assertIn("function setScroll(value) {", source)
                self.assertIn("property bool animatedScroll: true", source)
                self.assertIn("readonly property bool scrollAnimates:", source)
                # A Behaviour on contentX would re-animate every step of the
                # explicit animation and defeat animatedScroll: false.
                self.assertNotIn("Behavior on contentX", source)

    def test_every_programmatic_scroll_goes_through_the_helper(self) -> None:
        dock = home("DesktopHomeDock")
        rail = home("DesktopHomeRail")
        self.assertIn("root.setScroll(", dock)
        self.assertIn("root.setScroll(", rail)
        for name, source, flick in (("dock", dock, "tileFlick"), ("rail", rail, "shelfFlick")):
            with self.subTest(shelf=name):
                body = function_body(source, "setScroll")
                self.assertIn("%s.contentX = target" % flick, body)
                for fn in ("ensureTileVisible", "ensureIndexVisible"):
                    if ("function %s(" % fn) in source:
                        self.assertNotIn("%s.contentX = " % flick, function_body(source, fn))

    def test_rail_paging_helpers_are_present(self) -> None:
        rail = home("DesktopHomeRail")
        for fn in ("scrollToStart", "scrollToEnd", "centerOn", "nudge"):
            self.assertIn("function %s(" % fn, rail)
        dock = home("DesktopHomeDock")
        for fn in ("scrollToStart", "scrollToEnd", "pageForward", "pageBack", "centerOn"):
            self.assertIn("function %s(" % fn, dock)
        self.assertIn("readonly property int pageStep:", dock)


class HomeRailPresentationContracts(unittest.TestCase):
    def test_rail_sorts_locally_without_touching_the_page_model(self) -> None:
        rail = home("DesktopHomeRail")
        self.assertIn('property string sortMode: "default"', rail)
        self.assertIn('readonly property var sortModes: ["default", "recent", "hours", "title"]', rail)
        self.assertIn("function cycleSort() {", rail)
        self.assertIn("readonly property var sortedGames:", rail)
        # The shelf renders the sorted copy; the Repeater must not read `games`.
        self.assertIn("model: root.sortedGames", rail)
        self.assertNotIn("model: root.games", rail)

    def test_rail_can_collapse_but_keeps_its_header(self) -> None:
        rail = home("DesktopHomeRail")
        self.assertIn("property bool collapsed: false", rail)
        self.assertIn("function toggleCollapsed() {", rail)
        self.assertIn("implicitHeight: headerHeight + (collapsed ? 0 : tileHeight + DesktopTokens.px(10))", rail)
        self.assertIn("visible: !root.isEmpty && !root.collapsed", rail)

    def test_rail_echoes_the_hero_spotlight_onto_one_card(self) -> None:
        rail = home("DesktopHomeRail")
        self.assertIn("property string spotlightTitle:", rail)
        self.assertIn("readonly property int spotlightIndex:", rail)
        self.assertIn("featured: root.spotlightIndex === index", rail)
        screen = home("DesktopHomeScreen")
        self.assertEqual(screen.count("spotlightTitle: root.backdropGame ? String(root.backdropGame.title"), 4)
        poster = home("DesktopHomePoster")
        self.assertIn("property bool featured: false", poster)

    def test_rail_reports_its_scroll_position(self) -> None:
        rail = home("DesktopHomeRail")
        self.assertIn("readonly property real scrollSpan:", rail)
        self.assertIn("readonly property real scrollProgress:", rail)
        self.assertIn("readonly property real scrollThumb:", rail)
        self.assertIn("id: scrollTrack", rail)


class HomeBackdropStateContracts(unittest.TestCase):
    def test_backdrop_publishes_one_art_state(self) -> None:
        backdrop = home("DesktopHomeBackdrop")
        self.assertIn("readonly property string artState:", backdrop)
        for state in ('"missing"', '"loading"', '"ready"', '"idle"'):
            self.assertIn(state, backdrop)
        self.assertIn("signal artStateUpdated(string value)", backdrop)
        self.assertIn("onArtStateChanged: root.artStateUpdated(artState)", backdrop)

    def test_backdrop_parallax_and_idle_dim_are_owner_controllable(self) -> None:
        backdrop = home("DesktopHomeBackdrop")
        self.assertIn("property real parallaxStrength: 1", backdrop)
        self.assertIn("property bool idleDimming: true", backdrop)
        self.assertIn("property int idleDelay: 180000", backdrop)
        self.assertIn("function wakeFromIdle() {", backdrop)
        self.assertIn("id: idleTimer", backdrop)
        self.assertIn("* root.parallaxStrength", backdrop)
        self.assertIn("+ root.idleAmount", backdrop)
        screen = home("DesktopHomeScreen")
        self.assertIn("parallaxStrength: root.overlayOpen ? 0 : 1", screen)
        self.assertIn("idleDimming: !root.overlayOpen", screen)

    def test_no_qtobject_is_used_as_a_repeater_delegate(self) -> None:
        # Regression: the backdrop warmed its art cache with a Repeater over
        # ArtworkSource, which is a QtObject. The model was empty in CI, so the
        # warning only appeared once a real library loaded.
        offenders = []
        for name in HOME_COMPONENTS:
            source = home(name)
            for line, delegate in repeater_delegates(source):
                offenders.append("%s:%d %s" % (name, line, delegate))
        self.assertEqual(offenders, [])

    def test_backdrop_warms_a_bounded_art_cache(self) -> None:
        backdrop = home("DesktopHomeBackdrop")
        self.assertIn("readonly property var warmUrls:", backdrop)
        self.assertIn("function warmUrl(index) {", backdrop)
        self.assertEqual(backdrop.count("ArtworkSource {"), 3)
        self.assertIn("list.length < 3", backdrop)
        screen = home("DesktopHomeScreen")
        self.assertIn("warmGames: root.warmGames", screen)

    def test_screen_drives_the_new_backdrop_api(self) -> None:
        screen = home("DesktopHomeScreen")
        for binding in (
            "exposure: root.overlayOpen",
            "heroFocused: root.heroFocused",
            "warmGames: root.warmGames",
            "seamPosition: root.heroSeam",
            "fallbackSeed: root.backdropSeed",
            "artDescription: root.backdropDescription",
            "vignette: Theme.lightMode",
        ):
            with self.subTest(binding=binding):
                self.assertIn(binding, screen)
        # The warm cache must include whatever the pointer is inspecting.
        self.assertIn("list.unshift(hoveredDockGame)", screen)


class HomeDockHoverContracts(unittest.TestCase):
    def test_dock_publishes_hover_as_a_signal_not_a_binding(self) -> None:
        dock = home("DesktopHomeDock")
        self.assertIn("signal gameHovered(var game)", dock)
        self.assertIn("function publishHover(index) {", dock)
        screen = home("DesktopHomeScreen")
        self.assertIn("onGameHovered: game => root.hoveredDockGame = game", screen)
        # The dock writes hoveredGame itself; an owner binding would fight it.
        self.assertNotIn("hoveredGame: dock.hoveredGame", screen)

    def test_dock_density_reaches_the_screen(self) -> None:
        dock = home("DesktopHomeDock")
        self.assertIn('property string density: "comfortable"', dock)
        self.assertIn('readonly property int tilePad: density === "compact"', dock)
        screen = home("DesktopHomeScreen")
        self.assertIn("density: root.dockDensity", screen)
        self.assertIn('readonly property string dockDensity: height < DesktopTokens.px(720) ? "compact" : "comfortable"', screen)


class HomePressFeedbackContracts(unittest.TestCase):
    def test_press_morph_is_declared_exactly_once_per_component(self) -> None:
        # A duplicate declaration turns one of them into a dead binding.
        self.assertEqual(home("DesktopHomePoster").count("property real pressMorph"), 1)
        self.assertEqual(home("DesktopHomeDockTile").count("property real pressMorph"), 1)

    def test_press_releases_fire_a_single_ripple(self) -> None:
        for name in ("DesktopHomePoster", "DesktopHomeDockTile"):
            with self.subTest(component=name):
                source = home(name)
                self.assertIn("id: rippleAnimation", source)
                self.assertIn("rippleAnimation.restart()", source)
                self.assertIn("if (!pressed && !root.motionOff)", source)


class HomeEmptyStateLayoutContracts(unittest.TestCase):
    def test_plate_measures_its_content_instead_of_overlapping_it(self) -> None:
        empty = home("DesktopHomeEmptyState")
        self.assertIn("readonly property real contentTop: DesktopTokens.px(24)", empty)
        self.assertIn("readonly property real contentBottom: tipLine.y + tipLine.height", empty)
        self.assertIn("height: root.contentBottom - root.contentTop + DesktopTokens.px(24)", empty)
        self.assertIn("implicitHeight: contentTop + plate.height + DesktopTokens.px(24)", empty)
        # The plate is pinned to a constant top, which is what keeps the chain
        # acyclic; centring it would feed plate.height back into every child y.
        self.assertIn("id: plate\n        anchors.horizontalCenter: parent.horizontalCenter\n        y: root.contentTop", empty)
        self.assertNotIn("y: plate.y + plate.height - DesktopTokens.px(28)", empty)

    def test_empty_state_reports_live_facts_in_every_state(self) -> None:
        empty = home("DesktopHomeEmptyState")
        self.assertIn("readonly property var statusCells:", empty)
        self.assertIn("id: statusGrid", empty)
        self.assertIn("model: root.statusCells", empty)
        self.assertIn("y: stepRow.y + stepRow.height + DesktopTokens.px(16)", empty)
        self.assertIn("y: statusGrid.y + statusGrid.height + DesktopTokens.px(18)", empty)
        for label in ('qsTr("ACCOUNT")', 'qsTr("LIBRARY")', 'qsTr("HIDDEN")', 'qsTr("STORE")'):
            self.assertIn(label, empty)

    def test_failed_sync_retries_on_a_countdown_and_can_be_copied(self) -> None:
        empty = home("DesktopHomeEmptyState")
        self.assertIn("property int retryCooldown: 15", empty)
        self.assertIn("property int retryLimit: 3", empty)
        self.assertIn("property int retrySeconds: 0", empty)
        self.assertIn("readonly property bool retryArmed:", empty)
        self.assertIn("function requestRetry() {", empty)
        self.assertIn("function copyDiagnostics() {", empty)
        self.assertIn("AppController.writeClipboardText(diagnosticsText)", empty)
        self.assertIn("id: retryTimer", empty)
        # The button and the countdown must share one code path.
        self.assertIn("onClicked: root.requestRetry()", empty)
        self.assertNotIn("onClicked: root.retryRequested()", empty)

    def test_all_hidden_library_is_explained_not_reported_as_empty(self) -> None:
        empty = home("DesktopHomeEmptyState")
        self.assertIn("readonly property int hiddenCount:", empty)
        self.assertIn("readonly property bool allHidden:", empty)
        self.assertIn("ShellStore.isHidden(game)", empty)
        self.assertIn('qsTr("Everything is hidden")', empty)
        screen = home("DesktopHomeScreen")
        self.assertIn('onRetryRequested: ShellStore.refreshCatalog("")', screen)


class HomeHeaderContextContracts(unittest.TestCase):
    def test_header_takes_density_sync_stamp_and_live_session(self) -> None:
        header = home("DesktopHomeHeader")
        self.assertIn('property string density: "comfortable"', header)
        self.assertIn('property string lastSyncedLabel: ""', header)
        self.assertIn('property string nowPlayingTitle: ""', header)
        self.assertIn("readonly property bool compact: density === \"compact\"", header)
        self.assertIn("implicitHeight: DesktopTokens.px(compact ? 62 : 78)", header)
        screen = home("DesktopHomeScreen")
        self.assertIn("density: root.dockDensity", screen)
        self.assertIn("lastSyncedLabel: root.lastSyncedAgo", screen)
        self.assertIn("nowPlayingTitle: root.sessionTitle", screen)

    def test_header_does_not_double_prefix_the_sync_stamp(self) -> None:
        # lastSyncLabel already reads "Synced 3 min ago"; the header adds its
        # own prefix, so it must be fed the bare relative stamp.
        screen = home("DesktopHomeScreen")
        self.assertIn("readonly property string lastSyncedAgo:", screen)
        self.assertNotIn("lastSyncedLabel: root.lastSyncLabel", screen)


class HomeTranslationContracts(unittest.TestCase):
    """npm run locales:check gates CI; pin the same rule here."""

    def test_every_home_string_is_registered_in_the_source_locale(self) -> None:
        en = json.loads((REPO_ROOT / "locales" / "en.json").read_text(encoding="utf-8"))

        known = set()

        def collect(value):
            if isinstance(value, str):
                known.add(value)
            elif isinstance(value, dict):
                for child in value.values():
                    collect(child)

        collect(en)
        pattern = re.compile(r'\b(?:qsTr|I18n\.source)\(\s*("(?:\\.|[^"\\])*")')
        for name in HOME_COMPONENTS:
            source = home(name)
            texts = {json.loads(match.group(1)) for match in pattern.finditer(source)}
            with self.subTest(component=name):
                # A pattern that matched nothing would make this test vacuous.
                self.assertTrue(texts, "no qsTr strings found in %s" % name)
            missing = sorted(text for text in texts if text and text not in known)
            with self.subTest(component=name):
                self.assertEqual(missing, [], "unregistered qsTr strings in %s" % name)

    def test_no_string_arg_call_passes_more_than_one_value(self) -> None:
        # Regression: three of these shipped in the first cut of the redesign and
        # only surfaced when the Windows smoke test rendered the page.
        for name in HOME_COMPONENTS:
            offenders = ["%s:%d %s" % (name, line, snippet)
                         for line, snippet in multi_arg_calls(home(name))]
            with self.subTest(component=name):
                self.assertEqual(offenders, [])

    def test_home_strings_live_in_a_dedicated_namespace(self) -> None:
        en = json.loads((REPO_ROOT / "locales" / "en.json").read_text(encoding="utf-8"))
        self.assertIn("desktopHome", en)
        keys = list(en["desktopHome"])
        self.assertTrue(all(re.fullmatch(r"source\d{3}", key) for key in keys), keys[:5])
        self.assertEqual(keys, sorted(keys))


if __name__ == "__main__":
    unittest.main()
