import QtQuick
import OpenNOW

FocusScope {
    id: root
    objectName: "consoleLaunchScreen"
    readonly property var game: ShellStore.selectedGame
        || ({ title: ShellStore.pendingLaunchParams && ShellStore.pendingLaunchParams.title || qsTr("GeForce NOW") })
    readonly property var session: ShellStore.activeSession
    readonly property var progress: ShellStore.sessionSetupProgress
    readonly property string phase: ShellStore.streamState
    readonly property bool failed: phase === "error" || phase === "failed"
    readonly property bool stopping: phase === "stopping"
    readonly property bool resuming: phase === "resuming" || Boolean(session && session.resumePending)
    readonly property bool queued: Boolean(session) && progress.queued
    readonly property int setupStep: session ? progress.setupStep : -1
    readonly property bool preparingStorage: setupStep === 5 || setupStep === 6
    readonly property int step: !session || resuming ? 1
        : queued || preparingStorage ? 2
        : setupStep >= 2 && setupStep <= 4 ? 3 : 1
    property int reachedStep: 1
    readonly property bool canRetry: phase === "error" && (ShellStore.pendingLaunchParams !== null
        || ShellStore.activeSession !== null || ShellStore.conflictSession !== null)
    readonly property bool leavesWithoutConfirmation: (phase === "error" || phase === "checking")
        && !session && ShellStore.streamCreateRequestId === "" && ShellStore.sessionClaimRequestId === ""
        && ShellStore.streamStopRequestId === ""
    readonly property double appearedAtMs: Date.now()
    // A queue that stops moving is the difference between "still waiting" and
    // "stuck". GeForce NOW reports a position that jitters between polls, so
    // only a new best position counts as movement.
    property double clockMs: Date.now()
    readonly property int queueStallSeconds: ShellStore.sessionProgressGainedAtMs > 0
        ? Math.max(0, Math.floor((root.clockMs - ShellStore.sessionProgressGainedAtMs) / 1000)) : 0
    readonly property int queueContactSeconds: ShellStore.sessionProgressChangedAtMs > 0
        ? Math.max(0, Math.floor((root.clockMs - ShellStore.sessionProgressChangedAtMs) / 1000)) : 0
    readonly property bool queueContactActive: root.queueContactSeconds < 30
    readonly property bool queueStalled: root.queued && !root.stopping && root.queueStallSeconds >= 180
    // Show the latest server snapshot, not a historical best. In particular,
    // clearing position 1 must be allowed to leave the queue presentation.
    readonly property int queuePositionShown: root.progress.queuePosition
    readonly property string queueActivityText: {
        if (root.queueContactSeconds >= 30)
            return qsTr("No queue status update for %1s").arg(root.queueContactSeconds)
        if (root.queueStallSeconds < 10)
            return qsTr("GeForce NOW queue updates are active")
        if (root.queueStallSeconds < 60)
            return qsTr("Position unchanged for %1s · updates active").arg(root.queueStallSeconds)
        return qsTr("No position change for %1 min · updates active").arg(Math.max(1, Math.floor(root.queueStallSeconds / 60)))
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.queued && !root.failed
        onTriggered: root.clockMs = Date.now()
    }
    readonly property var rigRows: {
        const rows = []
        const current = session || ({})
        if (current.gpuType) rows.push({label: qsTr("GPU"), value: String(current.gpuType)})
        if (current.serverLocation || current.zone) rows.push({label: qsTr("Zone"), value: String(current.serverLocation || current.zone)})
        const settings = ShellStore.settings || ({})
        const requested = [settings.resolution ? String(settings.resolution) : "",
            settings.fps ? qsTr("%1 FPS").arg(settings.fps) : ""].filter(part => part !== "").join(" · ")
        if (requested !== "") rows.push({label: qsTr("Requested"), value: requested})
        return rows
    }

    onStepChanged: if (!failed) reachedStep = step
    Component.onCompleted: {
        reachedStep = step
        if (failed)
            Qt.callLater(focusDefault)
        else
            forceActiveFocus()
    }
    onFailedChanged: Qt.callLater(focusDefault)

    function focusDefault() {
        if (!root.failed)
            root.forceActiveFocus()
        else if (retryButton.visible && retryButton.enabled)
            retryButton.forceActiveFocus()
        else
            backButton.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (event.isAutoRepeat)
            return
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            event.accepted = true
            if (!root.stopping)
                ShellStore.requestStreamExitConfirmation()
        }
    }

    SessionGlyphs { id: glyphs }

    LaunchStage {
        id: stage
        anchors.fill: parent
        game: root.game
        tone: root.failed ? Theme.coral : root.stopping ? Theme.textMuted : root.queued || root.preparingStorage ? Theme.yellow : Theme.focus
        statusText: root.failed ? qsTr("Stopped")
            : root.stopping ? qsTr("Closing")
            : root.resuming ? qsTr("Reconnecting")
            : root.queued ? qsTr("In queue")
            : root.setupStep === 5 ? qsTr("Cleaning up")
            : root.setupStep === 6 ? qsTr("Waiting for storage")
            : root.step === 3 ? qsTr("Setting up")
            : qsTr("Starting")
        eyebrow: root.failed ? qsTr("Session could not start")
            : root.stopping ? qsTr("Ending a session")
            : root.resuming ? qsTr("Your game is still running")
            : qsTr("Starting your session")
        headline: root.failed ? qsTr("That didn't work")
            : root.stopping ? (ShellStore.conflictSession ? qsTr("Closing your other game") : qsTr("Closing your session"))
            : root.resuming ? qsTr("Returning to your game")
            : root.queued ? (root.progress.queuePosition > 0 ? qsTr("You're in line") : qsTr("Waiting for an available rig"))
            : root.session ? root.progress.title
            : root.phase === "requesting" ? qsTr("Requesting a rig")
            : qsTr("Checking for running games")
        detail: root.failed || root.stopping || root.resuming || !root.session
            ? I18n.source(ShellStore.streamMessage, I18n.revision)
            : root.queueStalled ? (root.queueContactActive
                ? qsTr("GeForce NOW is still updating your session, but your position has not improved. You can keep waiting, or leave this queue and request a fresh rig.")
                : qsTr("OpenNOW has not received a fresh queue status. You can refresh, keep waiting, or leave this queue and request a fresh rig."))
            : root.queued ? qsTr("Waiting for an available rig. Your session starts by itself, so you can put the controller down.")
            : root.progress.detail
        railVisible: !root.failed && !root.stopping
        activeStep: root.step
        activeStepDetail: root.queued ? qsTr("Position comes from GeForce NOW")
            : root.preparingStorage ? root.progress.title : ""
        waitStartedMs: root.failed || root.stopping ? 0 : root.appearedAtMs
        footerVisible: !root.failed && !root.stopping
        footerText: root.leavesWithoutConfirmation ? qsTr("Cancel")
            : root.queued ? qsTr("Leave queue…") : qsTr("Cancel session…")
        copyWidth: root.failed ? 860 : 1060
        detailWidth: root.failed ? 780 : 880
        onFooterRequested: ShellStore.requestStreamExitConfirmation()

        actions: [
            LaunchStage.LaunchAction {
                id: retryButton
                objectName: "launchRetryButton"
                visible: root.canRetry
                enabled: !ShellStore.streamBusy
                primary: true
                text: qsTr("Try again")
                detail: qsTr("Same game, same settings")
                glyph: glyphs.button("A")
                keyboardGlyph: glyphs.keyboard
                KeyNavigation.down: backButton
                onClicked: ShellStore.retrySessionLaunch()
            },
            LaunchStage.LaunchAction {
                id: requeueButton
                objectName: "launchRequeueButton"
                visible: !root.failed && root.queueStalled && ShellStore.pendingLaunchParams !== null
                enabled: !ShellStore.streamBusy && !ShellStore.requeueRequested
                text: qsTr("Request a fresh rig")
                detail: qsTr("Leaves this queue, then queues again")
                glyph: glyphs.button("Y")
                keyboardGlyph: glyphs.keyboard
                KeyNavigation.down: backButton
                onClicked: ShellStore.requeueSession()
            },
            LaunchStage.LaunchAction {
                id: backButton
                objectName: "launchBackButton"
                visible: root.failed
                text: root.session ? qsTr("End session…") : qsTr("Back to %1").arg(String(root.game.title || qsTr("GeForce NOW")))
                glyph: glyphs.button("B")
                keyboardGlyph: glyphs.keyboard
                KeyNavigation.up: retryButton
                onClicked: ShellStore.requestStreamExitConfirmation()
            }
        ]

        aside: [
            Item {
                anchors.fill: parent
                visible: !root.failed && root.queued && root.progress.queuePosition > 0
                Rectangle {
                    objectName: "launchQueueRing"
                    x: parent.width - width - 40
                    y: 36
                    width: 520; height: 520; radius: 260
                    color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.42)
                    border.width: 2
                    border.color: Theme.seam
                    Accessible.role: Accessible.StaticText
                    Accessible.name: qsTr("Queue position %1").arg(root.queuePositionShown)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.baseline: parent.top
                        anchors.baselineOffset: 145
                        text: qsTr("Queue position").toUpperCase()
                        color: Theme.label
                        font.family: Theme.monoFont; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 2.56
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.baseline: parent.top
                        anchors.baselineOffset: 323.8
                        text: String(root.queuePositionShown)
                        color: Theme.yellow
                        font.family: Theme.displayFont; font.pixelSize: root.queuePositionShown > 9999 ? 120 : 200
                        font.weight: Font.Black; font.letterSpacing: root.queuePositionShown > 9999 ? -4.8 : -8
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.baseline: parent.top
                        anchors.baselineOffset: 385.3
                        text: root.queueActivityText
                        color: Theme.textMuted
                        font.family: Theme.bodyFont; font.pixelSize: 19; font.weight: Font.Bold
                    }
                }
            },
            LaunchStage.RigCard {
                x: parent.width - width - 40
                y: 86
                visible: !root.failed && root.step === 3 && rows.length > 0
                rows: root.rigRows
            },
            LaunchStage.StopCard {
                x: parent.width - width - 40
                visible: root.failed
                reachedStep: root.reachedStep
            }
        ]
    }
}
