from pathlib import Path
import re
import unittest


QT_ROOT = Path(__file__).resolve().parents[1]


def qml(path: str) -> str:
    return (QT_ROOT / "qml" / path).read_text(encoding="utf-8")


class DesktopVisualRefinementContracts(unittest.TestCase):
    def test_hero_has_no_slide_zoom_and_uses_cinematic_fit(self) -> None:
        hero = qml("desktop/library/DesktopLibraryHero.qml")
        self.assertIn("cinematicFit: true", hero)
        self.assertIn("alignArtworkRight: true", hero)
        self.assertNotIn("1.08 - 0.08", hero)
        self.assertNotRegex(hero, r"(?m)^\s*scale:\s*index === root\.currentIndex")
        self.assertIn("duration: 520", hero)

    def test_home_scroll_is_only_explicit_navigation(self) -> None:
        home = qml("desktop/home/DesktopHomeScreen.qml")
        self.assertIn("function setSelection(zone, index, revealSelection)", home)
        self.assertIn("if (revealSelection === true)", home)
        self.assertNotIn("contentFlick.contentY = 0", home)
        pointed = re.findall(r"onPointed:\s*root\.setSelection\(([^\n]+)\)", home)
        self.assertEqual(len(pointed), 3)
        self.assertTrue(all("true" not in call for call in pointed))
        self.assertIn("root.focusIndex + delta)), true)", home)
        self.assertIn("root.setSelection(nextZone, nextIndex, true)", home)
        self.assertIn("onActionPointed: index => root.setSelection(0, index)", home)
        self.assertIn('selectedAction: root.focusZone === 0 && AppController.inputMode !== "pointer" ? root.focusIndex : -1', home)

    def test_hero_actions_keep_launch_and_details_signals(self) -> None:
        hero = qml("desktop/library/DesktopLibraryHero.qml")
        self.assertIn("signal playRequested(var game)", hero)
        self.assertIn("signal detailsRequested(var game)", hero)
        self.assertIn("root.playRequested(root.currentGame)", hero)
        self.assertIn("root.detailsRequested(root.currentGame)", hero)
        self.assertIn('objectName: "desktopHeroPlay"', hero)
        self.assertIn('objectName: "desktopHeroDetails"', hero)
        self.assertIn('glyph: "desktop-play-filled.svg"', hero)
        self.assertIn('glyph: "desktop-info.svg"', hero)
        self.assertIn("down ? 0.965", hero)
        self.assertIn("visible: action.activeFocus || action.navigationFocus", hero)
        self.assertIn("navigationFocus: root.selectedAction === 0", hero)
        self.assertIn("navigationFocus: root.selectedAction === 1", hero)
        showcase = qml("desktop/home/DesktopHomeShowcase.qml")
        self.assertIn("selectedAction: root.selectedAction", showcase)
        self.assertIn("onActionPointed: index => root.actionPointed(index)", showcase)

    def test_library_card_geometry_and_reduced_motion(self) -> None:
        poster = qml("desktop/components/DesktopPoster.qml")
        library = qml("desktop/library/DesktopLibraryScreen.qml")
        self.assertIn("artHeight + DesktopTokens.px(126)", poster)
        self.assertIn("Math.round(Math.max(1, libraryCellW - 24) * 198 / 132) + DesktopTokens.px(126)", library)
        self.assertIn("maximumLineCount: 2", poster)
        self.assertIn("primaryStoreIcon", poster)
        self.assertIn("pressAnimation.stop()", poster)
        self.assertIn("root.revealProgress = 1", poster)
        self.assertNotIn("Easing.OutBack", poster)

    def test_home_cards_do_not_double_zoom_artwork(self) -> None:
        poster = qml("desktop/home/DesktopHomePoster.qml")
        self.assertIn("scale: 1 + 0.03 * root.hoverMorph", poster)
        self.assertNotIn("scale: 1 + 0.045 * root.hoverMorph", poster)
        artwork = re.search(r"RoundedArtwork\s*\{(.*?)\n        \}", poster, re.DOTALL)
        self.assertIsNotNone(artwork)
        self.assertNotIn("scale:", artwork.group(1))


if __name__ == "__main__":
    unittest.main()
