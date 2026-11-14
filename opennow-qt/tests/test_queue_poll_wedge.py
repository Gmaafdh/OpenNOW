"""Pins the guard order that keeps a finished stop from freezing the queue.

The recurring "queue stuck" wedge: stopStreamingSession parks
sessionStopIntentId on the seat, pollStreamingSession returns early while that
intent matches, and the watchdog used to clear the intent only *after* its
running-timer guard - which a parked poll chain keeps alive every tick, so the
clear was unreachable and the queue screen sat on a stale position forever.
These pins keep the stale-intent clear in front of every guard it unblocks.
"""

from pathlib import Path
import unittest

QT_ROOT = Path(__file__).resolve().parents[1]
STORE = (QT_ROOT / "qml" / "state" / "ShellStore.qml").read_text(encoding="utf-8")


class QueuePollWedgeContracts(unittest.TestCase):
    def test_stale_stop_intent_has_a_single_bounded_clear(self) -> None:
        self.assertIn("function clearStaleSessionStopIntent()", STORE)
        # Only a finished stop may be dropped: anything in flight keeps it.
        self.assertIn(
            "if (coreSessionRestoreId !== \"\" || streamStopRequestId !== \"\" "
            "|| pendingSessionEnd !== null)",
            STORE,
        )
        # A live seat keeps the explicit stop intent until its stop lands.
        self.assertIn(
            "if (streamState === \"stopping\" || streamState === \"ready\" "
            "|| streamState === \"streaming\")",
            STORE,
        )

    def test_watchdog_clears_before_its_running_timer_guard(self) -> None:
        watchdog = STORE.split("function ensureSessionProgressPolling()", 1)[1]
        watchdog = watchdog.split("function pollStreamingSession()", 1)[0]
        clear_at = watchdog.index("clearStaleSessionStopIntent()")
        timer_guard = watchdog.index(
            "if (streamPollTimer.running || streamPollRequestId !== \"\" "
            "|| streamStopRequestId !== \"\")"
        )
        self.assertLess(
            clear_at,
            timer_guard,
            "a parked poll chain keeps the timer alive, so the stale-intent "
            "clear must run before the running-timer guard",
        )

    def test_poll_tick_drops_the_parked_intent_before_returning(self) -> None:
        poll = STORE.split("function pollStreamingSession()", 1)[1]
        poll = poll.split("function handleStreamPollFailure(", 1)[0]
        self.assertIn(
            "clearStaleSessionStopIntent()\n"
            "        if (sessionStopIntentId === String(activeSession.sessionId) "
            "&& coreSessionRestoreId === \"\")\n            return",
            poll,
        )

    def test_recovery_paths_clear_the_finished_stop_first(self) -> None:
        recover = STORE.split("function recoverStreamingSession(reason)", 1)[1]
        self.assertTrue(
            recover.split("{", 1)[1].strip().startswith("clearStaleSessionStopIntent()")
        )
        schedule = STORE.split("function scheduleSessionRecovery(reason)", 1)[1]
        guard_at = schedule.index(
            "if (!activeSession || streamStopRequestId !== \"\"\n"
            "                || sessionStopIntentId === String(activeSession.sessionId)) return"
        )
        self.assertLess(schedule.index("clearStaleSessionStopIntent()"), guard_at)


if __name__ == "__main__":
    unittest.main()
