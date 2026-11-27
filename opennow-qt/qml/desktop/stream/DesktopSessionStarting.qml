pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopSessionStarting"
    width: 1440
    height: 900
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Starting session")

    signal cancelRequested()
    signal retryRequested()

    readonly property var game: ShellStore.selectedGame || ({})
    readonly property var session: ShellStore.activeSession || ({})
    readonly property var streamer: ShellStore.streamer || ({})
    readonly property bool connecting: AppController.route === "stream"
    readonly property string phase: String(ShellStore.streamState || "preparing")
    readonly property bool stopping: phase === "stopping"
    readonly property bool failed: !stopping && (phase === "failed" || phase === "error"
        || (connecting && (streamer.status === "error" || streamer.status === "stopped")))
    readonly property bool reconnecting: phase === "reconnecting"
        || ShellStore.streamerRestartAttempts > 0 || ShellStore.sessionReconnectAttempts > 0
    SessionSetupProgress {
        id: setupProgress
        session: root.session
    }
    readonly property bool queueVisible: !stopping && !failed && !reconnecting && !connecting
        && setupProgress.queued
    readonly property int queuePosition: setupProgress.queuePosition
    property double queueClockMs: Date.now()
    readonly property int queueStallSeconds: ShellStore.sessionProgressGainedAtMs > 0
        ? Math.max(0, Math.floor((root.queueClockMs - ShellStore.sessionProgressGainedAtMs) / 1000)) : 0
    readonly property int queueContactSeconds: ShellStore.sessionProgressChangedAtMs > 0
        ? Math.max(0, Math.floor((root.queueClockMs - ShellStore.sessionProgressChangedAtMs) / 1000)) : 0
    readonly property bool queueContactActive: queueContactSeconds < 30
    readonly property bool queueStalled: queueVisible && queueStallSeconds >= 180
    readonly property string queueActivityText: {
        if (queueContactSeconds >= 30)
            return qsTr("No queue status update for %1s").arg(queueContactSeconds)
        if (queueStallSeconds < 10) return qsTr("GeForce NOW queue updates are active")
        if (queueStallSeconds < 60)
            return qsTr("Position unchanged for %1s · updates active").arg(queueStallSeconds)
        return qsTr("No position change for %1 min · updates active").arg(Math.max(1, Math.floor(queueStallSeconds / 60)))
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.queueVisible
        onTriggered: root.queueClockMs = Date.now()
    }
    readonly property string statusText: {
        if (stopping) return qsTr("Closing your session")
        if (failed) return ShellStore.launchConflictDetected
            ? qsTr("Your game is still running") : qsTr("Session could not start")
        if (reconnecting) return qsTr("Reconnecting to your session")
        if (connecting) return qsTr("Connecting to your game")
        if (setupProgress.queued) return setupProgress.title
        if (phase === "checking") return qsTr("Checking session availability")
        if (phase === "requesting") return qsTr("Requesting your session")
        if (phase === "resuming") return qsTr("Reconnecting to your game")
        return setupProgress.title
    }
    readonly property string detailText: {
        if (stopping) return qsTr("Waiting for your session to close.")
        if (failed) return String((connecting && streamer.message) || ShellStore.streamMessage
            || qsTr("Please try again or return to your library."))
        if (reconnecting) return qsTr("Your stream will return when the connection is restored.")
        if (phase === "resuming" || phase === "checking" || phase === "conflict")
            return ShellStore.streamMessage
        if (connecting) {
            if (streamer.status === "starting") return qsTr("Initializing the native streaming connection.")
            if (streamer.status === "streaming") return qsTr("Connected. Waiting for the first video frame.")
            return qsTr("Your game will appear here as soon as the video is ready.")
        }
        if (root.queueStalled)
            return root.queueContactActive
                ? qsTr("GeForce NOW is still updating your session, but your position has not improved. You can keep waiting, or leave this queue and request a fresh rig.")
                : qsTr("OpenNOW has not received a fresh queue status. You can refresh, keep waiting, or leave this queue and request a fresh rig.")
        return setupProgress.detail
    }

    function restoreFocus() {
        if (root.visible && root.enabled
                && !ShellStore.streamOverlayBlocksGameplayInput(AppController.overlay)) {
            if (root.queueVisible)
                queueExperience.restoreFocus()
            else
                cancelButton.forceActiveFocus()
        }
    }

    ArtworkSource {
        id: artwork
        sourceUrl: DesktopTokens.decodeArtworkUrl(String(root.game.heroImageUrl || root.game.imageUrl || ""))
        active: root.visible
    }

    Rectangle { anchors.fill: parent; color: DesktopTokens.shell }
    Image {
        anchors.fill: parent
        source: artwork.resolvedUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(1440, 900)
        asynchronous: true
        cache: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: DesktopTokens.revealDuration; easing.type: Easing.OutCubic } }
    }
    // Theme-aware wash, the same chrome tint the home rail and top bar lay
    // over their art, instead of a fixed dark veil.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b,
            Theme.lightMode ? 0.82 : 0.78)
    }

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 32
        z: 2
        spacing: 10
        DesktopBrandLockup {
            anchors.verticalCenter: parent.verticalCenter
            markHeight: 12
            fontPixelSize: 16
            spacing: 10
            ink: DesktopTokens.textHigh
        }
    }

    DesktopQueueExperience {
        id: queueExperience
        anchors.fill: parent
        visible: root.queueVisible
        game: root.game
        session: root.session
        queuePosition: root.queuePosition
        statusText: root.statusText
        detailText: root.detailText
        activityText: root.queueActivityText
        queueStalled: root.queueStalled
        requeueAvailable: ShellStore.pendingLaunchParams !== null
        requeueInProgress: ShellStore.requeueRequested === true
        streamBusy: ShellStore.streamBusy
        onCancelRequested: root.cancelRequested()
        onRefreshRequested: ShellStore.reconnectSessionProgress()
        onRequeueRequested: ShellStore.requeueSession()
    }

    Rectangle {
        anchors.centerIn: parent
        visible: !root.queueVisible
        width: launchColumn.width + 64
        height: launchColumn.height + 56
        radius: 24
        color: Theme.lightMode ? "#F2F5FA" : "#E60B1320"
        border.width: 1
        border.color: DesktopTokens.seam

    Column {
        id: launchColumn
        x: 32
        y: 28
        width: Math.min(560, root.width - 128)
        spacing: 0

        Text {
            text: root.stopping ? qsTr("ENDING SESSION")
                : root.failed ? qsTr("SESSION INTERRUPTED") : qsTr("STARTING SESSION")
            color: root.failed ? DesktopTokens.flightDeclined
                : (Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.mint)
            font.family: DesktopTokens.monoFont
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 1.8
        }
        Text {
            width: parent.width
            topPadding: 10
            text: String(root.game.title || qsTr("GeForce NOW"))
            color: DesktopTokens.textHigh
            font.family: DesktopTokens.displayFont
            font.pixelSize: root.width < 800 ? 34 : 44
            font.weight: Font.Black
            font.letterSpacing: -1.2
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
        }
        Item { width: 1; height: 32 }
        Row {
            width: parent.width
            spacing: 12
            Item {
                width: 20; height: 26
                visible: !root.failed
                Rectangle {
                    anchors.centerIn: parent
                    width: 18; height: 18; radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: DesktopTokens.seam
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -1
                        width: 6; height: 6; radius: 3
                        color: Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.mint
                    }
                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 1400; loops: Animation.Infinite
                        running: root.visible && !root.failed && !AppController.reducedMotion
                    }
                }
            }
            Text {
                objectName: "sessionLaunchStatus"
                width: parent.width - (root.failed ? 0 : 32)
                text: root.statusText
                color: root.failed ? DesktopTokens.flightDeclined : DesktopTokens.textHigh
                font.family: DesktopTokens.bodyFont
                font.pixelSize: 19
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
        }
        Text {
            width: parent.width
            topPadding: 10
            text: root.detailText
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: 14
            lineHeight: 1.4
            wrapMode: Text.WordWrap
            maximumLineCount: 5
            elide: Text.ElideRight
        }
        Item { width: 1; height: 32 }
        Flow {
            width: parent.width
            spacing: 12
            DesktopButton {
                visible: root.failed && (root.connecting || ShellStore.activeSession !== null
                    || ShellStore.pendingLaunchParams !== null || ShellStore.conflictSession !== null)
                enabled: !ShellStore.streamBusy
                text: root.connecting ? qsTr("Retry connection") : qsTr("Try again")
                primary: true
                onClicked: root.retryRequested()
            }
            DesktopButton {
                id: cancelButton
                enabled: !root.stopping
                text: root.failed && !ShellStore.activeSession ? qsTr("Back") : qsTr("Cancel session")
                shortcutText: qsTr("Esc")
                onClicked: root.cancelRequested()
            }
        }
    }
    }

    onVisibleChanged: if (visible) Qt.callLater(root.restoreFocus)
    onEnabledChanged: if (enabled) Qt.callLater(root.restoreFocus)
    Connections {
        target: AppController
        function onOverlayChanged() { Qt.callLater(root.restoreFocus) }
    }
    Keys.onPressed: event => {
        if (event.isAutoRepeat || root.stopping)
            return
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            root.cancelRequested()
            event.accepted = true
        }
    }
}
