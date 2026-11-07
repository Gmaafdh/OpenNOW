pragma ComponentBehavior: Bound

import QtQuick
import QtWebEngine

Item {
    id: root
    objectName: "htmlArcadeGame"
    property string gameId: ""
    property bool active: false
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
            if (loadRequest.status === WebEngineView.LoadFailedStatus)
                console.warn("While-you-wait game failed to load:", loadRequest.errorString)
        }
    }
}
