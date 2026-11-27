pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
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
    property real entranceProgress: 1
    property bool motionReady: false

    // ambient motion phases (all driven by the animations below)
    property real breath: 0        // 0..1..0 slow pulse
    property real spin: 0          // 0..360 fast spinner
    property int peakPosition: 0
    property string peakSessionId: ""

    signal cancelRequested()
    signal refreshRequested()
    signal requeueRequested()

    readonly property bool compact: height < 820
    readonly property bool veryCompact: height < 760
    // Short windows cannot carry the side-by-side mission column: below 760 px
    // tall the queue panel takes the full width and the artwork drops beneath
    // it, which keeps the actions inside the first viewport.
    readonly property bool stacked: width < 1000 || height < 650
        || (height < 760 && width < 1200)
    readonly property bool animating: root.visible && !AppController.reducedMotion
    readonly property int elapsedSeconds: queueVisibleSinceMs > 0
        ? Math.max(0, Math.floor((queueClockMs - queueVisibleSinceMs) / 1000)) : 0
    readonly property string coverSource: DesktopTokens.artworkUrl(root.game, false)

    readonly property bool indeterminate: root.queuePosition <= 0
    readonly property real ringProgress: root.queuePosition <= 0 ? 0
        : root.peakPosition <= 1 ? 1
        : Math.max(0.03, Math.min(1, (root.peakPosition - root.queuePosition) / (root.peakPosition - 1)))
    property real shownProgress: root.ringProgress
    Behavior on shownProgress { NumberAnimation { duration: Theme.duration(900); easing.type: Easing.OutCubic } }

    readonly property real ringSize: Math.max(150, Math.min(root.veryCompact ? 176 : 224, queuePass.width - 48))

    Accessible.role: Accessible.Pane
    Accessible.name: root.statusText
    clip: true

    // ───────────────────────── helpers ─────────────────────────

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

    function progressText() {
        return root.queuePosition > 0 ? Math.round(root.ringProgress * 100) + "%" : "—"
    }

    function aheadCaption() {
        if (root.queuePosition === 1) return qsTr("You're next")
        if (root.queuePosition > 1) return qsTr("%1 ahead of you").arg(root.queuePosition - 1)
        return qsTr("Finding your spot")
    }

    function gameSubtitle() {
        const publisher = String(root.game.publisherName || "")
        const genres = root.game.genres || []
        const genre = Array.isArray(genres) && genres.length ? String(genres[0]).replace(/_/g, " ") : ""
        return [publisher, genre].filter(value => value !== "").join(" · ")
    }

    function sectionOpacity(order) {
        if (AppController.reducedMotion)
            return 1
        return Math.max(0, Math.min(1, (root.entranceProgress - order * 0.08) / 0.60))
    }

    function sectionOffset(order, distance) {
        return (1 - root.sectionOpacity(order)) * distance
    }

    function playEntrance() {
        if (!root.motionReady)
            return
        entranceAnimation.stop()
        if (AppController.reducedMotion) {
            root.entranceProgress = 1
        } else {
            root.entranceProgress = 0
            entranceAnimation.start()
        }
    }

    function synchronizePeakPosition() {
        const sessionId = String(root.session && root.session.sessionId || "")
        if (sessionId !== root.peakSessionId) {
            root.peakSessionId = sessionId
            root.peakPosition = root.queuePosition
            return
        }
        if (root.queuePosition > root.peakPosition)
            root.peakPosition = root.queuePosition
    }

    // ───────────────────────── reusable pieces ─────────────────────────

    component MorphingText: Item {
        id: morph
        property string text: ""
        property color ink: DesktopTokens.textHigh
        property string family: DesktopTokens.bodyFont
        property int pixelSize: 14
        property int fontWeight: Font.DemiBold
        property real lineHeight: 1.0
        property int maximumLineCount: 3
        property real travel: 8
        property int horizontalAlignment: Text.AlignLeft
        property string contentObjectName: ""
        property string accessibleText: ""
        property string renderedText: ""
        property string outgoingText: ""
        property real blend: 1
        property bool initialized: false

        implicitHeight: Math.max(currentText.implicitHeight, outgoingTextItem.implicitHeight)
        height: implicitHeight
        Behavior on height { NumberAnimation { duration: Theme.duration(160); easing.type: Easing.OutCubic } }

        function transitionTo(value) {
            if (!morph.initialized) {
                morph.renderedText = value
                morph.blend = 1
                return
            }
            if (value === morph.renderedText)
                return
            textTransition.stop()
            morph.outgoingText = morph.renderedText
            morph.renderedText = value
            if (AppController.reducedMotion) {
                morph.blend = 1
                morph.outgoingText = ""
            } else {
                morph.blend = 0
                textTransition.start()
            }
        }

        onTextChanged: transitionTo(text)
        Component.onCompleted: {
            morph.renderedText = morph.text
            morph.blend = 1
            morph.initialized = true
        }

        NumberAnimation {
            id: textTransition
            target: morph
            property: "blend"
            from: 0
            to: 1
            duration: Theme.duration(220)
            easing.type: Easing.InOutCubic
            onFinished: morph.outgoingText = ""
        }
        Connections {
            target: AppController
            function onReducedMotionChanged() {
                if (AppController.reducedMotion) {
                    textTransition.stop()
                    morph.blend = 1
                    morph.outgoingText = ""
                }
            }
        }

        Text {
            id: outgoingTextItem
            width: morph.width
            text: morph.outgoingText
            visible: text !== "" && opacity > 0.001
            opacity: 1 - morph.blend
            color: morph.ink
            font.family: morph.family
            font.pixelSize: morph.pixelSize
            font.weight: morph.fontWeight
            lineHeight: morph.lineHeight
            horizontalAlignment: morph.horizontalAlignment
            wrapMode: Text.WordWrap
            maximumLineCount: morph.maximumLineCount
            elide: Text.ElideRight
            transform: Translate { y: -morph.blend * morph.travel }
        }
        Text {
            id: currentText
            objectName: morph.contentObjectName
            width: morph.width
            text: morph.renderedText
            visible: opacity > 0.001
            opacity: morph.blend
            color: morph.ink
            font.family: morph.family
            font.pixelSize: morph.pixelSize
            font.weight: morph.fontWeight
            lineHeight: morph.lineHeight
            horizontalAlignment: morph.horizontalAlignment
            wrapMode: Text.WordWrap
            maximumLineCount: morph.maximumLineCount
            elide: Text.ElideRight
            transform: Translate { y: (1 - morph.blend) * morph.travel }
            Accessible.role: Accessible.StaticText
            Accessible.name: morph.accessibleText !== "" ? morph.accessibleText : morph.renderedText
        }
    }

    // Inner surface: the same raised recipe the home page uses for rows.
    component GlassPanel: Rectangle {
        id: glass
        radius: 16
        color: DesktopTokens.raised
        border.width: 1
        border.color: DesktopTokens.seamSoft
    }

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property color tint: DesktopTokens.mint
        property bool showDot: false
        property real pulse: 0
        // Mint reads on dark panels; the light panel needs the deep variant.
        readonly property color ink: Theme.lightMode && tint === DesktopTokens.mint
            ? DesktopTokens.flightReady : tint
        implicitWidth: pillRow.implicitWidth + 26
        implicitHeight: 30
        radius: height / 2
        color: Qt.rgba(tint.r, tint.g, tint.b, Theme.lightMode ? 0.10 : 0.14)
        border.width: 1
        border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.35)
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8
            Item {
                visible: pill.showDot
                width: 10
                height: 10
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: 8 + pill.pulse * 10
                    height: width
                    radius: width / 2
                    color: pill.tint
                    opacity: 0.5 * (1 - pill.pulse)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: pill.ink
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.ink
                font.family: DesktopTokens.monoFont
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }
        }
    }

    component StatLine: Item {
        id: stat
        property string label: ""
        property string value: ""
        property color valueColor: DesktopTokens.textHigh
        height: 56
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: parent.height - 18
            radius: 1
            color: DesktopTokens.mint
        }
        Column {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                text: stat.label
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.monoFont
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1.3
            }
            Text {
                text: stat.value
                color: stat.valueColor
                font.family: DesktopTokens.monoFont
                font.pixelSize: 24
                font.weight: Font.Bold
            }
        }
    }

    component InfoTile: Rectangle {
        id: tile
        property string label: ""
        property string value: ""
        property color tint: DesktopTokens.mint
        property int maxLines: 2
        implicitHeight: Math.max(68, tileColumn.implicitHeight + 26)
        radius: 16
        color: DesktopTokens.raised
        border.width: 1
        border.color: DesktopTokens.seamSoft
        Column {
            id: tileColumn
            x: 16
            y: 13
            width: parent.width - 32
            spacing: 6
            Row {
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 2.5
                    color: tile.tint
                    Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                }
                Text {
                    text: tile.label
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.3
                }
            }
            Text {
                width: parent.width
                text: tile.value
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.bodyFont
                font.pixelSize: 13
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                maximumLineCount: tile.maxLines
                elide: Text.ElideRight
            }
        }
    }

    // ───────────────────────── animations ─────────────────────────

    NumberAnimation {
        id: entranceAnimation
        target: root
        property: "entranceProgress"
        from: 0
        to: 1
        duration: Theme.duration(900)
        easing.type: Easing.OutCubic
    }
    ParallelAnimation {
        id: positionPulse
        SequentialAnimation {
            NumberAnimation { target: positionBlock; property: "scale"; to: 0.985; duration: Theme.duration(90); easing.type: Easing.OutCubic }
            NumberAnimation { target: positionBlock; property: "scale"; to: 1; duration: Theme.duration(260); easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PropertyAction { target: ripple; property: "opacity"; value: 0.75 }
            PropertyAction { target: ripple; property: "scale"; value: 1 }
            ParallelAnimation {
                NumberAnimation { target: ripple; property: "scale"; to: 1.35; duration: Theme.duration(700); easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: Theme.duration(700); easing.type: Easing.OutCubic }
            }
        }
    }
    SequentialAnimation {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "breath"; from: 0; to: 1; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "breath"; from: 1; to: 0; duration: 2200; easing.type: Easing.InOutSine }
    }
    NumberAnimation {
        target: root; property: "spin"; from: 0; to: 360
        duration: 1500; loops: Animation.Infinite; running: root.animating && root.indeterminate
    }
    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion && root.motionReady) {
                entranceAnimation.stop()
                positionPulse.stop()
                root.entranceProgress = 1
                positionBlock.scale = 1
                ripple.opacity = 0
            }
        }
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

    onSessionChanged: root.synchronizePeakPosition()
    onQueuePositionChanged: {
        root.synchronizePeakPosition()
        if (root.motionReady && !AppController.reducedMotion) {
            positionPulse.stop()
            positionBlock.scale = 1
            positionPulse.start()
        }
    }
    onVisibleChanged: {
        if (visible) {
            root.queueVisibleSinceMs = Date.now()
            root.queueClockMs = root.queueVisibleSinceMs
            Qt.callLater(root.playEntrance)
        } else {
            entranceAnimation.stop()
            root.entranceProgress = 1
            root.artworkViewerOpen = false
        }
    }
    onArtworkViewerOpenChanged: if (root.visible) Qt.callLater(root.restoreFocus)
    Component.onCompleted: {
        root.synchronizePeakPosition()
        root.queueVisibleSinceMs = Date.now()
        root.queueClockMs = root.queueVisibleSinceMs
        root.motionReady = true
        Qt.callLater(root.playEntrance)
    }

    // ───────────────────────── backdrop ─────────────────────────

    Item {
        id: backdrop
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: DesktopTokens.shell }

        // The game's key art cropped edge to edge, exactly like the home
        // backdrop - no downsampled wash, no glow, no particles.
        Image {
            anchors.fill: parent
            source: coverArtwork.resolvedUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(1440, 900)
            smooth: true
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.duration(900) } }
        }

        // Theme-aware wash so the shell surfaces sit on a calmed backdrop,
        // the way the home rail and top bar tint their art.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b,
                Theme.lightMode ? 0.80 : 0.60)
        }
    }

    // ───────────────────────── content ─────────────────────────

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
            readonly property real margin: root.stacked ? 20 : 40
            width: Math.min(1260, Math.max(0, flick.width - 2 * margin))
            x: Math.max(margin, (flick.width - width) / 2)
            y: root.stacked ? (root.veryCompact ? 12 : 20) : Math.max(20, (flick.height - implicitHeight) / 2)
            height: implicitHeight
            columns: root.stacked ? 1 : 2
            columnSpacing: root.stacked ? 0 : root.compact ? 32 : 64
            rowSpacing: root.stacked ? 34 : 0
            verticalItemAlignment: Grid.AlignVCenter

            // ───── Left: floating cover ─────
            Item {
                id: artworkPanel
                readonly property real cardHeight: root.stacked ? 300
                    : Math.min(560, Math.max(340, flick.height - 190))
                readonly property real cardWidth: Math.min(width, cardHeight * 0.78)
                width: root.stacked ? layoutGrid.width
                    : Math.floor((layoutGrid.width - layoutGrid.columnSpacing) * (root.compact ? 0.30 : 0.38))
                height: artworkColumn.implicitHeight
                opacity: root.sectionOpacity(0)
                transform: Translate {
                    x: -root.sectionOffset(0, 32)
                    y: root.stacked ? queuePassPanel.height + layoutGrid.rowSpacing : 0
                }

                Column {
                    id: artworkColumn
                    width: artworkPanel.cardWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Rectangle {
                        id: artFrame
                        width: parent.width
                        height: artworkPanel.cardHeight
                        radius: 16
                        color: Theme.lightMode ? "#F0F3F8" : "#E617202D"
                        border.width: 1
                        border.color: artworkHover.hovered ? DesktopTokens.focus : DesktopTokens.cardOutlineIdle
                        Behavior on border.color { ColorAnimation { duration: Theme.focusDuration } }
                        clip: true

                        Image {
                            id: coverImage
                            anchors.fill: parent
                            anchors.margins: 12
                            source: coverArtwork.resolvedUrl
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(Math.max(1, Math.ceil(width * 2)), Math.max(1, Math.ceil(height * 2)))
                            opacity: status === Image.Ready ? 1 : 0
                            scale: status === Image.Ready ? 1 : 1.02
                            Behavior on opacity { NumberAnimation { duration: DesktopTokens.revealDuration } }
                            Behavior on scale { NumberAnimation { duration: Theme.duration(420); easing.type: Easing.OutCubic } }
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 48
                            visible: coverImage.status !== Image.Ready
                            text: String(root.game.title || qsTr("GeForce NOW"))
                            color: DesktopTokens.textHigh
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: 24
                            font.weight: Font.Black
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        HoverHandler {
                            id: artworkHover
                            enabled: coverImage.status === Image.Ready
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            enabled: coverImage.status === Image.Ready
                            onTapped: root.artworkViewerOpen = true
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            width: parent.width
                            text: String(root.game.title || qsTr("GeForce NOW"))
                            color: DesktopTokens.textHigh
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: 24
                            font.weight: Font.Black
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: root.gameSubtitle()
                            color: DesktopTokens.textMuted
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
                        text: qsTr("View artwork")
                        onClicked: root.artworkViewerOpen = true
                    }
                }
            }

            // ───── Right: mission control ─────
            // One shell panel with the home showcase card's surface recipe,
            // so the queue reads as part of the same app as the home page.
            Rectangle {
                id: queuePassPanel
                objectName: "desktopQueuePass"
                width: root.stacked ? layoutGrid.width
                    : layoutGrid.width - artworkPanel.width - layoutGrid.columnSpacing
                height: queuePass.implicitHeight + (root.veryCompact ? 46 : 56)
                radius: 24
                color: Theme.lightMode ? "#F2F5FA" : "#E60B1320"
                border.width: 1
                border.color: DesktopTokens.seam
                // On narrow screens, keep queue state and actions first. The
                // artwork remains available below them in the same flickable.
                transform: Translate {
                    y: root.stacked ? -artworkPanel.height - layoutGrid.rowSpacing : 0
                }

            Column {
                id: queuePass
                x: 28
                y: root.veryCompact ? 18 : 28
                width: parent.width - 56
                spacing: root.veryCompact ? 6 : root.compact ? 12 : 20

                // Eyebrow
                Flow {
                    width: parent.width
                    spacing: 10
                    opacity: root.sectionOpacity(0)
                    transform: Translate { y: root.sectionOffset(0, 12) }
                    Pill {
                        label: qsTr("STARTING SESSION")
                        showDot: true
                        pulse: root.breath
                    }
                    Pill {
                        label: root.regionText().toUpperCase()
                        tint: DesktopTokens.textMuted
                    }
                    Text {
                        visible: root.stacked
                        width: Math.min(implicitWidth, Math.max(120, parent.width - 320))
                        height: 30
                        text: String(root.game.title || qsTr("GeForce NOW"))
                        color: DesktopTokens.textHigh
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                // Headline + detail
                Column {
                    width: parent.width
                    spacing: 10
                    MorphingText {
                        width: parent.width
                        contentObjectName: "sessionQueueStatus"
                        text: root.statusText
                        ink: DesktopTokens.textHigh
                        family: DesktopTokens.displayFont
                        pixelSize: root.veryCompact ? 28 : root.compact ? 34 : 40
                        fontWeight: Font.Black
                        lineHeight: 1.05
                        maximumLineCount: 2
                        travel: 12
                        opacity: root.sectionOpacity(1)
                        transform: Translate { y: root.sectionOffset(1, 18) }
                    }
                    MorphingText {
                        width: parent.width
                        text: root.detailText
                        ink: DesktopTokens.textMuted
                        family: DesktopTokens.bodyFont
                        pixelSize: 15
                        lineHeight: 1.35
                        maximumLineCount: 3
                        travel: 7
                        opacity: root.sectionOpacity(1)
                        transform: Translate { y: root.sectionOffset(1, 14) }
                    }
                }

                // Hero: queue ring + stats
                GlassPanel {
                    id: positionBlock
                    objectName: "sessionQueuePositionBlock"
                    width: parent.width
                    height: heroFlow.implicitHeight + 44
                    opacity: root.sectionOpacity(2)
                    transformOrigin: Item.Center
                    transform: Translate { y: root.sectionOffset(2, 20) }

                    Flow {
                        id: heroFlow
                        x: 24
                        y: 22
                        width: parent.width - 48
                        spacing: 28

                        Item {
                            id: ringBox
                            width: root.ringSize
                            height: root.ringSize
                            readonly property real c: width / 2
                            readonly property real r: width / 2 - 22

                            Rectangle {
                                id: ripple
                                anchors.centerIn: parent
                                width: ringBox.width - 30
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: DesktopTokens.mint
                                opacity: 0
                            }

                            // track
                            Shape {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.samples: 4
                                ShapePath {
                                    strokeColor: DesktopTokens.seamSoft
                                    strokeWidth: 10
                                    fillColor: "transparent"
                                    PathAngleArc {
                                        centerX: ringBox.c; centerY: ringBox.c
                                        radiusX: ringBox.r; radiusY: ringBox.r
                                        startAngle: -90; sweepAngle: 359.9
                                    }
                                }
                            }

                            // progress
                            Item {
                                anchors.fill: parent
                                rotation: root.indeterminate ? root.spin : 0
                                Shape {
                                    anchors.fill: parent
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        strokeColor: DesktopTokens.mint
                                        strokeWidth: 10
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        PathAngleArc {
                                            centerX: ringBox.c; centerY: ringBox.c
                                            radiusX: ringBox.r; radiusY: ringBox.r
                                            startAngle: -90
                                            sweepAngle: root.indeterminate ? 100 : Math.max(2, 359.9 * root.shownProgress)
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: ringBox.width - 64
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: qsTr("YOUR PLACE")
                                    horizontalAlignment: Text.AlignHCenter
                                    color: DesktopTokens.textMuted
                                    font.family: DesktopTokens.monoFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.5
                                }
                                MorphingText {
                                    width: parent.width
                                    contentObjectName: "sessionQueuePosition"
                                    text: root.queuePosition > 0 ? String(root.queuePosition) : "—"
                                    accessibleText: root.statusText
                                    horizontalAlignment: Text.AlignHCenter
                                    ink: DesktopTokens.textHigh
                                    family: DesktopTokens.displayFont
                                    pixelSize: Math.round(ringBox.width * (root.queuePosition > 999 ? 0.24
                                        : root.queuePosition > 99 ? 0.30 : 0.38))
                                    fontWeight: Font.Black
                                    maximumLineCount: 1
                                    travel: 14
                                }
                                Text {
                                    width: parent.width
                                    text: root.aheadCaption()
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.mint
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Column {
                            id: statsColumn
                            readonly property real room: heroFlow.width - root.ringSize - heroFlow.spacing
                            width: room >= 190 ? room : heroFlow.width
                            anchors.verticalCenter: undefined
                            topPadding: room >= 190 ? Math.max(0, (root.ringSize - 3 * 56) / 2) : 0
                            StatLine {
                                width: parent.width
                                label: qsTr("QUEUE PROGRESS")
                                value: root.progressText()
                                valueColor: Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.mint
                            }
                            StatLine {
                                width: parent.width
                                label: qsTr("ELAPSED")
                                value: root.elapsedText()
                            }
                            StatLine {
                                width: parent.width
                                label: qsTr("BEST POSITION")
                                value: root.bestPositionText()
                            }
                        }
                    }
                }

                // Journey
                Column {
                    width: parent.width
                    spacing: 12
                    opacity: root.sectionOpacity(3)
                    transform: Translate { y: root.sectionOffset(3, 16) }

                    Text {
                        text: qsTr("WHAT HAPPENS NEXT")
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                    }

                    Item {
                        id: stepper
                        width: parent.width
                        height: 80
                        readonly property int currentStep: 1
                        readonly property real colW: width / 3

                        Rectangle {
                            id: trackLine
                            x: stepper.colW / 2
                            y: 13
                            width: stepper.colW * 2
                            height: 2
                            radius: 1
                            color: DesktopTokens.seam
                        }
                        Rectangle {
                            x: trackLine.x
                            y: 13
                            width: trackLine.width * 0.5
                            height: 2
                            radius: 1
                            color: DesktopTokens.mint
                        }
                        Repeater {
                            model: 3
                            delegate: Item {
                                id: step
                                required property int index
                                readonly property bool done: index < stepper.currentStep
                                readonly property bool active: index === stepper.currentStep
                                x: index * stepper.colW
                                width: stepper.colW
                                height: stepper.height

                                Rectangle {
                                    id: nodeBase
                                    x: (parent.width - width) / 2
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: DesktopTokens.raised
                                }
                                Rectangle {
                                    visible: step.active
                                    anchors.centerIn: nodeBase
                                    width: 28 + root.breath * 18
                                    height: width
                                    radius: width / 2
                                    color: DesktopTokens.mint
                                    opacity: 0.35 * (1 - root.breath)
                                }
                                Rectangle {
                                    anchors.fill: nodeBase
                                    radius: 14
                                    color: step.done ? DesktopTokens.mint
                                        : step.active ? Qt.rgba(DesktopTokens.mint.r, DesktopTokens.mint.g, DesktopTokens.mint.b, 0.16)
                                        : DesktopTokens.raised
                                    border.width: step.done || step.active ? 2 : 1
                                    border.color: step.done || step.active ? DesktopTokens.mint : DesktopTokens.seam
                                    Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: step.done ? "✓" : String(step.index + 1)
                                        color: step.done ? "#0A0D14"
                                            : step.active ? (Theme.lightMode ? DesktopTokens.flightReady : DesktopTokens.mint)
                                            : DesktopTokens.textMuted
                                        font.family: DesktopTokens.monoFont
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }
                                Text {
                                    y: 40
                                    width: parent.width - 12
                                    x: 6
                                    text: root.stepLabel(step.index)
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    color: step.active || step.done ? DesktopTokens.textHigh : DesktopTokens.textMuted
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: 12
                                    font.weight: step.active ? Font.ExtraBold : Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // Info tiles
                Grid {
                    id: tileGrid
                    visible: !root.stacked || root.height >= 680
                    width: parent.width
                    columns: root.compact && width >= 600 ? 4 : width >= 440 ? 2 : 1
                    columnSpacing: 12
                    rowSpacing: 12
                    opacity: root.sectionOpacity(4)
                    transform: Translate { y: root.sectionOffset(4, 16) }
                    readonly property real tileWidth: (width - (columns - 1) * columnSpacing) / columns

                    InfoTile {
                        width: tileGrid.tileWidth
                        label: qsTr("STREAM PROFILE")
                        value: root.streamProfileText()
                        maxLines: 1
                    }
                    InfoTile {
                        width: tileGrid.tileWidth
                        label: qsTr("REGION")
                        value: root.regionText()
                        maxLines: 1
                    }
                    InfoTile {
                        width: tileGrid.tileWidth
                        label: qsTr("QUEUE UPDATES")
                        value: root.activityText
                        tint: root.queueStalled ? DesktopTokens.amber : DesktopTokens.mint
                    }
                    InfoTile {
                        width: tileGrid.tileWidth
                        label: qsTr("SESSION DETAILS")
                        value: qsTr("Your session starts automatically")
                    }
                }

                // Stall banner
                Rectangle {
                    id: stallBanner
                    visible: root.queueStalled
                    width: parent.width
                    height: stallColumn.implicitHeight + 32
                    radius: 20
                    color: Qt.rgba(DesktopTokens.flightWarning.r, DesktopTokens.flightWarning.g, DesktopTokens.flightWarning.b, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(DesktopTokens.flightWarning.r, DesktopTokens.flightWarning.g, DesktopTokens.flightWarning.b, 0.45)
                    opacity: root.sectionOpacity(5)
                    Column {
                        id: stallColumn
                        x: 18
                        y: 16
                        width: parent.width - 36
                        spacing: 8
                        Text {
                            width: parent.width
                            text: qsTr("This is taking longer than usual")
                            color: DesktopTokens.flightWarning
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: 15
                            font.weight: Font.Black
                        }
                        Text {
                            width: parent.width
                            visible: root.requeueAvailable
                            text: qsTr("The queue has slowed down. You can keep waiting, or ask for a fresh rig.")
                            color: DesktopTokens.textMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }
                        DesktopButton {
                            id: requeueButton
                            objectName: "desktopQueueRequeue"
                            visible: root.queueStalled && root.requeueAvailable
                            enabled: !root.streamBusy && !root.requeueInProgress
                            primary: true
                            text: qsTr("Request a fresh rig")
                            onClicked: root.requeueRequested()
                        }
                    }
                }

                // Actions
                Flow {
                    width: parent.width
                    spacing: 10
                    opacity: root.sectionOpacity(5)
                    transform: Translate { y: root.sectionOffset(5, 14) }
                    DesktopButton {
                        objectName: "desktopQueueRefresh"
                        enabled: !root.streamBusy && !root.requeueInProgress
                        text: qsTr("Refresh status")
                        onClicked: root.refreshRequested()
                    }
                    DesktopButton {
                        id: cancelButton
                        objectName: "desktopQueueCancel"
                        enabled: !root.requeueInProgress
                        text: qsTr("Cancel session")
                        shortcutText: qsTr("Esc")
                        onClicked: root.cancelRequested()
                    }
                }
            }
            }
        }
    }

    // ───────────────────────── artwork viewer ─────────────────────────

    Rectangle {
        id: artworkViewer
        anchors.fill: parent
        z: 50
        visible: root.artworkViewerOpen || opacity > 0.001
        opacity: root.artworkViewerOpen ? 1 : 0
        color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.96)
        Behavior on opacity { NumberAnimation { duration: Theme.duration(220); easing.type: Easing.OutCubic } }
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("View artwork")

        MouseArea {
            anchors.fill: parent
            enabled: root.artworkViewerOpen
            onClicked: root.artworkViewerOpen = false
        }
        Image {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: parent.height * 0.78
            source: coverArtwork.resolvedUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            sourceSize: Qt.size(1600, 1600)
            scale: root.artworkViewerOpen ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.duration(320); easing.type: Easing.OutCubic } }
        }
        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 32
            width: parent.width - 64
            spacing: 4
            Text {
                width: parent.width
                text: String(root.game.title || qsTr("GeForce NOW"))
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.displayFont
                font.pixelSize: 24
                font.weight: Font.Black
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.gameSubtitle()
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
        DesktopButton {
            id: closeArtworkButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
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
