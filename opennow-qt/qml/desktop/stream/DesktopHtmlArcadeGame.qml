pragma ComponentBehavior: Bound

import QtQuick
import QtWebEngine

Item {
    id: root
    objectName: "htmlArcadeGame"
    property string gameId: ""
    property bool active: false
    property bool pageLoaded: false
    property bool contentReady: false
    property bool canvasReady: false
    property string canvasStatus: qsTr("Waiting for the game canvas")
    property string loadError: ""
    property int canvasProbeCount: 0
    property bool canvasProbePending: false
    readonly property url gameUrl: "qrc:/qt/qml/OpenNOW/games/" + root.gameId + "/index.html"

    function resetPageHealth() {
        pageLoaded = false
        contentReady = false
        canvasReady = false
        canvasProbeCount = 0
        canvasProbePending = false
        canvasStatus = qsTr("Waiting for the game canvas")
        loadError = ""
    }

    function inspectCanvas() {
        if (!root.active || !root.pageLoaded || root.canvasReady || root.canvasProbePending)
            return

        let canvasId = ""
        if (root.gameId === "neon-drift")
            canvasId = "display-canvas"
        else if (root.gameId === "void-vanguard")
            canvasId = "showcase-canvas"
        else if (root.gameId === "rally-light")
            canvasId = "court"
        else {
            // Mosslight is rendered with DOM elements rather than a canvas.
            root.canvasStatus = qsTr("Game interface loaded")
            root.canvasReady = root.contentReady
            return
        }

        root.canvasProbeCount += 1
        root.canvasProbePending = true
        const requestedGame = root.gameId
        const requestedUrl = root.gameUrl.toString()
        const script = "(() => {"
            + "try {"
            + "const c = document.getElementById(" + JSON.stringify(canvasId) + ");"
            + "if (!c) return 'missing canvas #' + " + JSON.stringify(canvasId) + ";"
            + "if (c.clientWidth < 2 || c.clientHeight < 2 || c.width < 2 || c.height < 2)"
            + " return 'canvas has zero size (' + c.clientWidth + 'x' + c.clientHeight + ')';"
            + "const x = c.getContext('2d');"
            + "if (!x) return '2D context unavailable';"
            + "const w = c.width, h = c.height, pixels = x.getImageData(0, 0, w, h).data;"
            + "let painted = 0;"
            + "const sx = Math.max(1, Math.floor(w / 48)), sy = Math.max(1, Math.floor(h / 32));"
            + "for (let y = 0; y < h; y += sy) for (let x0 = 0; x0 < w; x0 += sx) {"
            + "const i = (y * w + x0) * 4;"
            + "if (pixels[i + 3] > 48 && pixels[i] + pixels[i + 1] + pixels[i + 2] > 90) painted++;"
            + "}"
            + "return JSON.stringify({width: c.clientWidth, height: c.clientHeight, painted});"
            + "} catch (e) { return 'canvas probe failed: ' + String(e); }"
            + "})()"

        browser.runJavaScript(script, function(result) {
            root.canvasProbePending = false
            if (!root.active || root.gameId !== requestedGame
                    || browser.url.toString() !== requestedUrl)
                return

            let report
            try {
                report = JSON.parse(String(result))
            } catch (_) {
                root.canvasStatus = String(result || qsTr("Canvas did not report a frame"))
                if (root.canvasProbeCount >= 20)
                    root.loadError = root.canvasStatus
                return
            }
            root.canvasStatus = qsTr("Canvas %1×%2 · %3 rendered samples")
                .arg(report.width).arg(report.height).arg(report.painted)
            if (report.width > 1 && report.height > 1 && report.painted > 0) {
                root.canvasReady = true
            } else if (root.canvasProbeCount >= 20) {
                root.loadError = root.canvasStatus
            }
        })
    }

    WebEngineView {
        id: browser
        objectName: "htmlArcadeBrowser"
        anchors.fill: parent
        url: root.active ? root.gameUrl : "about:blank"
        backgroundColor: "#070b14"
        focus: root.active
        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.javascriptCanOpenWindows: false
        settings.javascriptCanAccessClipboard: false
        settings.localContentCanAccessRemoteUrls: false
        settings.localContentCanAccessFileUrls: false
        // Chromium's accelerated 2D canvas can fail to composite into Qt Quick's
        // D3D11 swapchain on Windows. Keep the app/stream renderer unchanged and
        // rasterize these small local arcade canvases in software instead.
        settings.accelerated2dCanvasEnabled: false
        onLoadingChanged: loadRequest => {
            if (!root.active || browser.url !== root.gameUrl)
                return
            if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                root.resetPageHealth()
            } else if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                root.pageLoaded = true
                browser.runJavaScript(
                    "document.body && document.body.innerText.trim().length > 0",
                    function(hasVisibleText) { root.contentReady = Boolean(hasVisibleText) })
                root.inspectCanvas()
            } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                root.pageLoaded = false
                root.loadError = loadRequest.errorString
                console.warn("While-you-wait game failed to load:", loadRequest.errorString)
            }
        }
        onJavaScriptConsoleMessage: (level, message, lineNumber, sourceID) => {
            if (level === WebEngineView.ErrorMessageLevel) {
                root.loadError = qsTr("Game script error at line %1: %2").arg(lineNumber).arg(message)
                console.warn("While-you-wait game script error:", sourceID, lineNumber, message)
            }
        }
        onRenderProcessTerminated: (terminationStatus, exitCode) => {
            root.loadError = qsTr("Game renderer stopped (code %1)").arg(exitCode)
            console.warn("While-you-wait game renderer stopped:", terminationStatus, exitCode)
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.active && root.pageLoaded && !root.canvasReady && root.loadError === ""
        onTriggered: root.inspectCanvas()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 560)
        height: errorText.implicitHeight + 32
        visible: root.active && root.loadError !== ""
        radius: 12
        color: "#ee17131d"
        border.color: "#ff8fa3"
        border.width: 1
        z: 10
        Text {
            id: errorText
            anchors.fill: parent
            anchors.margins: 16
            color: "#ffd4dd"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            text: qsTr("Mini-game rendering failed: %1").arg(root.loadError)
        }
    }
}
