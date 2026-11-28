"""The stream must present at the display cadence, not at frame-arrival cadence.

Rendering only when a decoded frame arrived made network and GUI-thread jitter
visible as judder, and coalesced bursty arrivals into a single update so the
frames in between were dropped. The window now keeps rendering at vsync while
decoded frames are being presented; these pins keep that wiring in place.
"""

import unittest
from pathlib import Path

QT_ROOT = Path(__file__).resolve().parents[1]
ITEM = (QT_ROOT / "src" / "streaming" / "StreamVideoItem.cpp").read_text(encoding="utf-8")
CALLBACK = (QT_ROOT / "src" / "streaming" / "rendering" / "NativeStreamRenderCallback.cpp").read_text(encoding="utf-8")
INTERFACE = (QT_ROOT / "src" / "streaming" / "rendering" / "StreamVideoRenderCallback.h").read_text(encoding="utf-8")


class StreamPresentLoopTest(unittest.TestCase):
    def test_frame_swapped_keeps_the_loop_running_while_presenting(self) -> None:
        loop = ITEM[ITEM.index("m_frameUpdateConnection = connect("):]
        loop = loop[: loop.index("Qt::QueuedConnection)")]
        self.assertIn("presentationLoopActive()", loop)
        self.assertIn("needsFrame()", loop)
        self.assertIn("isVisible()", loop)

    def test_arrival_still_kicks_the_first_frame(self) -> None:
        self.assertIn("connect(s_nativeRuntime, &NativeStreamRuntime::frameAvailable,\n                this, &StreamVideoItem::requestFrame);", ITEM)

    def test_unminimizing_rearms_the_loop(self) -> None:
        gate = ITEM[ITEM.index("void StreamVideoItem::pushSwapGate()"):]
        gate = gate[: gate.index("\n}\n")]
        self.assertIn("m_swapGateSource.isEmpty()", gate)
        self.assertIn("update();", gate)

    def test_native_callback_gates_the_loop_on_presentation(self) -> None:
        override = CALLBACK[CALLBACK.index("bool presentationLoopActive() const override"):]
        override = override[: override.index("\n    }")]
        self.assertIn("m_graphicsReady", override)
        self.assertIn("presentationAllowed()", override)
        self.assertIn("presentationGeneration()", override)

    def test_interface_defaults_to_no_loop(self) -> None:
        self.assertIn("virtual bool presentationLoopActive() const { return false; }", INTERFACE)


if __name__ == "__main__":
    unittest.main()
