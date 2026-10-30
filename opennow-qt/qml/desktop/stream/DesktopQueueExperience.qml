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
    readonly property bool stacked: width < 1080 || height < 650
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
        anchors.topMargin: 68
        anchors.bottomMargin: 24
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, queueLayout.height + 48)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Item {
            id: queueLayout
            x: root.stacked ? 20 : 40
            y: root.stacked ? 20 : Math.max(16, (flick.height - height) / 2)
            width: Math.max(0, flick.width - 2 * x)
            height: root.stacked ? heroCard.height + 28 + queueColumn.implicitHeight
                : Math.max(heroCard.height, queueColumn.implicitHeight)

            Rectangle {
                id: heroCard
                objectName: "desktopQueueArtwork"
                x: 0
                y: 0
                width: root.stacked ? queueLayout.width
                    : Math.floor((queueLayout.width - 48) * 0.42)
                height: root.stacked ? (root.veryCompact ? 230 : 280)
                    : Math.min(610, Math.max(500, flick.height - 96))
                radius: Theme.radius(26)
                color: "#0B111D"
                border.width: 1
                border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.32)
                clip: true

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: coverArtwork.resolvedUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(Math.max(1, Math.ceil(width * 2)), Math.max(1, Math.ceil(height * 2)))
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: DesktopTokens.revealDuration } }
                    TapHandler {
                        enabled: coverImage.status === Image.Ready
                        onTapped: root.artworkViewerOpen = true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: coverImage.status !== Image.Ready
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#101827" }
                        GradientStop { position: 1; color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.16) }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    visible: coverImage.status !== Image.Ready
                    text: String(root.game.title || qsTr("GeForce NOW"))
                    color: Theme.mediaForeground
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: 26
                    font.weight: Font.Black
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.28; color: "transparent" }
                        GradientStop { position: 0.68; color: "#3004060A" }
                        GradientStop { position: 1; color: "#F704060A" }
                    }
                }

                Rectangle {
                    x: 22
                    y: 22
                    width: cloudRow.implicitWidth + 20
                    height: 30
                    radius: Theme.radius(15)
                    color: "#8A04060A"
                    border.width: 1
                    border.color: "#38FFFFFF"
                    Row {
                        id: cloudRow
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.mediaAccent
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("CLOUD QUEUE")
                            color: Theme.mediaForeground
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.3
                        }
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: root.stacked ? 20 : 26
                    spacing: 9
                    Text {
                        width: parent.width
                        text: String(root.game.title || qsTr("GeForce NOW"))
                        color: Theme.mediaForeground
                        font.family: DesktopTokens.displayFont
                        font.pixelSize: root.stacked ? 25 : 30
                        font.weight: Font.Black
                        font.letterSpacing: -0.7
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
                    DesktopButton {
                        id: viewArtworkButton
                        visible: coverImage.status === Image.Ready
                        onMediaBackground: true
                        text: qsTr("View artwork")
                        onClicked: root.artworkViewerOpen = true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: "#24FFFFFF"
                    radius: parent.radius
                }
            }

            Column {
                id: queueColumn
                objectName: "desktopQueuePass"
                x: root.stacked ? 0 : heroCard.width + 48
                y: root.stacked ? heroCard.height + 28
                    : Math.max(0, (heroCard.height - implicitHeight) / 2)
                width: root.stacked ? queueLayout.width
                    : queueLayout.width - heroCard.width - 48
                height: implicitHeight
                spacing: root.veryCompact ? 10 : 12

                Item {
                    width: parent.width
                    height: 28
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
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
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: liveRow.implicitWidth + 18
                        height: 28
                        radius: Theme.radius(14)
                        color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.30)
                        Row {
                            id: liveRow
                            anchors.centerIn: parent
                            spacing: 7
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: root.queueStalled ? DesktopTokens.amber : Theme.mediaAccent
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("LIVE")
                                color: Theme.mediaForeground
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                            }
                        }
                    }
                }

                Text {
                    objectName: "sessionQueueStatus"
                    width: parent.width
                    text: root.statusText
                    color: Theme.mediaForeground
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: root.veryCompact ? 27 : 34
                    font.weight: Font.Black
                    font.letterSpacing: -0.8
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

                Rectangle {
                    id: positionCard
                    objectName: "desktopQueuePositionCard"
                    width: parent.width
                    height: root.veryCompact ? 142 : 158
                    radius: Theme.radius(22)
                    color: "#D009101B"
                    border.width: 1
                    border.color: "#32FFFFFF"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 20
                        width: 3
                        radius: 1.5
                        color: Theme.mediaAccent
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.top: parent.top
                        anchors.topMargin: 18
                        width: parent.width * 0.46
                        spacing: 0
                        Text {
                            text: qsTr("YOUR PLACE IN LINE")
                            color: Theme.mediaMuted
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.1
                        }
                        Text {
                            text: root.queuePosition > 0 ? String(root.queuePosition) : "—"
                            color: Theme.mediaForeground
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: root.queuePosition > 999 ? 52 : positionCard.width < 420 ? 58 : 76
                            font.weight: Font.Black
                            font.letterSpacing: -2
                            Accessible.role: Accessible.StaticText
                            Accessible.name: root.statusText
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        anchors.top: parent.top
                        anchors.topMargin: 32
                        spacing: 22
                        Column {
                            spacing: 5
                            Text {
                                text: qsTr("ELAPSED")
                                color: Theme.mediaMuted
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                            Text {
                                text: root.elapsedText()
                                color: Theme.mediaForeground
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 19
                                font.weight: Font.Bold
                            }
                        }
                        Column {
                            visible: positionCard.width > 360
                            spacing: 5
                            Text {
                                text: qsTr("BEST POSITION")
                                color: Theme.mediaMuted
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                            Text {
                                text: root.bestPositionText()
                                color: Theme.mediaAccent
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 19
                                font.weight: Font.Bold
                            }
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        height: 34
                        radius: Theme.radius(10)
                        color: "#12FFFFFF"
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
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
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Item {
                    id: journey
                    objectName: "desktopQueueJourney"
                    width: parent.width
                    height: 94
                    Text {
                        text: qsTr("WHAT HAPPENS NEXT")
                        color: Theme.mediaMuted
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }
                    Item {
                        id: journeyTrack
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 28
                        height: 62
                        Rectangle {
                            x: journeyTrack.width / 6
                            y: 20
                            width: journeyTrack.width * 2 / 3
                            height: 2
                            color: "#30FFFFFF"
                        }
                        Rectangle {
                            x: journeyTrack.width / 6
                            y: 20
                            width: journeyTrack.width / 3
                            height: 2
                            color: Theme.mediaAccent
                        }
                        Repeater {
                            model: 3
                            delegate: Item {
                                id: step
                                required property int index
                                x: index * journeyTrack.width / 3
                                width: journeyTrack.width / 3
                                height: journeyTrack.height
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 3
                                    width: 36
                                    height: 36
                                    radius: Theme.radius(18)
                                    visible: step.index === 1
                                    color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.14)
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 8
                                    width: 26
                                    height: 26
                                    radius: Theme.radius(13)
                                    color: step.index === 1 ? Theme.mediaAccent : "#101722"
                                    border.width: 1
                                    border.color: step.index === 0 ? Theme.mediaAccent
                                        : step.index === 1 ? Theme.mediaAccent : "#55FFFFFF"
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
                                    anchors.right: parent.right
                                    anchors.leftMargin: 5
                                    anchors.rightMargin: 5
                                    y: 44
                                    text: root.stepLabel(step.index)
                                    color: step.index === 2 ? Theme.mediaMuted : Theme.mediaForeground
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: 11
                                    font.weight: step.index === 1 ? Font.ExtraBold : Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Grid {
                    id: detailGrid
                    objectName: "desktopQueueDetails"
                    width: parent.width
                    columns: width >= 620 ? 3 : 1
                    columnSpacing: 10
                    rowSpacing: 10
                    height: implicitHeight

                    Rectangle {
                        width: (detailGrid.width - detailGrid.columnSpacing * (detailGrid.columns - 1)) / detailGrid.columns
                        height: 56
                        radius: Theme.radius(12)
                        color: "#0FFFFFFF"
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 4
                            Text { text: qsTr("STREAM PROFILE"); color: Theme.mediaMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 1 }
                            Text { width: parent.width; text: root.streamProfileText(); color: Theme.mediaForeground; font.family: DesktopTokens.bodyFont; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight }
                        }
                    }
                    Rectangle {
                        width: (detailGrid.width - detailGrid.columnSpacing * (detailGrid.columns - 1)) / detailGrid.columns
                        height: 56
                        radius: Theme.radius(12)
                        color: "#0FFFFFFF"
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 4
                            Text { text: qsTr("REGION"); color: Theme.mediaMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 1 }
                            Text { width: parent.width; text: root.regionText(); color: Theme.mediaForeground; font.family: DesktopTokens.bodyFont; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight }
                        }
                    }
                    Rectangle {
                        width: (detailGrid.width - detailGrid.columnSpacing * (detailGrid.columns - 1)) / detailGrid.columns
                        height: 56
                        radius: Theme.radius(12)
                        color: "#0FFFFFFF"
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 4
                            Text { text: qsTr("SESSION DETAILS"); color: Theme.mediaMuted; font.family: DesktopTokens.monoFont; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 1 }
                            Text { width: parent.width; text: qsTr("Your session starts automatically"); color: Theme.mediaForeground; font.family: DesktopTokens.bodyFont; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        }
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
