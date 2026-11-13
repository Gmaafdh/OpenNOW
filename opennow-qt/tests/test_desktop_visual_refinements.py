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
        self.assertIn("duration: Theme.duration(560)", hero)

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
        card = qml("desktop/library/DesktopLibraryCard.qml")
        library = qml("desktop/library/DesktopLibraryScreen.qml")
        tokens = qml("desktop/components/DesktopTokens.qml")
        # The grid and the card derive their cell from one shared contract, so a
        # landscape tile can never be taller or shorter than its artwork.
        self.assertIn("DesktopTokens.libraryCardHeight(tileWidth, showTitle)", card)
        self.assertIn("DesktopTokens.libraryCardHeight(libraryCellW, tileLabelsVisible)", library)
        self.assertIn("libraryCardArtWidth(cellWidth) * 9 / 16", tokens)
        self.assertIn("DesktopTokens.libraryCardBaseWidth * tileScale", library)
        self.assertIn("statusLabel", card)
        self.assertIn("primaryStoreIcon", card)
        self.assertIn("maximumLineCount: 1", card)
        self.assertIn("pressAnimation.stop()", card)
        self.assertIn("root.revealProgress = 1", card)
        self.assertNotIn("Easing.OutBack", card)

    def test_library_card_action_gradient_follows_the_accent(self) -> None:
        card = qml("desktop/library/DesktopLibraryCard.qml")
        tokens = qml("desktop/components/DesktopTokens.qml")
        details = qml("desktop/components/DesktopGameModal.qml")
        # Both hero actions sweep accent -> violet and keep the fixed dark ink,
        # so a custom accent can never produce an unreadable button.
        self.assertIn("Theme.mixColors(Theme.focus, Theme.violet, 70)", tokens)
        self.assertIn('readonly property color actionInk: "#0A0D14"', tokens)
        # Light enough for the fixed dark ink at every stop, but no lighter.
        self.assertIn("tintToward(Theme.mixColors(Theme.focus, Theme.violet, 18), 0.40)", tokens)
        self.assertIn("tintToward(actionViolet, 0.16)", tokens)
        self.assertIn("DesktopTokens.actionStart", card)
        self.assertIn("DesktopTokens.actionEnd", card)
        self.assertIn("DesktopTokens.actionInk", card)
        self.assertIn("DesktopTokens.actionStart", details)
        self.assertIn("DesktopTokens.actionEnd", details)
        # The detail CTA keeps DesktopButton's primary ink, which is exactly the
        # ink the sweep is tuned for, so the two can never drift apart.
        self.assertIn('color: root.primary ? "#0A0D14"', qml("desktop/components/DesktopButton.qml"))
        self.assertIn('readonly property color actionInk: "#0A0D14"', tokens)

    def test_library_card_keeps_the_label_and_reach_contracts(self) -> None:
        card = qml("desktop/library/DesktopLibraryCard.qml")
        library = qml("desktop/library/DesktopLibraryScreen.qml")
        # The acceptance suites collect the label tree from the live delegate, so
        # the landscape card has to keep every name and tip anchor it replaces.
        self.assertIn("DesktopGameLabels {", card)
        self.assertIn("DesktopGameLabelTip {", card)
        self.assertIn("objectName: \"desktopLibraryCardPlay\"", card)
        self.assertIn("objectName: \"desktopLibraryCardDetails\"", card)
        self.assertIn("objectName: \"desktopLibraryCardStatus\"", card)
        self.assertIn("signal playActivated()", card)
        self.assertIn("signal detailsActivated()", card)
        self.assertIn("root.playActivated()", card)
        self.assertIn("root.detailsActivated()", card)
        # The play action is part of the card, not a hover-only reveal, and the
        # details chip drops out instead of landing on top of the artwork.
        self.assertNotIn("playRevealed", card)
        self.assertIn("visible: playPill.x + playPill.width", card)
        # Two rows beyond the fold stay instantiated on a short window.
        self.assertIn("cacheBuffer: Math.max(DesktopTokens.px(320), root.libraryCellH * 2)", library)

    def test_detail_view_is_a_full_screen_landscape_presentation(self) -> None:
        details = qml("desktop/components/DesktopGameModal.qml")
        # Full-bleed artwork with one left-hand column for the title and actions.
        self.assertIn("readonly property int dialogWidth: width", details)
        # The artwork fills the window: a cover crop has no letterbox bands, and
        # the scroll thumb appears only while scrolling instead of drawing a
        # permanent rule across the art.
        self.assertIn("cinematicFit: false", details)
        # The cover crop is centred: key art subjects live in the middle of
        # the banner, not at its right edge.
        self.assertNotIn("coverAlignRight", details)
        self.assertNotIn("alignArtworkRight", details)
        self.assertIn("policy: ScrollBar.AsNeeded", details)
        self.assertIn("background: Item {}", details)
        # The way back to the library sits where the shell navigation was.
        self.assertIn('objectName: "gameDetailsBack"', details)
        self.assertIn("visible: !root.compactDetails", details)
        self.assertIn("readonly property int contentInset: DesktopTokens.px(56)", details)
        self.assertIn("id: backdrop", details)
        self.assertIn("anchors.fill: parent", details)
        # The column stops short of the close button, so a corner action can
        # never sit on top of the title.
        # The whole presentation is centred: one reading column for the title
        # and actions, and a wider centred stage whose bottom row is the
        # summary bar.
        self.assertIn("readonly property int columnX", details)
        self.assertIn("Math.round((width - contentWidth) / 2)", details)
        self.assertIn("x: root.columnX", details)
        self.assertIn("readonly property int stageX", details)
        self.assertIn("x: root.stageX", details)
        self.assertIn("x: root.columnInStage", details)
        self.assertIn("width: root.stageWidth", details)
        # A short window shrinks the title block and the CTA together and keeps
        # the hero proportional, so the primary action stays inside the cap.
        self.assertIn("readonly property bool compactDetails: maximumDialogHeight < DesktopTokens.px(620)", details)
        self.assertIn("Math.round(maximumDialogHeight * 0.36)", details)
        self.assertIn("maximumLineCount: root.compactDetails ? 1 : 2", details)
        self.assertIn("Layout.preferredHeight: root.primaryActionHeight", details)
        self.assertNotIn("DesktopTokens.px(300)", details)
        # What the mock asks for below the CTA: the store the license comes from
        # and the stream requests this game would launch with.
        self.assertIn("objectName: \"gameDetailsStoreRequirement\"", details)
        self.assertIn("objectName: \"gameDetailsGameplaySettings\"", details)
        self.assertIn("objectName: \"gameDetailsGameplaySettingsPanel\"", details)
        self.assertIn("model: root.streamRows", details)
        self.assertIn("property bool gameplaySettingsShown: false", details)
        # The scrims follow the theme, so the existing label colours keep their
        # contrast on top of artwork in Paper as well as in the dark themes.
        self.assertIn("readonly property color scrimFlat: Theme.lightMode", details)

    def test_home_cards_do_not_double_zoom_artwork(self) -> None:
        poster = qml("desktop/home/DesktopHomePoster.qml")
        self.assertIn("scale: 1 + 0.03 * root.hoverMorph", poster)
        self.assertNotIn("scale: 1 + 0.045 * root.hoverMorph", poster)
        artwork = re.search(r"RoundedArtwork\s*\{(.*?)\n        \}", poster, re.DOTALL)
        self.assertIsNotNone(artwork)
        self.assertNotIn("scale:", artwork.group(1))


if __name__ == "__main__":
    unittest.main()
