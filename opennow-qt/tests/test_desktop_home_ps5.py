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
import re
import unittest


QT_ROOT = Path(__file__).resolve().parents[1]

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


if __name__ == "__main__":
    unittest.main()
