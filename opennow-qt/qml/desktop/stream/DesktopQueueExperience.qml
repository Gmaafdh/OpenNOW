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
    property real drift: 0         // 0..1..0 background drift
    property real floatPhase: 0.5  // 0..1..0 cover levitation
    property real spin: 0          // 0..360 fast spinner
    property real orbit: 0         // 0..360 slow orbit
    property real beam: 0          // 0..1 scan beam
    property real flowPhase: 0     // 0..1 timeline comet
    property int peakPosition: 0
    property string peakSessionId: ""

    signal cancelRequested()
    signal refreshRequested()
    signal requeueRequested()

    readonly property bool compact: height < 820
    readonly property bool veryCompact: height < 760
    readonly property bool stacked: width < 1000 || height < 650
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

    function accentA(alpha) {
        return Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, alpha)
    }

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
        property color ink: Theme.mediaForeground
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

    // Soft radial light used for ambience.
    component GlowBlob: Shape {
        id: blob
        property color tint: "white"
        property real strength: 0.3
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: blob.width / 2
                centerY: blob.height / 2
                centerRadius: Math.min(blob.width, blob.height) / 2
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0.0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.strength) }
                GradientStop { position: 0.55; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.strength * 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: blob.width; y: 0 }
            PathLine { x: blob.width; y: blob.height }
            PathLine { x: 0; y: blob.height }
            PathLine { x: 0; y: 0 }
        }
    }

    component GlassPanel: Rectangle {
        id: glass
        radius: 28
        border.width: 1
        border.color: "#2AFFFFFF"
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#20FFFFFF" }
            GradientStop { position: 1.0; color: "#08FFFFFF" }
        }
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: glass.radius
            anchors.rightMargin: glass.radius
            height: 1
            color: "#40FFFFFF"
        }
    }

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property color tint: Theme.mediaAccent
        property bool showDot: false
        property real pulse: 0
        implicitWidth: pillRow.implicitWidth + 26
        implicitHeight: 30
        radius: height / 2
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.14)
        border.width: 1
        border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.42)
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
                    color: pill.tint
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.tint
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
        property color valueColor: Theme.mediaForeground
        height: 56
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: parent.height - 18
            radius: 1
            color: Qt.rgba(stat.valueColor.r, stat.valueColor.g, stat.valueColor.b, 0.75)
        }
        Column {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                text: stat.label
                color: Theme.mediaMuted
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
        property color tint: Theme.mediaAccent
        property int maxLines: 2
        implicitHeight: Math.max(68, tileColumn.implicitHeight + 26)
        radius: 18
        color: "#10FFFFFF"
        border.width: 1
        border.color: "#1CFFFFFF"
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
                    color: Theme.mediaMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.3
                }
            }
            Text {
                width: parent.width
                text: tile.value
                color: Theme.mediaForeground
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
    SequentialAnimation {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "drift"; from: 0; to: 1; duration: 20000; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "drift"; from: 1; to: 0; duration: 20000; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "floatPhase"; from: 0; to: 1; duration: 3400; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "floatPhase"; from: 1; to: 0; duration: 3400; easing.type: Easing.InOutSine }
    }
    NumberAnimation {
        target: root; property: "spin"; from: 0; to: 360
        duration: 1500; loops: Animation.Infinite; running: root.animating && root.indeterminate
    }
    NumberAnimation {
        target: root; property: "orbit"; from: 0; to: 360
        duration: 48000; loops: Animation.Infinite; running: root.animating
    }
    SequentialAnimation {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "beam"; from: 0; to: 1; duration: 8000 }
        PauseAnimation { duration: 3500 }
    }
    NumberAnimation {
        target: root; property: "flowPhase"; from: 0; to: 1
        duration: 1800; loops: Animation.Infinite; easing.type: Easing.InOutQuad
        running: root.animating
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

    // ───────────────────────── ambient backdrop ─────────────────────────

    Item {
        id: backdrop
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: "#06080E" }

        // Artwork, downsampled hard and stretched => colour wash of the game's palette.
        Image {
            anchors.centerIn: parent
            width: parent.width * 1.3
            height: parent.height * 1.3
            source: coverArtwork.resolvedUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(48, 48)
            smooth: true
            asynchronous: true
            opacity: status === Image.Ready ? 0.55 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.duration(900) } }
            transform: Translate { x: (root.drift - 0.5) * 70; y: (0.5 - root.drift) * 30 }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#B0060810" }
                GradientStop { position: 0.55; color: "#D9060810" }
                GradientStop { position: 1.0; color: "#F5060810" }
            }
        }

        GlowBlob {
            x: parent.width - width * 0.62
            y: -height * 0.32
            width: Math.max(600, parent.width * 0.85)
            height: width
            tint: Theme.mediaAccent
            strength: 0.22 + root.breath * 0.07
        }
        GlowBlob {
            x: -width * 0.38
            y: parent.height - height * 0.62
            width: Math.max(520, parent.width * 0.7)
            height: width
            tint: Theme.mediaAccent
            strength: 0.14 + (1 - root.breath) * 0.06
        }

        // Faint scan beam
        Rectangle {
            visible: root.animating
            width: parent.width
            height: 200
            y: -height + root.beam * (parent.height + height)
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.accentA(0) }
                GradientStop { position: 0.5; color: root.accentA(0.06) }
                GradientStop { position: 1.0; color: root.accentA(0) }
            }
        }

        // Rising motes
        Repeater {
            model: 18
            delegate: Rectangle {
                id: mote
                required property int index
                readonly property real seed: ((index * 37) % 17) / 17
                readonly property real travelTime: 14000 + seed * 16000
                visible: root.animating
                width: 2 + (index % 3)
                height: width
                radius: width / 2
                x: ((index * 61) % 100) / 100 * backdrop.width
                color: index % 4 === 0 ? "#FFFFFF" : Theme.mediaAccent
                opacity: 0.10 + seed * 0.25
                SequentialAnimation on y {
                    running: root.animating
                    NumberAnimation {
                        from: backdrop.height * (1 - mote.seed)
                        to: -10
                        duration: Math.max(1, mote.travelTime * (1 - mote.seed))
                    }
                    SequentialAnimation {
                        loops: Animation.Infinite
                        NumberAnimation { from: backdrop.height + 10; to: -10; duration: mote.travelTime }
                    }
                }
            }
        }

        // Edge vignette
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#70000000" }
                GradientStop { position: 0.22; color: "#00000000" }
                GradientStop { position: 0.78; color: "#00000000" }
                GradientStop { position: 1.0; color: "#70000000" }
            }
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
                    y: root.stacked ? queuePass.height + layoutGrid.rowSpacing : 0
                }

                GlowBlob {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: artFrame.y + artFrame.height / 2 - height / 2
                    width: artworkPanel.cardWidth * 2
                    height: width
                    tint: Theme.mediaAccent
                    strength: 0.24 + root.breath * 0.12
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
                        radius: 26
                        color: "#0D1220"
                        border.width: 1
                        border.color: root.accentA(artworkHover.hovered ? 0.75 : 0.38)
                        Behavior on border.color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                        clip: true

                        readonly property real hx: artworkHover.hovered ? artworkHover.point.position.x / Math.max(1, width) : 0.5
                        readonly property real hy: artworkHover.hovered ? artworkHover.point.position.y / Math.max(1, height) : 0.5
                        property real tiltY: AppController.reducedMotion ? 0 : (hx - 0.5) * 14
                        property real tiltX: AppController.reducedMotion ? 0 : -(hy - 0.5) * 14
                        Behavior on tiltY { NumberAnimation { duration: Theme.duration(140); easing.type: Easing.OutCubic } }
                        Behavior on tiltX { NumberAnimation { duration: Theme.duration(140); easing.type: Easing.OutCubic } }

                        transform: [
                            Translate { y: AppController.reducedMotion ? 0 : (root.floatPhase - 0.5) * 12 },
                            Rotation {
                                origin.x: artFrame.width / 2
                                origin.y: artFrame.height / 2
                                axis { x: 0; y: 1; z: 0 }
                                angle: artFrame.tiltY
                            },
                            Rotation {
                                origin.x: artFrame.width / 2
                                origin.y: artFrame.height / 2
                                axis { x: 1; y: 0; z: 0 }
                                angle: artFrame.tiltX
                            }
                        ]

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
                            scale: status === Image.Ready
                                ? (artworkHover.hovered && !AppController.reducedMotion ? 1.03 : 1) : 1.05
                            Behavior on opacity { NumberAnimation { duration: DesktopTokens.revealDuration } }
                            Behavior on scale { NumberAnimation { duration: Theme.duration(420); easing.type: Easing.OutCubic } }
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 48
                            visible: coverImage.status !== Image.Ready
                            text: String(root.game.title || qsTr("GeForce NOW"))
                            color: Theme.mediaForeground
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: 24
                            font.weight: Font.Black
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        // Light sheen following the cursor
                        Rectangle {
                            width: parent.width * 0.55
                            height: parent.height * 1.8
                            anchors.verticalCenter: parent.verticalCenter
                            x: artFrame.hx * parent.width - width / 2
                            rotation: 16
                            opacity: artworkHover.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.duration(220) } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#00FFFFFF" }
                                GradientStop { position: 0.5; color: "#1EFFFFFF" }
                                GradientStop { position: 1.0; color: "#00FFFFFF" }
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 16
                            width: viewHint.implicitWidth + 24
                            height: 28
                            radius: 14
                            color: "#CC0A0D14"
                            border.width: 1
                            border.color: root.accentA(0.5)
                            opacity: artworkHover.hovered && coverImage.status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.duration(180) } }
                            Text {
                                id: viewHint
                                anchors.centerIn: parent
                                text: qsTr("VIEW")
                                color: Theme.mediaAccent
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
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
                            color: Theme.mediaForeground
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

            // ───── Right: mission control ─────
            Column {
                id: queuePass
                objectName: "desktopQueuePass"
                width: root.stacked ? layoutGrid.width
                    : layoutGrid.width - artworkPanel.width - layoutGrid.columnSpacing
                spacing: root.veryCompact ? 6 : root.compact ? 12 : 20
                // On narrow screens, keep queue state and actions first. The
                // artwork remains available below them in the same flickable.
                transform: Translate {
                    y: root.stacked ? -artworkPanel.height - layoutGrid.rowSpacing : 0
                }

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
                        tint: Theme.mediaMuted
                    }
                    Text {
                        visible: root.stacked
                        width: Math.min(implicitWidth, Math.max(120, parent.width - 320))
                        height: 30
                        text: String(root.game.title || qsTr("GeForce NOW"))
                        color: Theme.mediaForeground
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
                        ink: Theme.mediaForeground
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
                        ink: Theme.mediaMuted
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
                            readonly property real tipAngle: (-90 + 360 * root.shownProgress) * Math.PI / 180

                            GlowBlob {
                                anchors.centerIn: parent
                                width: parent.width * 1.6
                                height: width
                                tint: Theme.mediaAccent
                                strength: 0.12 + root.breath * 0.10
                            }

                            Rectangle {
                                id: ripple
                                anchors.centerIn: parent
                                width: ringBox.width - 30
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: Theme.mediaAccent
                                opacity: 0
                            }

                            // slow dotted orbit
                            Item {
                                anchors.fill: parent
                                rotation: root.orbit
                                Shape {
                                    anchors.fill: parent
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        strokeColor: "#38FFFFFF"
                                        strokeWidth: 1.5
                                        strokeStyle: ShapePath.DashLine
                                        dashPattern: [1, 6]
                                        fillColor: "transparent"
                                        PathAngleArc {
                                            centerX: ringBox.c; centerY: ringBox.c
                                            radiusX: ringBox.c - 3; radiusY: ringBox.c - 3
                                            startAngle: 0; sweepAngle: 359.9
                                        }
                                    }
                                }
                            }

                            // track
                            Shape {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.samples: 4
                                ShapePath {
                                    strokeColor: "#18FFFFFF"
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
                                        strokeColor: root.accentA(0.22)
                                        strokeWidth: 20
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        PathAngleArc {
                                            centerX: ringBox.c; centerY: ringBox.c
                                            radiusX: ringBox.r; radiusY: ringBox.r
                                            startAngle: -90
                                            sweepAngle: root.indeterminate ? 100 : Math.max(2, 359.9 * root.shownProgress)
                                        }
                                    }
                                    ShapePath {
                                        strokeColor: Theme.mediaAccent
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

                            // glowing tip
                            Rectangle {
                                visible: !root.indeterminate
                                width: 14
                                height: 14
                                radius: 7
                                x: ringBox.c + ringBox.r * Math.cos(ringBox.tipAngle) - 7
                                y: ringBox.c + ringBox.r * Math.sin(ringBox.tipAngle) - 7
                                color: "#FFFFFF"
                                border.width: 3
                                border.color: root.accentA(0.55)
                            }

                            Column {
                                anchors.centerIn: parent
                                width: ringBox.width - 64
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: qsTr("YOUR PLACE")
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Theme.mediaMuted
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
                                    ink: Theme.mediaForeground
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
                                    color: Theme.mediaAccent
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
                                valueColor: Theme.mediaAccent
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
                        color: Theme.mediaMuted
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
                            color: "#24FFFFFF"
                        }
                        Rectangle {
                            x: trackLine.x
                            y: 13
                            width: trackLine.width * 0.5
                            height: 2
                            radius: 1
                            color: Theme.mediaAccent
                        }
                        Rectangle {
                            visible: root.animating
                            readonly property real segment: trackLine.width * 0.5
                            width: 44
                            height: 4
                            radius: 2
                            y: 12
                            x: trackLine.x + segment + root.flowPhase * (segment - width)
                            opacity: 1 - Math.abs(root.flowPhase * 2 - 1)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: root.accentA(0) }
                                GradientStop { position: 1.0; color: root.accentA(1) }
                            }
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
                                    color: "#0B0F18"
                                }
                                Rectangle {
                                    visible: step.active
                                    anchors.centerIn: nodeBase
                                    width: 28 + root.breath * 18
                                    height: width
                                    radius: width / 2
                                    color: Theme.mediaAccent
                                    opacity: 0.35 * (1 - root.breath)
                                }
                                Rectangle {
                                    anchors.fill: nodeBase
                                    radius: 14
                                    color: step.done ? Theme.mediaAccent
                                        : step.active ? root.accentA(0.2) : "#0DFFFFFF"
                                    border.width: step.done || step.active ? 2 : 1
                                    border.color: step.done || step.active ? Theme.mediaAccent : "#40FFFFFF"
                                    Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: step.done ? "✓" : String(step.index + 1)
                                        color: step.done ? "#0A0D14" : step.active ? Theme.mediaAccent : Theme.mediaMuted
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
                                    color: step.active || step.done ? Theme.mediaForeground : Theme.mediaMuted
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
                        tint: root.queueStalled ? DesktopTokens.amber : Theme.mediaAccent
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
                    color: Qt.rgba(DesktopTokens.amber.r, DesktopTokens.amber.g, DesktopTokens.amber.b, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(DesktopTokens.amber.r, DesktopTokens.amber.g, DesktopTokens.amber.b, 0.5)
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
                            color: DesktopTokens.amber
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: 15
                            font.weight: Font.Black
                        }
                        Text {
                            width: parent.width
                            visible: root.requeueAvailable
                            text: qsTr("The queue has slowed down. You can keep waiting, or ask for a fresh rig.")
                            color: Theme.mediaMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }
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

    // ───────────────────────── artwork viewer ─────────────────────────

    Rectangle {
        id: artworkViewer
        anchors.fill: parent
        z: 50
        visible: root.artworkViewerOpen || opacity > 0.001
        opacity: root.artworkViewerOpen ? 1 : 0
        color: "#F2060810"
        Behavior on opacity { NumberAnimation { duration: Theme.duration(220); easing.type: Easing.OutCubic } }
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("View artwork")

        GlowBlob {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 1.5
            height: width
            tint: Theme.mediaAccent
            strength: 0.16
        }

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
                color: Theme.mediaForeground
                font.family: DesktopTokens.displayFont
                font.pixelSize: 24
                font.weight: Font.Black
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.gameSubtitle()
                color: Theme.mediaMuted
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
