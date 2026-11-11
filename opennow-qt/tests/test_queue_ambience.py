"""Contracts for the queue page's ambient colour and glow system.

The queue backdrop is the one surface in OpenNOW that is lit rather than laid
out, and three separate systems meet on it:

* ``tst_sessionstarting.qml`` audits the queue copy against a fixed dark media
  surface (``#04060A``) for a 4.5:1 ratio, across every theme pack and accent.
* The same test pins the page geometry at five window sizes, so the ambience may
  never move copy around.
* Settings -> Appearance -> Ambient glow (``Theme.glow``) has to reach this page
  like it reaches ``DesktopBackdrop`` and ``ScreenBackground``.

Nothing here renders. These tests keep the lighting honest statically, which is
the only way to check it on a headless runner.
"""

from pathlib import Path
import re
import unittest


QT_ROOT = Path(__file__).resolve().parents[1]
PAGE = "desktop/stream/DesktopQueueExperience.qml"
THEME_TEST = "theme/tst_sessionstarting.qml"
# The surface tst_sessionstarting composites queue copy against. The page's own
# floor has to be this colour or the contrast audit measures a fiction.
MEDIA_SURFACE = "#04060A"
PALETTE_TOKENS = ("root.glowKey", "root.glowCompanion", "root.glowField")


def qml(path: str) -> str:
    return (QT_ROOT / "qml" / path).read_text(encoding="utf-8")


def tests(path: str) -> str:
    return (QT_ROOT / "tests" / path).read_text(encoding="utf-8")


def block(text: str, start: str, end: str) -> str:
    """The slice of `text` between two unique markers."""
    begin = text.index(start)
    return text[begin:text.index(end, begin)]


def gradient_stops(text: str) -> list[tuple[float, int]]:
    """(position, alpha) for every literal 8-digit ARGB stop in `text`."""
    return [
        (float(position), int(alpha, 16))
        for position, alpha in re.findall(
            r'GradientStop \{ position: ([\d.]+); color: "#([0-9A-Fa-f]{2})[0-9A-Fa-f]{6}" \}',
            text,
        )
    ]


class QueueAmbienceContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = qml(PAGE)
        cls.backdrop = block(cls.source, "id: backdrop", "// ───────────────────────── content")

    def test_backdrop_floor_is_the_audited_media_surface(self) -> None:
        self.assertIn(
            'Rectangle { anchors.fill: parent; color: "%s" }' % MEDIA_SURFACE, self.source
        )
        # The artwork viewer scrim is the same surface, just near-opaque.
        self.assertIn('color: "#F204060A"', self.source)
        for retired in ("#06080E", "#060810"):
            self.assertNotIn(retired, self.source, "retired backdrop surface is back")

    def test_ambience_palette_is_derived_from_theme_tokens(self) -> None:
        self.assertIn("readonly property color glowKey: Theme.mediaAccent", self.source)
        companion = block(self.source, "readonly property color glowCompanion:", "readonly property color glowField:")
        field = block(self.source, "readonly property color glowField:", "readonly property color orbitInk:")
        self.assertIn("Theme.hslFromColor(Theme.mediaAccent)", companion)
        self.assertIn("Theme.colorFromHsl(", companion)
        self.assertIn("Theme.hslFromColor(Theme.atmosphere)", field)
        self.assertIn("Theme.colorFromHsl(", field)
        self.assertIn('Theme.mixColors("#FFFFFF", glowCompanion, 55)', self.source)
        # A hue invented here would not follow the pack or the accent override,
        # so the derived palettes carry no literal colours of their own.
        for name, palette in (("glowCompanion", companion), ("glowField", field)):
            self.assertNotRegex(palette, r"#[0-9A-Fa-f]{6}", f"{name} hardcodes a colour")

    def test_every_glow_blob_is_scaled_by_the_ambient_glow_setting(self) -> None:
        blob = block(self.source, "component GlowBlob: Shape {", "component GlassPanel:")
        self.assertIn("readonly property real lit: Theme.glow(blob.strength)", blob)
        stops = re.findall(r"GradientStop \{[^}]*Qt\.rgba\(blob\.tint\.r[^}]*\}", blob)
        self.assertEqual(len(stops), 3, "the blob gradient lost a stop")
        self.assertEqual(blob.count("blob.lit"), 2, "both lit stops must use the scaled alpha")
        self.assertEqual(blob.count("blob.strength"), 1, "raw strength may only feed Theme.glow")
        instances = re.findall(r"GlowBlob \{\n(?:.*?\n)*?\s*tint: ([^\n]+)\n", self.source)
        self.assertGreaterEqual(len(instances), 8, "expected the backdrop, cover, ring and viewer blooms")
        for tint in instances:
            self.assertIn(
                tint.strip(),
                PALETTE_TOKENS,
                "a bloom must be lit by a palette hue, not by a literal colour",
            )
        # Rising motes are ambience too, so they fade with the same setting.
        self.assertIn("opacity: Theme.glow(0.10 + seed * 0.25)", self.source)

    def test_structural_chrome_is_never_glow_scaled(self) -> None:
        # With Ambient glow at zero the page must still show queue progress, the
        # panel edges and the arc head; only the blooms may disappear.
        self.assertIn("strokeColor: Theme.mediaAccent", self.source)
        self.assertIn("border.color: root.accentA(", self.source)
        self.assertNotRegex(self.source, r"border\.color: root\.glowA\(")
        self.assertNotRegex(self.source, r"strokeColor: root\.glowA\(root\.glowKey, 1\)")
        ring = block(self.source, "id: ringBox", "// Journey")
        self.assertIn("color: \"#FFFFFF\"", ring, "the arc head must stay a white core")

    def test_copy_band_keeps_its_scrim_cover(self) -> None:
        scrim = block(self.source, "// Legibility scrim", "// Key light, top right")
        stops = gradient_stops(scrim)
        self.assertEqual(len(stops), 5)
        centre = max(stops, key=lambda stop: stop[1])
        self.assertGreaterEqual(centre[1], 0xDE, "the copy band needs near-opaque cover")
        self.assertLessEqual(centre[0], 0.6, "the darkest stop belongs in the copy band")
        for position, alpha in stops:
            if position in (0.0, 1.0):
                self.assertLessEqual(alpha, 0x60, "the extremes must let the colour field through")

    def test_backdrop_lights_three_hues(self) -> None:
        for token in PALETTE_TOKENS:
            self.assertIn(f"tint: {token}", self.backdrop, f"{token} does not light the backdrop")
        # Horizon pool along the bottom edge, behind the panels.
        pool = block(self.backdrop, "// Horizon pool", "// Faint scan beam")
        self.assertIn("anchors.bottom: parent.bottom", pool)
        self.assertIn("root.glowA(root.glowKey,", pool)
        # The scan beam carries the companion hue at its edges.
        beam = block(self.backdrop, "// Faint scan beam", "// Rising motes")
        self.assertIn("root.glowA(root.glowCompanion, 0)", beam)

    def test_pinned_queue_copy_colours_are_untouched(self) -> None:
        # tst_sessionstarting compares the STARTING SESSION pill label with
        # Theme.mediaAccent for every pack and accent, so the pill's default tint
        # and its label binding are part of the contract, not decoration.
        self.assertEqual(self.source.count("property color tint: Theme.mediaAccent"), 2)
        self.assertIn("color: pill.tint", self.source)
        self.assertIn(
            'compare(textItem("STARTING SESSION").color, Theme.mediaAccent)', tests(THEME_TEST)
        )
        self.assertIn("compare(textItem(screen.detailText).color.toString(), Theme.mediaMuted.toString())", tests(THEME_TEST))

    def test_layout_geometry_contract_is_untouched(self) -> None:
        # The compact-layout test measures these at 800x600 up to 1440x900.
        self.assertIn("anchors.topMargin: 58", self.source)
        self.assertIn("height: heroFlow.implicitHeight + 44", self.source)
        self.assertIn(
            "readonly property real ringSize: Math.max(150, Math.min(root.veryCompact ? 176 : 224, queuePass.width - 48))",
            self.source,
        )
        # All three arc strokes share one sweep, so a halo can never disagree
        # with the arc it outlines.
        self.assertIn("readonly property real sweep: root.indeterminate ? 100", self.source)
        self.assertEqual(self.source.count("sweepAngle: progressArc.sweep"), 3)

    def test_ambient_motion_is_reduced_motion_gated(self) -> None:
        for binding in re.findall(r"(?m)^\s*running: (.+)$", self.source):
            self.assertTrue(
                "root.animating" in binding or binding.strip() == "root.visible",
                f"ungated ambient motion: running: {binding}",
            )

    def test_ambience_pass_adds_no_copy(self) -> None:
        # A visual pass must not smuggle in strings: every qsTr here needs a key
        # in all twelve locale files before the contracts job will pass.
        palette = block(self.source, "// ───────────────────────── ambience palette", "function restoreFocus()")
        self.assertNotIn("qsTr(", palette)
        self.assertEqual(len(re.findall(r"qsTr\(", self.source)), 34)


if __name__ == "__main__":
    unittest.main()
