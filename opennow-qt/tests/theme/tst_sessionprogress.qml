import QtQuick
import QtTest
import OpenNOW

TestCase {
    name: "SessionSetupProgress"
    when: windowShown
    width: 1000
    height: 700

    SessionSetupProgress {
        id: progress
        session: null
    }

    DesktopSessionStarting {
        id: screen
        anchors.fill: parent
    }

    function init() {
        ShellStore.activeSession = {}
        ShellStore.streamer = {}
        ShellStore.streamState = "preparing"
        ShellStore.streamerRestartAttempts = 0
        ShellStore.sessionReconnectAttempts = 0
        ShellStore.streamMessage = ""
        AppController.route = "inserting"
        AppController.overlay = ""
    }

    function cleanup() {
        ShellStore.activeSession = {queuePosition: 21}
        ShellStore.streamer = {}
        ShellStore.streamState = "preparing"
        AppController.route = "inserting"
    }

    function test_setupSteps_data() {
        return [
            {tag: "missing", session: {}, title: "Preparing your game"},
            {tag: "null", session: {seatSetupStep: null}, title: "Preparing your game"},
            {tag: "unknown", session: {seatSetupStep: 72}, title: "Preparing your game"},
            {tag: "negative", session: {seatSetupStep: -1}, title: "Preparing your game"},
            {tag: "invalid", session: {seatSetupStep: "5"}, title: "Preparing your game"},
            {tag: "fraction", session: {seatSetupStep: 2.5}, title: "Preparing your game"},
            {tag: "connecting", session: {seatSetupStep: 0}, title: "Connecting to GeForce NOW"},
            {tag: "queue-without-position", session: {seatSetupStep: 1}, title: "Waiting for an available rig"},
            {tag: "queue", session: {seatSetupStep: 1, queuePosition: 21}, title: "Queue position 21"},
            {tag: "position-only", session: {queuePosition: 3}, title: "Queue position 3"},
            {tag: "configuring-2", session: {seatSetupStep: 2}, title: "Configuring your cloud gaming rig"},
            {tag: "configuring-3-not-native-enum", session: {seatSetupStep: 3}, title: "Configuring your cloud gaming rig"},
            {tag: "configuring-4-not-ready", session: {seatSetupStep: 4}, title: "Configuring your cloud gaming rig"},
            {tag: "stale-front-of-queue-does-not-hide-allocation", session: {seatSetupStep: 2, queuePosition: 1}, title: "Configuring your cloud gaming rig"},
            {tag: "stale-queue-does-not-hide-connecting", session: {seatSetupStep: 0, queuePosition: 1}, title: "Connecting to GeForce NOW"},
            {tag: "cleanup", session: {seatSetupStep: 5, queuePosition: 21}, title: "Cleaning up your previous session"},
            {tag: "storage", session: {seatSetupStep: 6, queuePosition: 21}, title: "Waiting for cloud storage"}
        ]
    }

    function test_setupSteps(data) {
        progress.session = data.session
        ShellStore.activeSession = data.session
        compare(progress.title, data.title)
        compare(screen.statusText, data.title)
        compare(screen.detailText, progress.detail)
        verify(progress.detail.length > 0)
    }

    function test_queuePositionBounds() {
        for (const invalid of [-1, "bad", Infinity, NaN]) {
            progress.session = {seatSetupStep: 1, queuePosition: invalid}
            compare(progress.queuePosition, 0)
            compare(progress.title, "Waiting for an available rig")
        }
        progress.session = {queuePosition: 2.7}
        compare(progress.queuePosition, 2)
    }

    function test_staleFrontOfQueueClearsWhenRigIsAllocated() {
        ShellStore.activeSession = {sessionId: "queue-transition", seatSetupStep: 1, queuePosition: 1}
        compare(screen.queueVisible, true)
        compare(screen.queuePosition, 1)
        compare(screen.statusText, "Queue position 1")

        // CloudMatch may retain the final counter while allocation advances.
        ShellStore.activeSession = {sessionId: "queue-transition", seatSetupStep: 2, queuePosition: 1}
        compare(screen.queueVisible, false)
        compare(screen.statusText, "Configuring your cloud gaming rig")
        compare(screen.detailText, "Your rig has been allocated. GeForce NOW is configuring it for your game.")
    }

    function test_clearedQueueCounterDoesNotReuseHistoricalBest() {
        ShellStore.sessionProgressBestPosition = 1
        ShellStore.activeSession = {sessionId: "queue-cleared", seatSetupStep: 1, queuePosition: 1}
        compare(screen.queuePosition, 1)
        ShellStore.activeSession = {sessionId: "queue-cleared", seatSetupStep: 1, queuePosition: 0}
        compare(screen.queueVisible, true)
        compare(screen.queuePosition, 0)
        compare(screen.statusText, "Waiting for an available rig")
        ShellStore.sessionProgressBestPosition = 0
    }

    function test_lifecyclePrecedence() {
        ShellStore.activeSession = {seatSetupStep: 5, queuePosition: 21}
        for (const entry of [
            ["checking", "Checking session availability"],
            ["requesting", "Requesting your session"],
            ["resuming", "Reconnecting to your game"],
            ["reconnecting", "Reconnecting to your session"],
            ["failed", "Session could not start"],
            ["stopping", "Closing your session"]
        ]) {
            ShellStore.streamState = entry[0]
            compare(screen.statusText, entry[1])
        }
    }

    function test_nativeConnectionProgress() {
        AppController.route = "stream"
        ShellStore.activeSession = {seatSetupStep: 5}
        ShellStore.streamer = {status: "starting"}
        compare(screen.statusText, "Connecting to your game")
        compare(screen.detailText, "Initializing the native streaming connection.")
        ShellStore.streamer = {status: "streaming"}
        compare(screen.detailText, "Connected. Waiting for the first video frame.")
        ShellStore.streamer = {status: "error", message: "Connection failed"}
        compare(screen.statusText, "Session could not start")
        compare(screen.detailText, "Connection failed")
    }

    function test_progressCanMoveBackward() {
        for (const step of [1, 2, 5, 0, 6, 1]) {
            ShellStore.activeSession = {seatSetupStep: step}
            progress.session = ShellStore.activeSession
            compare(screen.statusText, progress.title)
        }
        ShellStore.activeSession = null
        compare(screen.statusText, "Preparing your game")
    }
}
