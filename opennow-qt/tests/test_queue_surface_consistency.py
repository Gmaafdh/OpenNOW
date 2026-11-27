"""Pins the queue page to the home page's surface language.

The queue used to speak a different dialect than the rest of the shell:
glass panels with white alpha gradients, radial glow blobs, a scan beam,
rising motes, a tilting levitating cover and media-surface inks. The home
page speaks shell surfaces: theme-aware fills, seam borders, raised inner
rows, mint accents and label inks. These pins keep the queue on the home
dialect and keep every behavioural hook the acceptance routes rely on.
"""

from pathlib import Path
import unittest

QT_ROOT = Path(__file__).resolve().parents[1]
QUEUE = (QT_ROOT / "qml" / "desktop" / "stream" / "DesktopQueueExperience.qml").read_text(encoding="utf-8")
BACKDROP = (QT_ROOT / "qml" / "desktop" / "components" / "DesktopBackdrop.qml").read_text(encoding="utf-8")


class QueueSurfaceConsistencyContracts(unittest.TestCase):
    def test_futuristic_dialect_is_gone(self) -> None:
        for gone in ("GlowBlob", "#06080E", "Rising motes", "scan beam",
                     "onMediaBackground", "Theme.mediaAccent", "Theme.mediaForeground",
                     "dashPattern", "flowPhase", "floatPhase"):
            self.assertNotIn(gone, QUEUE)

    def test_queue_uses_the_home_surface_recipe(self) -> None:
        # Same panel fill as the home showcase card.
        self.assertIn('color: Theme.lightMode ? "#F2F5FA" : "#E60B1320"', QUEUE)
        # Same card fill as the home library posters.
        self.assertIn('color: Theme.lightMode ? "#F0F3F8" : "#E617202D"', QUEUE)
        for token in ("DesktopTokens.seam", "DesktopTokens.seamSoft",
                      "DesktopTokens.raised", "DesktopTokens.mint",
                      "DesktopTokens.textHigh", "DesktopTokens.textMuted",
                      "DesktopTokens.cardOutlineIdle"):
            self.assertIn(token, QUEUE)
        # The backdrop crops the key art edge to edge like the home backdrop.
        self.assertIn("sourceSize: Qt.size(1440, 900)", QUEUE)
        self.assertIn("sourceSize: Qt.size(1440, 900)", BACKDROP)
        self.assertIn("Rectangle { anchors.fill: parent; color: DesktopTokens.shell }", QUEUE)

    def test_behavioural_hooks_survive_the_restyle(self) -> None:
        for name in ("desktopQueueExperience", "desktopQueuePass",
                     "sessionQueuePositionBlock", "desktopQueueRequeue",
                     "desktopQueueRefresh", "desktopQueueCancel"):
            self.assertIn('objectName: "%s"' % name, QUEUE)
        # The morphing texts carry their hooks through contentObjectName.
        for name in ("sessionQueueStatus", "sessionQueuePosition"):
            self.assertIn('contentObjectName: "%s"' % name, QUEUE)
        for hook in ("signal cancelRequested()", "signal refreshRequested()",
                     "signal requeueRequested()", "function restoreFocus()",
                     "function synchronizePeakPosition()"):
            self.assertIn(hook, QUEUE)


if __name__ == "__main__":
    unittest.main()
