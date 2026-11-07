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
    property string loadError: ""
    readonly property url gameUrl: "qrc:/qt/qml/OpenNOW/games/" + root.gameId + "/index.html"

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
        onLoadingChanged: loadRequest => {
            if (!root.active || browser.url !== root.gameUrl)
                return
            if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                root.pageLoaded = false
                root.contentReady = false
                root.loadError = ""
            } else if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                root.pageLoaded = true
                browser.runJavaScript(
                    "document.body && document.body.innerText.trim().length > 0",
                    function(hasVisibleText) { root.contentReady = Boolean(hasVisibleText) })
            } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                root.pageLoaded = false
                root.loadError = loadRequest.errorString
                console.warn("While-you-wait game failed to load:", loadRequest.errorString)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 520)
        visible: root.active && root.loadError.length > 0
        color: "#f3b5c4"
        font.pixelSize: 15
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: qsTr("This mini-game could not be loaded: %1").arg(root.loadError)
    }
}
