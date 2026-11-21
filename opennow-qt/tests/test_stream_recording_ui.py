"""Pins the in-game recording chrome on the stream screen.

Video recording existed end to end (native mkv capture, Ctrl+K menu row, guide
tile, F12) but had no presence over the game itself: nothing showed while a
take was running and nothing surfaced the saved file until the media page.
The stream screen now carries a REC pill - pulsing dot, elapsed take, one
click stops and saves - plus a four-second media notice for screenshot and
recording messages. These pins keep that chrome wired to the store and keep
it out of the game's input and occlusion paths.
"""

from pathlib import Path
import unittest

QT_ROOT = Path(__file__).resolve().parents[1]
SCREEN = (QT_ROOT / "qml" / "desktop" / "stream" / "DesktopStreamScreen.qml").read_text(encoding="utf-8")
MENU = (QT_ROOT / "qml" / "desktop" / "stream" / "DesktopInStreamMenu.qml").read_text(encoding="utf-8")


class StreamRecordingUiContracts(unittest.TestCase):
    def test_rec_pill_is_present_over_the_game(self) -> None:
        self.assertIn('objectName: "desktopStreamRecordingPill"', SCREEN)
        # Findable while the stream is live, not only mid-take.
        self.assertIn("visible: root.streaming && AppController.overlay === \"\"", SCREEN)
        self.assertIn("readonly property bool takeActive: ShellStore.streamRecordingActive", SCREEN)
        self.assertIn('takeActive ? qsTr("Stop recording") : qsTr("Start recording")', SCREEN)
        self.assertIn("onClicked: ShellStore.toggleStreamRecording()", SCREEN)
        self.assertIn("ShellStore.streamRecordingElapsedMs", SCREEN)
        # The pill must never steal input focus from the game surface.
        self.assertIn("focusPolicy: Qt.NoFocus", SCREEN)
        # HDR chrome and native-window occlusion treat it like the other pills.
        self.assertIn("nativeOcclusion(recordingPill)", SCREEN)
        pill = SCREEN.split('objectName: "desktopStreamRecordingPill"', 1)[1]
        self.assertIn("layer.effect: HdrChromeEffect {}", pill)
        self.assertIn("Accessible.role: Accessible.Button", pill)

    def test_media_notice_surfaces_store_messages_while_streaming(self) -> None:
        self.assertIn('objectName: "desktopStreamMediaNotice"', SCREEN)
        self.assertIn("function onMediaMessageChanged()", SCREEN)
        self.assertIn("ShellStore.mediaMessage", SCREEN)
        notice = SCREEN.split('objectName: "desktopStreamMediaNotice"', 1)[1]
        self.assertIn("interval: 4000", notice)
        self.assertIn("Accessible.role: Accessible.AlertMessage", notice)

    def test_menu_still_offers_the_recording_row(self) -> None:
        self.assertIn('item("recording", "toggle-recording",', MENU)
        self.assertIn('root.shortcut("shortcutToggleRecording", "F12")', MENU)


if __name__ == "__main__":
    unittest.main()
