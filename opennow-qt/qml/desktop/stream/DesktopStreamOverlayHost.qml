import QtQuick
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopStreamOverlayHost"
    width: 1440
    height: 900
    property string overlay: ""
    property bool inputBlocking: false
    property bool pointerLocked: false
    property var frameGenerationStats: ({})
    property var swapStats: ({})
    property bool notificationsEnabled: false
    property bool connectionNotificationsEnabled: true
    focus: visible && inputBlocking
    readonly property bool present: menuView.present || exitView.present || statsVisible || notificationsEnabled
    readonly property var nativeSurfaceOcclusions: {
        if (!root.visible)
            return []
        let rectangles = root.statsVisible ? statsView.nativeOcclusionRects.slice() : []
        if (root.menuVisible)
            rectangles = rectangles.concat(menuView.nativeOcclusionRects)
        if (root.exitVisible)
            rectangles = rectangles.concat(exitView.nativeOcclusionRects)
        const toast = nativeOcclusion(toasts)
        if (toast !== null)
            rectangles.push(toast)
        return rectangles
    }
    onNativeSurfaceOcclusionsChanged: ShellStore.nativeSurfaceOcclusions = nativeSurfaceOcclusions
    Component.onCompleted: ShellStore.nativeSurfaceOcclusions = nativeSurfaceOcclusions
    Component.onDestruction: ShellStore.nativeSurfaceOcclusions = []

    function nativeOcclusion(item) {
        if (!root.visible || !item.visible || item.width <= 0 || item.height <= 0
                || !Number.isFinite(item.x) || !Number.isFinite(item.y))
            return null
        const rect = item.mapToItem(null, 0, 0, item.width, item.height)
        return Qt.rect(rect.x, rect.y, rect.width, rect.height)
    }

    readonly property bool menuVisible: overlay === "desktop-stream-menu"
    readonly property bool exitVisible: overlay === "desktop-stream-exit-confirm"
    readonly property bool statsVisible: overlay === "desktop-stream-stats"
        || overlay === "desktop-stream-stats-expanded"
        || overlay === "stream-stats"
        || overlay === "stream-stats-expanded"

    function closeOverlay() {
        AppController.showOverlay("")
    }
    function cycleStats() {
        const prefix = overlay.startsWith("desktop-") ? "desktop-stream-stats" : "stream-stats"
        if (overlay === prefix)
            AppController.showOverlay(prefix + "-expanded")
        else if (overlay === prefix + "-expanded")
            AppController.showOverlay("")
        else
            AppController.showOverlay(prefix)
    }
    function copyStatsSummary() { return statsView.report() }
    function copyStatsToClipboard() {
        const summary = root.copyStatsSummary()
        if (AppController.writeClipboardText(summary))
            ShellStore.accessibilityMessage = summary
    }

    function nativeAccent(value) {
        return ((Math.round(value.r * 255) << 16)
            | (Math.round(value.g * 255) << 8)
            | Math.round(value.b * 255)) >>> 0
    }

    function nativeOverlayModel(overlayName, clockMs, controlToast) {
        const name = String(overlayName || "")
        let model = {kind: "", items: [], hud: [], inputBlocking: false}
        if (name === "desktop-stream-menu" || name === "guide-session")
            model = menuView.nativeViewModel(clockMs, controlToast)
        else if (statsVisible || name === "desktop-stream-stats" || name === "desktop-stream-stats-expanded"
                || name === "stream-stats" || name === "stream-stats-expanded")
            model = statsView.nativeViewModel(name.endsWith("-expanded"))
        else if (name === "desktop-stream-exit-confirm")
            model = exitView.nativeViewModel()
        const modal = model.inputBlocking === true
        const hud = []
        if (!modal) {
            if (statsView.shown("Clock") && ShellStore.streamStartedAtMs > 0)
                hud.push({id: "session-clock", action: "", label: statsView.elapsedText(clockMs),
                    value: "", role: "hud-right", enabled: false})
            const elapsedSeconds = Math.max(0, Math.floor((clockMs - ShellStore.streamStartedAtMs) / 1000))
            if (ShellStore.antiAfkIndicatorShown(elapsedSeconds))
                hud.push({id: "anti-afk", action: "", label: qsTr("Anti-AFK") + " · " + qsTr("On"),
                    value: "", role: "hud-left", enabled: false})
            if (ShellStore.microphoneEnabled)
                hud.push({id: "microphone", action: "", label: ShellStore.microphoneLabel,
                    value: "", role: "hud-left", enabled: false})
            if (notificationsEnabled)
                for (const toast of toasts.nativeItems()) hud.push(toast)
            if (String(controlToast || "") !== "")
                hud.push({id: "stream-control", action: "", label: String(controlToast),
                    value: "", role: "toast", enabled: false})
        }
        model.hud = hud
        model.fontFamily = Theme.bodyFont
        model.monoFontFamily = Theme.monoFont
        model.accent = nativeAccent(Theme.focus)
        model.reducedMotion = AppController.reducedMotion
        if (model.scale === undefined) model.scale = 1
        if (model.opacity === undefined) model.opacity = name === "desktop-stream-exit-confirm" ? 96 : 92
        if (model.position === undefined) model.position = ""
        return model
    }

    DesktopInStreamMenu {
        id: menuView
        anchors.fill: parent
        opened: root.menuVisible
        onResumeRequested: root.closeOverlay()
        onInviteRequested: if (ShellStore.socialCapabilities
                && ShellStore.socialCapabilities.invitesAvailable)
            AppController.showOverlay("friends")
        onConsoleModeRequested: enabled => {
            ShellStore.requestConsoleSurface(enabled)
            ShellStore.accessibilityMessage = enabled
                ? qsTr("Switching to console mode") : qsTr("Switching to computer mode")
            root.closeOverlay()
        }
        onEndSessionRequested: {
            ShellStore.requestStreamExitConfirmation()
        }
        onFullscreenRequested: ShellStore.fullscreenToggleRequested()
        onStatsRequested: AppController.showOverlay("desktop-stream-stats-expanded")
    }

    DesktopStreamExitConfirm {
        id: exitView
        anchors.fill: parent
        opened: root.exitVisible
        onCancelRequested: root.closeOverlay()
        onConfirmRequested: ShellStore.confirmStreamExit()
    }

    DesktopStreamStats {
        id: statsView
        anchors.fill: parent
        visible: root.statsVisible
        frameGenerationStats: root.frameGenerationStats
        swapStats: root.swapStats
        pointerLocked: root.pointerLocked
        focus: false
        expanded: root.overlay === "desktop-stream-stats-expanded"
            || root.overlay === "stream-stats-expanded"
        onCycleRequested: root.cycleStats()
        onCloseRequested: root.closeOverlay()
        onCopyRequested: root.copyStatsToClipboard()
    }

    DesktopStreamToasts {
        id: toasts
        connectionNotificationsEnabled: root.connectionNotificationsEnabled
        controllers: ControllerInput.controllers
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: statsView.topRightInset
        visible: root.notificationsEnabled && !root.inputBlocking && y + 148 <= root.height - 24
    }

    Keys.onPressed: event => {
        const modifiers = event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier
            | Qt.AltModifier | Qt.MetaModifier)
        if (!root.exitVisible && event.key === Qt.Key_Q
                && modifiers === (Qt.ControlModifier | Qt.ShiftModifier)) {
            ShellStore.requestStreamExitConfirmation()
            event.accepted = true
        }
    }
}
