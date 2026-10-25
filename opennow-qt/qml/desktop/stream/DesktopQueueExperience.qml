pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopQueueExperience"

    property var game: ({})
    property var session: ({})
    property int queuePosition: 0
    property string statusText: ""
    property string detailText: ""
    property string activityText: ""
    property bool queueStalled: false
    property bool requeueAvailable: false
    property bool requeueInProgress: false
    property bool streamBusy: false
    property bool artworkViewerOpen: false
    property double queueVisibleSinceMs: 0
    property double queueClockMs: Date.now()

    signal cancelRequested()
    signal refreshRequested()
    signal requeueRequested()

    readonly property bool compact: height < 820
    readonly property bool veryCompact: height < 700
    readonly property bool stacked: width < 1000 || height < 650
    readonly property int elapsedSeconds: queueVisibleSinceMs > 0
        ? Math.max(0, Math.floor((queueClockMs - queueVisibleSinceMs) / 1000)) : 0
    readonly property string coverSource: DesktopTokens.artworkUrl(root.game, false)

    Accessible.role: Accessible.Pane
    Accessible.name: root.statusText
    clip: true

    function restoreFocus() {
        if (root.artworkViewerOpen)
            closeArtworkButton.forceActiveFocus()
        else
            cancelButton.forceActiveFocus()
    }

    function stepLabel(index) {
        if (index === 0) return qsTr("Session requested")
        if (index === 1) return qsTr("Waiting for a rig")
        return qsTr("Connecting the stream")
    }

    function elapsedText() {
        const total = root.elapsedSeconds
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const seconds = total % 60
        return hours > 0
            ? hours + ":" + String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
            : String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
    }

    function regionText() {
        let value = String(root.session.regionName || root.session.region || root.session.serverRegionId
            || (typeof root.session.serverLocation === "string" ? root.session.serverLocation : "")
            || root.session.zone || ShellStore.selectedRegionName || "")
        if (value.indexOf("http://") === 0 || value.indexOf("https://") === 0)
            value = value.replace(/^https?:\/\//, "").split("/")[0]
        return value === "" ? qsTr("Automatic") : value
    }

    function streamProfileText() {
        const settings = ShellStore.settings || ({})
        const profile = root.session.negotiatedStreamProfile || root.session.streamProfile || ({})
        const measuredResolution = Number(profile.width || 0) > 0 && Number(profile.height || 0) > 0
            ? String(profile.width) + "x" + String(profile.height) : ""
        const resolution = String(profile.resolution || measuredResolution || settings.resolution || "")
        const fps = Number(profile.fps || settings.fps || 0)
        const codec = String(profile.codec || settings.codec || "auto").toUpperCase()
        const parts = []
        if (resolution.indexOf("x") > 0)
            parts.push(resolution.split("x")[1] + "p")
        else if (resolution !== "")
            parts.push(resolution)
        if (fps > 0)
            parts.push(fps + " fps")
        if (codec !== "")
            parts.push(codec)
        return parts.length ? parts.join(" · ") : qsTr("Automatic")
    }

    function bestPositionText() {
        const best = Number(ShellStore.sessionProgressBestPosition || 0)
        return best > 0 ? String(best) : "—"
    }

    function gameSubtitle() {
        const publisher = String(root.game.publisherName || "")
        const genres = root.game.genres || []
        const genre = Array.isArray(genres) && genres.length ? String(genres[0]).replace(/_/g, " ") : ""
        return [publisher, genre].filter(value => value !== "").join(" · ")
    }

    ArtworkSource {
        id: coverArtwork
        sourceUrl: root.coverSource
        active: root.visible
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.queueClockMs = Date.now()
    }

    onVisibleChanged: {
        if (visible) {
            root.queueVisibleSinceMs = Date.now()
            root.queueClockMs = root.queueVisibleSinceMs
        } else {
            root.artworkViewerOpen = false
        }
    }
    onArtworkViewerOpenChanged: if (root.visible) Qt.callLater(root.restoreFocus)
    Component.onCompleted: {
        root.queueVisibleSinceMs = Date.now()
        root.queueClockMs = root.queueVisibleSinceMs
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: 58
        anchors.bottomMargin: 20
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, layoutGrid.implicitHeight + 48)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Grid {
            id: layoutGrid
            x: root.stacked ? 20 : 40
            y: root.stacked ? 20 : Math.max(20, (flick.height - implicitHeight) / 2)
            width: Math.max(0, flick.width - 2 * x)
            height: implicitHeight
            columns: root.stacked ? 1 : 2
            rows: root.stacked ? 2 : 1
            columnSpacing: root.stacked ? 0 : 56
            rowSpacing: root.stacked ? 30 : 0

            Item {
                id: artworkPanel
                width: root.stacked ? layoutGrid.width
                    : Math.floor((layoutGrid.width - layoutGrid.columnSpacing) * 0.46)
                height: root.stacked ? artworkColumn.implicitHeight : coverPanelHeight
                readonly property real coverPanelHeight: Math.min(620, Math.max(430, flick.height - 70))

                Column {
                    id: artworkColumn
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        id: artFrame
                        width: parent.width
                        height: root.stacked ? 270 : artworkPanel.coverPanelHeight - 132
                        radius: 20
                        color: Theme.lightMode ? "#E8EBF0" : "#101827"
                        border.width: 1
                        border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.34)
                        clip: true

                        Image {
                            id: coverImage
                            anchors.fill: parent
                            source: coverArtwork.resolvedUrl
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(Math.max(1, Math.ceil(width * 2)), Math.max(1, Math.ceil(height * 2)))
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: DesktopTokens.revealDuration } }
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 40
                            visible: coverImage.status !== Image.Ready
                            text: String(root.game.title || qsTr("GeForce NOW"))
                            color: Theme.lightMode ? Theme.label : Theme.mediaForeground
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: 24
                            font.weight: Font.Black
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: "#22FFFFFF"
                            radius: parent.radius
                        }
                        TapHandler {
                            enabled: coverImage.status === Image.Ready
                            onTapped: root.artworkViewerOpen = true
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 3
                        Text {
                            width: parent.width
                            text: String(root.game.title || qsTr("GeForce NOW"))
                            color: Theme.mediaForeground
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: 23
                            font.weight: Font.Black
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: root.gameSubtitle()
                            color: Theme.mediaMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }

                    DesktopButton {
                        id: viewArtworkButton
                        visible: coverImage.status === Image.Ready
                        onMediaBackground: true
                        text: qsTr("View artwork")
                        onClicked: root.artworkViewerOpen = true
                    }
                }
            }

            Column {
                id: queuePass
                objectName: "desktopQueuePass"
                width: root.stacked ? layoutGrid.width
                    : layoutGrid.width - artworkPanel.width - layoutGrid.columnSpacing
                spacing: root.veryCompact ? 10 : 14

                Row {
                    width: parent.width
                    height: 24
                    spacing: 10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 2
                        color: Theme.mediaAccent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("STARTING SESSION")
                        color: Theme.mediaAccent
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.6
                    }
                }

                Text {
                    objectName: "sessionQueueStatus"
                    width: parent.width
                    text: root.statusText
                    color: Theme.mediaForeground
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: root.veryCompact ? 25 : 32
                    font.weight: Font.Black
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.detailText
                    color: Theme.mediaMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: 14
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                Item {
                    id: positionBlock
                    width: parent.width
                    height: 116
                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            text: qsTr("YOUR PLACE IN LINE")
                            color: Theme.mediaMuted
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Text {
                            text: root.queuePosition > 0 ? String(root.queuePosition) : "—"
                            color: Theme.mediaForeground
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: root.queuePosition > 999 ? 58 : root.veryCompact ? 66 : 82
                            font.weight: Font.Black
                            Accessible.role: Accessible.StaticText
                            Accessible.name: root.statusText
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 24
                        Column {
                            spacing: 4
                            Text {
                                text: qsTr("ELAPSED")
                                color: Theme.mediaMuted
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                            Text {
                                text: root.elapsedText()
                                color: Theme.mediaForeground
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }
                        }
                        Column {
                            visible: positionBlock.width > 360
                            spacing: 4
                            Text {
                                text: qsTr("BEST POSITION")
                                color: Theme.mediaMuted
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                            Text {
                                text: root.bestPositionText()
                                color: Theme.mediaAccent
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#2AFFFFFF" }

                Grid {
                    id: detailGrid
                    width: parent.width
                    columns: root.veryCompact ? 1 : 2
                    columnSpacing: 20
                    rowSpacing: 12
                    height: implicitHeight

                    Column {
                        width: root.veryCompact ? detailGrid.width : (detailGrid.width - detailGrid.columnSpacing) / 2
                        spacing: 4
                        Text { text: qsTr("STREAM PROFILE"); color: Theme.mediaMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1 }
                        Text { width: parent.width; text: root.streamProfileText(); color: Theme.mediaForeground; font.family: DesktopTokens.bodyFont; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight }
                    }
                    Column {
                        width: root.veryCompact ? detailGrid.width : (detailGrid.width - detailGrid.columnSpacing) / 2
                        spacing: 4
                        Text { text: qsTr("REGION"); color: Theme.mediaMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1 }
                        Text { width: parent.width; text: root.regionText(); color: Theme.mediaForeground; font.family: DesktopTokens.bodyFont; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight }
                    }
                    Column {
                        width: root.veryCompact ? detailGrid.width : (detailGrid.width - detailGrid.columnSpacing) / 2
                        spacing: 4
                        Text { text: qsTr("QUEUE UPDATES"); color: Theme.mediaMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1 }
                        Text { width: parent.width; text: root.activityText; color: Theme.mediaForeground; font.family: DesktopTokens.bodyFont; font.pixelSize: 13; font.weight: Font.DemiBold; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
                    }
                    Column {
                        width: root.veryCompact ? detailGrid.width : (detailGrid.width - detailGrid.columnSpacing) / 2
                        spacing: 4
                        Text { text: qsTr("SESSION DETAILS"); color: Theme.mediaMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1 }
                        Text { width: parent.width; text: qsTr("Your session starts automatically"); color: Theme.mediaForeground; font.family: DesktopTokens.bodyFont; font.pixelSize: 13; font.weight: Font.DemiBold; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#2AFFFFFF" }

                Text {
                    text: qsTr("WHAT HAPPENS NEXT")
                    color: Theme.mediaMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
                Column {
                    width: parent.width
                    spacing: 7
                    Repeater {
                        model: 3
                        delegate: Item {
                            id: step
                            required property int index
                            width: parent.width
                            height: 28
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                radius: 10
                                color: step.index === 1 ? Theme.mediaAccent : "transparent"
                                border.width: 1
                                border.color: step.index === 1 ? Theme.mediaAccent : "#55FFFFFF"
                                Text {
                                    anchors.centerIn: parent
                                    text: step.index === 0 ? "✓" : String(step.index + 1)
                                    color: step.index === 1 ? "#0A0D14" : Theme.mediaForeground
                                    font.family: DesktopTokens.monoFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 32
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.stepLabel(step.index)
                                color: step.index === 2 ? Theme.mediaMuted : Theme.mediaForeground
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: 13
                                font.weight: step.index === 1 ? Font.ExtraBold : Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 24
                    spacing: 9
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.queueStalled ? DesktopTokens.amber : Theme.mediaAccent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 16
                        text: root.activityText
                        color: Theme.mediaMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 10
                    DesktopButton {
                        id: requeueButton
                        objectName: "desktopQueueRequeue"
                        onMediaBackground: true
                        visible: root.queueStalled && root.requeueAvailable
                        enabled: !root.streamBusy && !root.requeueInProgress
                        primary: true
                        text: qsTr("Request a fresh rig")
                        onClicked: root.requeueRequested()
                    }
                    DesktopButton {
                        objectName: "desktopQueueRefresh"
                        onMediaBackground: true
                        enabled: !root.streamBusy && !root.requeueInProgress
                        text: qsTr("Refresh status")
                        onClicked: root.refreshRequested()
                    }
                    DesktopButton {
                        id: cancelButton
                        objectName: "desktopQueueCancel"
                        onMediaBackground: true
                        enabled: !root.requeueInProgress
                        text: qsTr("Cancel session")
                        shortcutText: qsTr("Esc")
                        onClicked: root.cancelRequested()
                    }
                }
            }
        }
    }

    Rectangle {
        id: artworkViewer
        anchors.fill: parent
        z: 50
        visible: root.artworkViewerOpen
        color: "#F20B0F1A"
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("View artwork")

        MouseArea {
            anchors.fill: parent
            onClicked: root.artworkViewerOpen = false
        }
        Image {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: parent.height * 0.80
            source: coverArtwork.resolvedUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            sourceSize: Qt.size(1600, 1600)
        }
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 32
            width: parent.width - 64
            text: String(root.game.title || qsTr("GeForce NOW"))
            color: Theme.mediaForeground
            font.family: DesktopTokens.displayFont
            font.pixelSize: 22
            font.weight: Font.Black
            elide: Text.ElideRight
        }
        DesktopButton {
            id: closeArtworkButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            onMediaBackground: true
            text: qsTr("Close")
            shortcutText: qsTr("Esc")
            onClicked: root.artworkViewerOpen = false
        }
    }

    Keys.onPressed: event => {
        if (root.artworkViewerOpen && (event.key === Qt.Key_Escape || event.key === Qt.Key_Back)) {
            root.artworkViewerOpen = false
            event.accepted = true
        }
    }
}
