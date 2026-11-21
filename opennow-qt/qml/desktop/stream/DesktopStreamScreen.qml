import QtQuick
import QtQuick.Controls
import OpenNOW

FocusScope {
    id: root
    readonly property bool streamPointerLocked: streamVideo.relativeMouse
        && (streamVideo.captureActive || NativeStreamRuntime.usesExternalWindow)
    focus: true
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Live session")

    signal stopRequested()
    property bool launchCovered: false

    Rectangle { anchors.fill: parent; color: "black"; z: -1 }

    readonly property var session: ShellStore.activeSession || ({})
    readonly property string sessionId: String(session.sessionId || "")
    property string clipboardPasteMessage: ""
    onSessionIdChanged: {
        clipboardPasteMessage = ""
        if (clipboardPasteNotice) clipboardPasteNotice.stop()
    }
    readonly property var profile: session.negotiatedStreamProfile || session.streamProfile || ({})
    readonly property var streamer: ShellStore.streamer || ({})
    readonly property string status: {
        if (ShellStore.streamState === "error")
            return "error"
        if (ShellStore.streamState === "reconnecting"
                || (ShellStore.streamerRestartAttempts > 0 && root.streamer.status !== "streaming"))
            return "reconnecting"
        return String(root.streamer.status || ShellStore.streamState || "starting")
    }
    readonly property bool streaming: root.status === "streaming"
    readonly property bool videoSurfaceActive: root.streaming || (root.streamer.status === "connecting" && root.status !== "error")
    readonly property bool videoReady: streaming
        && root.streamer.firstFrameLatencyMs !== undefined
        && root.streamer.firstFrameLatencyMs !== null
    property var frameGenerationStats: streamVideo.frameGenerationStats || ({})
    property var swapStats: streamVideo.swapStats || ({})
    property bool nativeSurfaceAttached: false
    property string publishedNativeSurfaceKey: ""
    property string nativeSurfaceFocusedOverlay: ""
    readonly property var localNativeOcclusions: [
        nativeOcclusion(antiAfkIndicator), nativeOcclusion(sessionClockIndicator),
        nativeOcclusion(recordingPill),
        nativeOcclusion(idleWarning), nativeOcclusion(inputNotice),
        nativeOcclusion(captureStatus)
    ].filter(rect => rect !== null)
    property double clockNowMs: Date.now()
    readonly property int clockSeconds: ShellStore.streamStartedAtMs > 0
        ? Math.max(0, Math.floor((clockNowMs - ShellStore.streamStartedAtMs) / 1000)) : 0
    Timer {
        interval: 1000; repeat: true
        running: root.visible && root.streaming
            && (ShellStore.settings.sessionCounterEnabled === true || ShellStore.antiAfkEnabled)
        onTriggered: root.clockNowMs = Date.now()
    }
    MotionProgress {
        id: antiAfkReveal
        shown: root.videoReady && ShellStore.antiAfkIndicatorShown(root.clockSeconds)
            && AppController.overlay.indexOf("stats") < 0
    }
    Rectangle {
        id: antiAfkIndicator
        objectName: "desktopAntiAfkIndicator"
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 24
        layer.enabled: HdrOutput.chromeRequired
        layer.effect: HdrChromeEffect {}
        width: antiAfkLabel.implicitWidth + 28; height: 36; radius: 18; z: 4
        color: Qt.rgba(Theme.shell.r,Theme.shell.g,Theme.shell.b,0.85)
        visible: antiAfkReveal.present
        opacity: antiAfkReveal.progress
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("Anti-AFK is enabled")
        Row {
            id: antiAfkLabel; anchors.centerIn: parent; spacing: 8
            Rectangle { width: 8; height: 8; radius: 4; color: DesktopTokens.green; anchors.verticalCenter: parent.verticalCenter }
            Text { text: qsTr("ANTI-AFK ON"); color: Theme.label; font.family: Theme.monoFont; font.pixelSize: 12 }
        }
    }
    Rectangle {
        id: sessionClockIndicator
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24
        layer.enabled: HdrOutput.chromeRequired
        layer.effect: HdrChromeEffect {}
        width: sessionClock.implicitWidth + 24; height: 36; radius: 18; z: 4
        color: Qt.rgba(Theme.shell.r,Theme.shell.g,Theme.shell.b,0.85)
        visible: root.streaming && ShellStore.settings.sessionCounterEnabled === true
            && AppController.overlay.indexOf("stats") < 0
        Text {
            id: sessionClock; anchors.centerIn: parent
            text: Math.floor(root.clockSeconds / 3600) + ":" + String(Math.floor(root.clockSeconds / 60) % 60).padStart(2,"0") + ":" + String(root.clockSeconds % 60).padStart(2,"0")
            color: Theme.label; font.family: Theme.monoFont; font.pixelSize: 12
        }
    }
    // Video recording keeps its own chrome on the in-game screen: a pulsing
    // take indicator with the elapsed time, and one click stops and saves the
    // recording. Until now recording lived only in the Ctrl+K menu, the guide
    // and the F12 shortcut, so a live take had no presence over the game.
    AbstractButton {
        id: recordingPill
        objectName: "desktopStreamRecordingPill"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: 24
        layer.enabled: HdrOutput.chromeRequired
        layer.effect: HdrChromeEffect {}
        width: recordingTakeLabel.implicitWidth + 28; height: 36; radius: 18; z: 4
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        // Idle while the stream is live so the feature is findable over the
        // game, coral and counting while a take is running.
        visible: root.streaming && AppController.overlay === ""
        opacity: takeActive || hovered ? 1 : 0.8
        Behavior on opacity { NumberAnimation { duration: DesktopTokens.quickDuration } }
        Accessible.role: Accessible.Button
        Accessible.name: takeActive ? qsTr("Stop recording") : qsTr("Start recording")
        Accessible.description: takeActive
            ? qsTr("Stops the take and saves it to your media library")
            : qsTr("Records the stream in source quality")
        ToolTip.visible: hovered
        ToolTip.text: takeActive
            ? qsTr("Stop and save the recording")
            : qsTr("Records the stream in source quality")
        ToolTip.delay: 400
        onClicked: ShellStore.toggleStreamRecording()
        readonly property bool takeActive: ShellStore.streamRecordingActive
        readonly property int takeSeconds: Math.floor(ShellStore.streamRecordingElapsedMs / 1000)
        readonly property string takeClock: String(Math.floor(takeSeconds / 60)).padStart(2, "0")
            + ":" + String(takeSeconds % 60).padStart(2, "0")
        background: Rectangle {
            radius: 18
            color: recordingPill.hovered
                ? Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.95)
                : Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.85)
            border.width: 1
            border.color: recordingPill.takeActive
                ? Qt.rgba(Theme.coral.r, Theme.coral.g, Theme.coral.b, 0.55)
                : Qt.rgba(1, 1, 1, 0.14)
            Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
        }
        Row {
            id: recordingTakeLabel; anchors.centerIn: parent; spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: recordingPill.takeActive ? Theme.coral : Theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: recordingPill.takeActive && recordingPill.visible
                        && !AppController.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }
            Text {
                text: qsTr("REC") + (recordingPill.takeActive ? " " + recordingPill.takeClock : "")
                color: Theme.label; font.family: Theme.monoFont; font.pixelSize: 12
            }
        }
    }
    function nativeOcclusion(item) {
        if (!item || !item.visible || item.width <= 0 || item.height <= 0
                || !Number.isFinite(item.x) || !Number.isFinite(item.y))
            return null
        const rect = item.mapToItem(null, 0, 0, item.width, item.height)
        return Qt.rect(rect.x, rect.y, rect.width, rect.height)
    }
    function publishCaptureRect() {
        const window = root.Window.window
        if (!window)
            return
        const rect = root.mapToItem(null, 0, 0, root.width, root.height)
        ShellStore.streamCaptureRect = Qt.rect(
            Math.round(window.x + rect.x), Math.round(window.y + rect.y),
            Math.round(rect.width), Math.round(rect.height))
    }
    function publishNativeSurface() {
        if (NativeStreamRuntime.usesHostedSurface !== true || !NativeStreamRuntime.running)
            return
        const overlay = String(AppController.overlay || "")
        const blockingOverlay = ShellStore.streamOverlayBlocksGameplayInput(overlay)
        const show = root.visible && root.videoReady && !root.launchCovered
            && (!blockingOverlay || ShellStore.streamOverlayPreservesNativeSurface(overlay))
        if (ShellStore.streamerStopExpected || root.status === "stopped") {
            nativeSurfaceAttached = false
            publishedNativeSurfaceKey = ""
            nativeSurfaceFocusedOverlay = ""
            return
        }
        if (!show && !nativeSurfaceAttached)
            return
        const shared = ShellStore.nativeSurfaceOcclusions || []
        const descriptor = streamVideo.nativeSurfaceDescriptor(show,
            show ? localNativeOcclusions.concat(shared) : [], show && blockingOverlay)
        const key = JSON.stringify(descriptor)
        if (key === publishedNativeSurfaceKey)
            return
        if (blockingOverlay && root.visible && nativeSurfaceAttached
                && nativeSurfaceFocusedOverlay !== overlay) {
            NativeStreamRuntime.focusHostedOverlay(root.Window.window)
            nativeSurfaceFocusedOverlay = overlay
        }
        if (!blockingOverlay)
            nativeSurfaceFocusedOverlay = ""
        const requestId = ShellStore.updateNativeSurface(descriptor)
        if (requestId === "")
            return
        publishedNativeSurfaceKey = key
        nativeSurfaceAttached = descriptor.visible === true
        if (descriptor.visible === true && AppController.overlay === "")
            ShellStore.focusNativeSurface()
    }
    function resynchronizeStreamInput() {
        root.publishCaptureRect()
        root.publishNativeSurface()
        if (!root.visible || !root.streaming || root.launchCovered
                || NativeStreamRuntime.usesExternalWindow
                || ShellStore.streamOverlayBlocksGameplayInput(AppController.overlay))
            return
        streamVideo.forceActiveFocus()
        streamVideo.resynchronizeInput()
    }

    onXChanged: { publishCaptureRect(); Qt.callLater(publishNativeSurface) }
    onYChanged: { publishCaptureRect(); Qt.callLater(publishNativeSurface) }
    onWidthChanged: { publishCaptureRect(); Qt.callLater(publishNativeSurface) }
    onHeightChanged: { publishCaptureRect(); Qt.callLater(publishNativeSurface) }
    onVideoReadyChanged: Qt.callLater(publishNativeSurface)
    onLocalNativeOcclusionsChanged: Qt.callLater(publishNativeSurface)
    Component.onCompleted: { publishCaptureRect(); Qt.callLater(publishNativeSurface) }

    Connections {
        target: root.Window.window
        function onXChanged() { root.resynchronizeStreamInput() }
        function onYChanged() { root.resynchronizeStreamInput() }
        function onWidthChanged() { Qt.callLater(root.resynchronizeStreamInput) }
        function onHeightChanged() { Qt.callLater(root.resynchronizeStreamInput) }
        function onVisibilityChanged() { Qt.callLater(root.resynchronizeStreamInput) }
        function onActiveChanged() { Qt.callLater(root.resynchronizeStreamInput) }
        function onScreenChanged() { Qt.callLater(root.resynchronizeStreamInput) }
    }

    Connections {
        target: AppController
        function onOverlayChanged() { Qt.callLater(root.publishNativeSurface) }
    }

    Connections {
        target: NativeStreamRuntime
        function onRunningChanged() {
            if (!NativeStreamRuntime.running) {
                root.nativeSurfaceAttached = false
                root.publishedNativeSurfaceKey = ""
                root.nativeSurfaceFocusedOverlay = ""
            }
        }
    }

    StreamVideoItem {
        id: streamVideo
        objectName: "streamSurfaceHost"
        anchors.fill: parent
        visible: root.visible && root.videoSurfaceActive && !NativeStreamRuntime.usesExternalWindow
        enabled: !root.launchCovered
        focus: root.streaming && visible && !root.launchCovered
        inputEnabled: root.streaming && visible
            && !ShellStore.streamOverlayBlocksGameplayInput(AppController.overlay)
        shortcutBindings: ShellStore.streamShortcutBindings()
        clipboardPaste: ShellStore.settings.clipboardPaste === true
        keyboardLayout: String((ShellStore.activeSession || {}).keyboardLayout || "en-US")
        videoSize: Qt.size(Number(root.profile.width || 0), Number(root.profile.height || 0))
        frameGeneration: String(ShellStore.settings.frameGeneration || 'off') === '2x'
        metalFxUpscaling: Qt.platform.os === "osx" && ShellStore.settings.upscaling === "metalfx"
        fsrUpscaling: Qt.platform.os !== "osx" && ShellStore.settings.upscaling === "fsr1"
        upscalingSharpness: Number(ShellStore.settings.upscalingSharpness ?? 10)
        upscalingDenoise: Number(ShellStore.settings.upscalingDenoise ?? 0)
        z: 0
        onLocalShortcutRequested: action => ShellStore.applyStreamShortcutAction(action)
        onClipboardPasteFailed: {
            root.clipboardPasteMessage = ""
            clipboardPasteNotice.restart()
        }
    }

    Timer {
        id: clipboardPasteNotice
        objectName: "streamClipboardPasteNoticeTimer"
        interval: 5000
        onTriggered: root.clipboardPasteMessage = ""
    }

    StreamIdleWarning {
        id: idleWarning
        layer.enabled: HdrOutput.chromeRequired
        layer.effect: HdrChromeEffect {}
        z: 5
    }

    StreamInputNotice {
        id: inputNotice
        layer.enabled: HdrOutput.chromeRequired
        layer.effect: HdrChromeEffect {}
        title: clipboardPasteNotice.running ? qsTr("Text input unavailable") : qsTr("Relative mouse input unavailable")
        message: !root.streaming ? "" : clipboardPasteNotice.running
            ? root.clipboardPasteMessage || qsTr("Clipboard paste failed. Use plain text up to 64 KiB and try again.")
            : streamVideo.relativeMouse ? streamVideo.inputCaptureError : ""
        z: 3
    }

    StreamCaptureStatus {
        id: captureStatus
        layer.enabled: HdrOutput.chromeRequired
        layer.effect: HdrChromeEffect {}
        z: 4
    }
    // Media feedback over the game: screenshots and recording starts, stops
    // and failures already set ShellStore.mediaMessage, but nothing surfaced
    // it while streaming - the guide toast only exists while the guide is
    // open. This pill shows the latest media message for four seconds.
    Rectangle {
        id: mediaNotice
        objectName: "desktopStreamMediaNotice"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 32
        layer.enabled: HdrOutput.chromeRequired
        layer.effect: HdrChromeEffect {}
        width: mediaNoticeLabel.implicitWidth + 56; height: 40; radius: 20; z: 5
        color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.96)
        border.width: 1
        border.color: Theme.seam
        visible: mediaNoticeText !== ""
        Accessible.role: Accessible.AlertMessage
        Accessible.name: mediaNoticeText
        property string mediaNoticeText: ""
        Text {
            id: mediaNoticeLabel; anchors.centerIn: parent
            text: mediaNotice.mediaNoticeText
            color: Theme.label; font.family: Theme.monoFont; font.pixelSize: 12
        }
        Timer {
            interval: 4000
            running: mediaNotice.mediaNoticeText !== ""
            onTriggered: mediaNotice.mediaNoticeText = ""
        }
        Connections {
            target: ShellStore
            function onMediaMessageChanged() {
                if (ShellStore.mediaMessage !== "")
                    mediaNotice.mediaNoticeText = ShellStore.mediaMessage
            }
        }
    }

    Connections {
        target: ShellStore
        function onNativeSurfaceOcclusionsChanged() { Qt.callLater(root.publishNativeSurface) }
        function onPointerLockToggleRequested() {
            streamVideo.togglePointerLock()
        }
        function onNativePointerLockToggled(relativeMouse) {
            streamVideo.setExternalPointerLock(relativeMouse)
        }
        function onTextInputErrorAnnounced(message) {
            root.clipboardPasteMessage = message
            clipboardPasteNotice.restart()
        }
    }

    function restoreStreamFocus() {
        if (!root.visible || root.launchCovered
                || NativeStreamRuntime.usesExternalWindow
                || ShellStore.streamOverlayBlocksGameplayInput(AppController.overlay))
            return
        streamVideo.forceActiveFocus()
    }

    onVisibleChanged: {
        publishCaptureRect()
        Qt.callLater(root.publishNativeSurface)
        if (visible)
            Qt.callLater(root.restoreStreamFocus)
    }
    onLaunchCoveredChanged: Qt.callLater(root.resynchronizeStreamInput)

    Keys.onPressed: event => {
        if (event.isAutoRepeat)
            return
        if (!root.streaming
                && (event.key === Qt.Key_Escape || event.key === Qt.Key_Back)) {
            root.stopRequested()
            event.accepted = true
        }
    }
}
