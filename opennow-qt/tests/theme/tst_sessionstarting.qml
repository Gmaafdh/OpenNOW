import QtQuick
import QtTest
import OpenNOW

TestCase {
    id: testCase
    name: "SessionStartingContrast"
    width: 1000
    height: 700
    when: windowShown
    visible: true

    DesktopSessionStarting {
        id: screen
        anchors.fill: parent
    }

    DesktopButton {
        id: shellButton
        visible: false
        text: "Shell button"
    }

    function init() {
        testCase.width = 1000
        testCase.height = 700
        ShellStore.previewThemePack = ""
        ShellStore.streamState = "preparing"
        ShellStore.activeSession = Object.assign({}, ShellStore.activeSession, {queuePosition: 21})
        AppController.route = "inserting"
        AppController.overlay = ""
        AppController.reducedMotion = true
    }

    function descendants(item) {
        let result = []
        for (const child of item.children || [])
            result = result.concat([child], descendants(child))
        return result
    }

    function visibleOnScreen(item) {
        for (let current = item; current; current = current.parent) {
            if (current.visible === false)
                return false
            if (current === screen)
                return true
        }
        return false
    }

    function textItem(text) {
        const item = descendants(screen).find(item => item.text === text && item.color !== undefined
            && visibleOnScreen(item))
        verify(item !== undefined, "Missing visible text: " + text)
        return item
    }

    function contrastOnDark(color) {
        const background = Qt.color("#04060A")
        const linear = value => value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        const luminance = value => linear(value.r) * 0.2126 + linear(value.g) * 0.7152 + linear(value.b) * 0.0722
        const composited = Qt.rgba(color.r * color.a + background.r * (1 - color.a),
                                  color.g * color.a + background.g * (1 - color.a),
                                  color.b * color.a + background.b * (1 - color.a), 1)
        return (luminance(composited) + 0.05) / (luminance(background) + 0.05)
    }

    function test_launchPalette_data() {
        const rows = []
        for (const pack of Theme.packs) {
            for (const mode of ["light", "dark", "auto"]) {
                for (const accent of ["pack"].concat(Theme.accentChoices))
                    rows.push({tag: pack.id + "-" + mode + "-" + accent, pack: pack.id, mode: mode, accent: accent})
            }
        }
        return rows
    }

    function test_launchPalette(data) {
        ShellStore.settings = {themePack: data.pack, appTheme: data.mode,
            appAccentColor: data.accent, themeAccentOverride: data.accent !== "pack"}
        compare(textItem("Dead by Daylight").color, Theme.mediaForeground)
        compare(textItem("Queue position 21").color, Theme.mediaForeground)
        compare(textItem("OpenNOW").color, Theme.mediaForeground)
        compare(textItem(screen.detailText).color.toString(), Theme.mediaMuted.toString())
        compare(textItem("STARTING SESSION").color, Theme.mediaAccent)
        compare(textItem("Cancel session").color, Theme.mediaForeground)
        for (const text of ["Dead by Daylight", "Queue position 21", "OpenNOW",
                            screen.detailText, "STARTING SESSION", "Cancel session"])
            verify(contrastOnDark(textItem(text).color) >= 4.5, "Insufficient contrast: " + text)

        const shortcut = descendants(screen).find(item => item.shortcut === "Esc")
        verify(shortcut !== undefined)
        compare(shortcut.ink, Theme.mediaMuted)
        verify(contrastOnDark(shortcut.ink) >= 4.5)

        const cancel = descendants(screen).find(item => item.text === "Cancel session" && item.onMediaBackground !== undefined)
        cancel.forceActiveFocus()
        verify(descendants(cancel.background).some(item => item.visible && item.border
            && item.border.width === 2 && item.border.color.toString() === Theme.mediaAccent.toString()))

        const shellText = descendants(shellButton).find(item => item.text === shellButton.text && item.color !== undefined)
        compare(shellText.color, DesktopTokens.textHigh)
    }

    function test_compactLayout_data() {
        return [
            {tag: "stacked-800x600", width: 800, height: 600},
            {tag: "stacked-900x600", width: 900, height: 600},
            {tag: "compact-1000x700", width: 1000, height: 700},
            {tag: "compact-1280x720", width: 1280, height: 720},
            {tag: "desktop-1440x900", width: 1440, height: 900}
        ]
    }

    function test_compactLayout(data) {
        testCase.width = data.width
        testCase.height = data.height
        ShellStore.activeSession = {sessionId: "layout-" + data.tag, seatSetupStep: 1, queuePosition: 21}
        const items = descendants(screen)
        const queue = items.find(item => item.objectName === "desktopQueueExperience")
        const pass = items.find(item => item.objectName === "desktopQueuePass")
        const position = items.find(item => item.objectName === "sessionQueuePositionBlock")
        const cancel = items.find(item => item.objectName === "desktopQueueCancel")
        verify(queue && pass && position && cancel)
        tryCompare(queue, "width", data.width)
        tryCompare(queue, "height", data.height)
        waitForRendering(screen)

        const passPoint = pass.mapToItem(queue, 0, 0)
        const positionPoint = position.mapToItem(queue, 0, 0)
        const cancelPoint = cancel.mapToItem(queue, 0, 0)
        verify(passPoint.y >= 58 && passPoint.y < 100,
            "Queue content must start in the initial viewport; y=" + passPoint.y)
        verify(positionPoint.y >= 0 && positionPoint.y + position.height <= data.height,
            "Queue position must be visible without scrolling; bottom=" + (positionPoint.y + position.height))
        verify(cancelPoint.x >= 0 && cancelPoint.x + cancel.width <= data.width)
        verify(cancelPoint.y + cancel.height <= data.height - 8,
            "Queue actions must be visible without scrolling; bottom=" + (cancelPoint.y + cancel.height))
    }

    function test_queueMorphAndReducedMotion() {
        const queue = descendants(screen).find(item => item.objectName === "desktopQueueExperience")
        verify(queue !== undefined)
        AppController.reducedMotion = true
        compare(queue.sectionOpacity(3), 1)
        compare(queue.sectionOffset(3, 18), 0)
        const status = descendants(screen).find(item => item.objectName === "sessionQueueStatus")
        compare(status.opacity, 1)
        compare(status.parent.opacity, 1)

        ShellStore.activeSession = Object.assign({}, ShellStore.activeSession, {queuePosition: 32})
        compare(queue.queuePosition, 32)
        let number = descendants(screen).find(item => item.objectName === "sessionQueuePosition")
        compare(number.text, "32")
        compare(number.opacity, 1)

        AppController.reducedMotion = false
        ShellStore.activeSession = Object.assign({}, ShellStore.activeSession, {queuePosition: 18})
        compare(queue.queuePosition, 18)
        number = descendants(screen).find(item => item.objectName === "sessionQueuePosition")
        compare(number.text, "18")
        verify(number.opacity < 1, "queue number should crossfade from its previous value")

        queue.playEntrance()
        compare(queue.entranceProgress, 0)
        AppController.reducedMotion = true
        compare(queue.entranceProgress, 1)
        compare(number.opacity, 1)
        ShellStore.activeSession = Object.assign({}, ShellStore.activeSession, {queuePosition: 21})
    }

    function test_queueProgressSessionReset() {
        const queue = descendants(screen).find(item => item.objectName === "desktopQueueExperience")
        verify(queue !== undefined)
        AppController.reducedMotion = true
        ShellStore.activeSession = {sessionId: "queue-a", seatSetupStep: 1, queuePosition: 40}
        compare(queue.queuePosition, 40)
        compare(queue.peakPosition, 40)

        ShellStore.activeSession = {sessionId: "queue-a", seatSetupStep: 1, queuePosition: 12}
        compare(queue.queuePosition, 12)
        compare(queue.peakPosition, 40)

        // A reused component must not carry the previous session's baseline
        // into a new queue, even when both sessions report the same position.
        ShellStore.activeSession = {sessionId: "queue-b", seatSetupStep: 1, queuePosition: 12}
        compare(queue.queuePosition, 12)
        compare(queue.peakPosition, 12)
        ShellStore.activeSession = {queuePosition: 21}
    }

    function test_whileYouWaitGamesSaveAndYieldToConnection() {
        const queue = descendants(screen).find(item => item.objectName === "desktopQueueExperience")
        const action = descendants(screen).find(item => item.objectName === "desktopQueueWhileYouWait")
        const overlay = descendants(screen).find(item => item.objectName === "desktopWhileYouWait")
        verify(queue && action && overlay)
        compare(overlay.showing, false)
        mouseClick(action)
        tryCompare(overlay, "showing", true)
        compare(overlay.games.length, 4)
        compare(AppController.route, "inserting")
        compare(queue.queuePosition, 21)

        const expectedGames = ["rally-light", "void-vanguard", "neon-drift", "mosslight"]
        for (let i = 0; i < expectedGames.length; ++i)
            verify(descendants(overlay).some(item => item.objectName === "whileYouWaitGame-" + expectedGames[i]))

        const fighterChoice = descendants(overlay).find(item => item.objectName === "whileYouWaitGame-void-vanguard")
        verify(fighterChoice)
        mouseClick(fighterChoice)
        compare(overlay.gameId, "void-vanguard")
        const loader = descendants(overlay).find(item => item.objectName === "whileYouWaitGameLoader")
        verify(loader)
        tryCompare(loader, "status", Loader.Ready)
        const webGame = descendants(overlay).find(item => item.objectName === "htmlArcadeGame")
        verify(webGame)
        compare(webGame.gameId, "void-vanguard")
        compare(webGame.gameUrl.toString(), "qrc:/qt/qml/OpenNOW/games/void-vanguard/index.html")
        tryVerify(() => webGame.pageLoaded, 15000,
                  "The packaged HTML game document must load successfully in WebEngine")
        tryVerify(() => webGame.contentReady, 5000,
                  "The loaded game document must expose visible game UI text")
        compare(webGame.loadError, "", "The game page must not report a WebEngine load error")
        compare(queue.queuePosition, 21, "The queue should keep its own state while a game is open")

        overlay.showPicker()
        const rallyChoice = descendants(overlay).find(item => item.objectName === "whileYouWaitGame-rally-light")
        verify(rallyChoice)
        mouseClick(rallyChoice)
        tryCompare(loader, "status", Loader.Ready)
        compare(overlay.gameId, "rally-light")
        compare(queue.queuePosition, 21, "Opening another local game must not alter queue progress")

        AppController.route = "stream"
        tryCompare(overlay, "showing", false)
        tryCompare(screen, "queueVisible", false)
        compare(overlay.open, false)
        AppController.route = "inserting"
    }

    function test_failureAndReconnect() {
        ShellStore.settings = {themePack: "nocturne", appTheme: "light"}
        ShellStore.streamState = "failed"
        compare(textItem("Session could not start").color, DesktopTokens.danger)
        compare(textItem("Try again").color, Qt.color("#0A0D14"))
        compare(textItem("Cancel session").color, Theme.mediaForeground)
        ShellStore.streamState = "reconnecting"
        compare(textItem("Reconnecting to your session").color, Theme.mediaForeground)
        ShellStore.streamState = "stopping"
        compare(textItem("Closing your session").color, Theme.mediaForeground)
    }
}
