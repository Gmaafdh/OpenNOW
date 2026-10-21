import QtQuick
import QtQuick.Effects
import OpenNOW

Item {
    id: root
    objectName: "launchStage"
    property var game: ({})
    readonly property var variant: game && game.variants && Number(game.selectedVariantIndex) >= 0
        ? (game.variants[Number(game.selectedVariantIndex)] || null) : null
    property string subtitle: [variant && variant.store ? DesktopTokens.storeLabel(variant.store) : "",
        String((ShellStore.activeSession || {}).serverLocation || ShellStore.selectedRegionName || "")]
        .filter(part => part !== "").join(" · ")
    property string statusText: ""
    property color tone: Theme.focus
    property string eyebrow: ""
    property string headline: ""
    property string detail: ""
    property color detailColor: Theme.textMuted
    property bool railVisible: false
    property int activeStep: 1
    property int failedStep: 0
    property string activeStepDetail: ""
    property bool activityRunning: true
    property double waitStartedMs: 0
    property string footerText: ""
    property string footerGlyph: "B"
    property bool footerVisible: footerText !== ""
    property real copyWidth: 1060
    property real detailWidth: 880
    readonly property real copyBottom: copy.y + (detailText.visible ? detailText.y + detailText.height : headlineText.y + headlineText.height)
    property alias aside: asideSlot.data
    property alias actions: actionColumn.data
    signal footerRequested()

    property double nowMs: Date.now()
    readonly property int waitedSeconds: waitStartedMs > 0 ? Math.max(0, Math.floor((nowMs - waitStartedMs) / 1000)) : 0
    readonly property string artwork: DesktopTokens.artworkUrl(game, true)
    readonly property string iconArtwork: DesktopTokens.decodeArtworkUrl(game && (game.boxArtUrl || game.imageUrl) || "")

    function clock(seconds) {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        return (hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") : String(minutes).padStart(2, "0"))
            + ":" + String(seconds % 60).padStart(2, "0")
    }

    function stepLabel(step) {
        if (step === 1) return qsTr("UPLINK REQUESTED")
        if (step === 2) return root.activeStep > 2 && root.failedStep !== 2 ? qsTr("RIG SECURED") : qsTr("QUEUED — AWAITING RIG")
        if (step === 3) return root.activeStep > 3 && root.failedStep !== 3 ? qsTr("RIG ONLINE") : qsTr("INITIALIZING RIG")
        return qsTr("ESTABLISHING STREAM")
    }

    // Keep API compatible — new cyber styling
    component LaunchAction: ConsoleActionButton {
        id: action
        property string detail: ""
        property bool keyboardGlyph: false
        width: 640
        implicitWidth: 640
        implicitHeight: detail !== "" ? 84 : 64
        cornerRadius: 12
        glyphSize: detail !== "" ? 30 : 28
        leftPadding: glyph === "" ? 24 : primary ? 16 : 18
        rightPadding: 24
        Accessible.description: detail
        // Override fill with cyber neon
        contentItem: Item {
            implicitWidth: actionRow.implicitWidth
            implicitHeight: actionRow.implicitHeight
            Row {
                id: actionRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                opacity: action.enabled ? 1 : 0.5
                ControllerGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: action.glyph !== ""
                    glyph: action.glyph
                    keyboard: action.keyboardGlyph
                    label: ""
                    glyphSize: action.glyphSize
                    glyphColor: action.primary ? Theme.faceText : action.danger ? Theme.coral : Theme.focus
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: Math.min(implicitWidth, action.availableWidth - (action.glyph !== "" ? action.glyphSize + 16 : 0))
                        text: action.text
                        elide: Text.ElideRight
                        color: action.inkColor
                        font.family: Theme.monoFont
                        font.pixelSize: action.detail === "" ? 15 : 15
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                    Text {
                        visible: action.detail !== ""
                        width: Math.min(implicitWidth, action.availableWidth - (action.glyph !== "" ? action.glyphSize + 16 : 0))
                        text: action.detail.toUpperCase()
                        elide: Text.ElideRight
                        color: action.primary ? Qt.rgba(Theme.faceText.r, Theme.faceText.g, Theme.faceText.b, 0.62) : Theme.textMuted
                        font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 1.1
                    }
                }
            }
        }
    }

    // CYBER INFO CARD — holographic panel with corner brackets
    component InfoCard: Rectangle {
        id: card
        property string title: ""
        property string footnote: ""
        property bool footnoteCode: false
        property bool divider: true
        property real padding: 28
        property real gap: 18
        property real footnoteSize: 12
        property real footnoteLineHeight: 17
        property real bodySpacing: 12
        default property alias content: cardBody.data
        width: 520
        height: cardColumn.implicitHeight + 2 * (padding + border.width + 6)
        radius: 14
        color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.88)
        border.width: 1
        border.color: Theme.neonSeam
        // outer glow
        layer.enabled: true
        // corner brackets
        Canvas {
            anchors.fill: parent
            opacity: 0.9
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = Theme.focus
                ctx.lineWidth = 1.6
                const r = parent.radius, w = width, h = height, l = 14
                // top-left
                ctx.beginPath(); ctx.moveTo(1, r+l); ctx.lineTo(1, r); ctx.arc(r, r, r-1, Math.PI, 1.5*Math.PI); ctx.lineTo(r+l, 1); ctx.stroke()
                // top-right
                ctx.beginPath(); ctx.moveTo(w - r - l, 1); ctx.lineTo(w - r, 1); ctx.arc(w - r, r, r-1, 1.5*Math.PI, 0); ctx.lineTo(w-1, r+l); ctx.stroke()
                // bottom-left
                ctx.beginPath(); ctx.moveTo(1, h - r - l); ctx.lineTo(1, h - r); ctx.arc(r, h - r, r-1, Math.PI, 0.5*Math.PI); ctx.lineTo(r + l, h-1); ctx.stroke()
                // bottom-right
                ctx.beginPath(); ctx.moveTo(w - r - l, h-1); ctx.lineTo(w - r, h-1); ctx.arc(w - r, h - r, r-1, 0.5*Math.PI, 0); ctx.lineTo(w-1, h - r - l); ctx.stroke()
            }
        }
        // scanline overlay
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            clip: true
            Canvas {
                anchors.fill: parent
                opacity: 0.04
                onPaint: {
                    const ctx=getContext("2d"); ctx.reset(); ctx.strokeStyle="#FFFFFF"; ctx.lineWidth=1
                    for(let y=0;y<height;y+=3){ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(width,y); ctx.stroke()}
                }
            }
        }
        Column {
            id: cardColumn
            x: card.padding + card.border.width
            y: card.padding + card.border.width
            width: card.width - 2 * x
            spacing: card.gap
            Row {
                width: parent.width
                spacing: 8
                Rectangle { width: 3; height: 14; radius: 1; color: Theme.focus; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: card.title.toUpperCase()
                    color: Theme.focus
                    font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.8
                }
            }
            Column { id: cardBody; width: parent.width; spacing: card.bodySpacing }
            Rectangle { visible: card.divider && card.footnote !== ""; width: parent.width; height: 1; color: Theme.neonSeam }
            Text {
                visible: card.footnote !== ""
                width: parent.width
                text: card.footnoteCode ? card.footnote.toUpperCase() : card.footnote
                wrapMode: Text.WordWrap
                color: Theme.textMuted
                font.family: Theme.monoFont
                font.pixelSize: card.footnoteSize
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }
        }
    }

    component RigCard: InfoCard {
        id: rigCard
        property var rows: []
        objectName: "launchRigCard"
        title: qsTr("Assigned Rig")
        footnote: qsTr("Live telemetry — values reported by session, never estimated.")
        visible: rows.length > 0
        Repeater {
            model: rigCard.rows
            Item {
                required property var modelData
                width: parent.width
                height: 28
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label.toUpperCase()
                    color: Theme.textMuted
                    font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.64)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: String(modelData.value).toUpperCase()
                    color: Theme.label
                    font.family: Theme.monoFont; font.pixelSize: 13; font.weight: Font.Black
                }
            }
        }
    }

    component StopCard: InfoCard {
        id: stopCard
        property int reachedStep: 1
        property string code: ""
        objectName: "launchStopCard"
        title: qsTr("Trace — Where it stopped")
        gap: 14
        bodySpacing: 14
        footnoteCode: true
        footnoteSize: 10
        footnoteLineHeight: 14
        footnote: code !== "" ? qsTr("CODE %1").arg(code) : ""
        Repeater {
            model: Math.min(4, stopCard.reachedStep + 1)
            Row {
                id: stopRow
                required property int index
                readonly property int step: index + 1
                readonly property bool failed: step === stopCard.reachedStep
                readonly property bool done: step < stopCard.reachedStep
                spacing: 12
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: stopRow.done ? Theme.mint : stopRow.failed ? Theme.coral : "transparent"
                    border.width: stopRow.done || stopRow.failed ? 0 : 1.4
                    border.color: Theme.neonSeam
                    Text {
                        anchors.centerIn: parent
                        visible: stopRow.done || stopRow.failed
                        text: stopRow.done ? "✓" : "✕"
                        color: Theme.contrastText(parent.color)
                        font.family: Theme.monoFont; font.pixelSize: 14; font.weight: Font.Black
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !stopRow.done && !stopRow.failed
                        text: String(stopRow.step)
                        color: Theme.textMuted
                        font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stepLabel(stopRow.step)
                    color: stopRow.failed ? Theme.coral : stopRow.done ? Theme.label : Theme.textMuted
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    font.weight: stopRow.failed || stopRow.done ? Font.Bold : Font.DemiBold
                    font.letterSpacing: 0.6
                }
            }
        }
    }

    Timer { id: clockTimer; interval: 1000; running: root.waitStartedMs > 0 && root.visible; repeat: true; onTriggered: root.nowMs = Date.now() }

    // === BACKGROUND — cyber void with grid & scanlines ===
    Rectangle { anchors.fill: parent; color: Theme.shellDeep }

    // Ambient artwork — heavily crushed to serve as texture
    ArtworkSource { id: cyberArt; sourceUrl: root.artwork; active: root.visible }
    Image {
        anchors.fill: parent
        source: cyberArt.resolvedUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        asynchronous: true
        opacity: status === Image.Ready ? 0.18 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.enterDuration } }
    }
    // Cyan / magenta duotone over artwork
    Rectangle {
        anchors.fill: parent
        opacity: cyberArt.resolvedUrl !== "" ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.12) }
            GradientStop { position: 0.6; color: Qt.rgba(Theme.mint.r, Theme.mint.g, Theme.mint.b, 0.06) }
            GradientStop { position: 1; color: Qt.rgba(0,0,0, 0.22) }
        }
    }
    // Grid
    Canvas {
        anchors.fill: parent
        opacity: 0.07
        onPaint: {
            const ctx=getContext("2d"); ctx.reset()
            const w=width,h=height
            ctx.strokeStyle=Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 1)
            ctx.lineWidth=1
            for(let x=0;x<w;x+=40){ ctx.beginPath(); ctx.moveTo(x+0.5,0); ctx.lineTo(x+0.5,h); ctx.stroke() }
            for(let y=0;y<h;y+=40){ ctx.beginPath(); ctx.moveTo(0,y+0.5); ctx.lineTo(w,y+0.5); ctx.stroke() }
        }
    }
    // Scanlines
    Canvas {
        anchors.fill: parent
        opacity: 0.06
        onPaint: {
            const ctx=getContext("2d"); ctx.reset()
            ctx.strokeStyle="#FFFFFF"; ctx.lineWidth=1
            for(let y=0;y<height;y+=4){ ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(width,y); ctx.stroke() }
        }
    }
    // Vignette
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(Theme.shellDeep.r, Theme.shellDeep.g, Theme.shellDeep.b, 0.88) }
            GradientStop { position: 0.52; color: Qt.rgba(Theme.shellDeep.r, Theme.shellDeep.g, Theme.shellDeep.b, 0.62) }
            GradientStop { position: 1; color: Qt.rgba(Theme.shellDeep.r, Theme.shellDeep.g, Theme.shellDeep.b, 0.84) }
        }
    }
    // Top neon hairline
    Rectangle { anchors.top: parent.top; width: parent.width; height: 2; color: Theme.focus; opacity: 0.9
        Rectangle { anchors.top: parent.top; anchors.topMargin: 2; width: parent.width; height: 8; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.11) }
    }
    // Bottom neon horizon glow
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.22) }
    // Perspective grid at bottom
    Canvas {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 220
        opacity: 0.18
        onPaint: {
            const ctx=getContext("2d"); ctx.reset()
            const w=width,h=height
            const accent=Theme.focus
            ctx.strokeStyle=Qt.rgba(accent.r,accent.g,accent.b,0.45); ctx.lineWidth=1
            for(let i=0;i<10;i++){ const t=i/9; const y=Math.pow(t,1.6)*h; ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke() }
            const vCount=24; const vanishX=w/2
            for(let i=0;i<=vCount;i++){ const xb=(w/vCount)*i; const xt=vanishX+(xb-vanishX)*0.04; ctx.beginPath(); ctx.moveTo(xt,0); ctx.lineTo(xb,h); ctx.stroke() }
        }
    }

    // === HEADER — game identity bar ===
    Item {
        id: headerBar
        x: 38; y: 18
        width: parent.width - 76
        height: 52

        // Left: game icon with neon frame
        Item {
            id: iconFrame
            width: 52; height: 52
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.92)
                border.width: 1.2
                border.color: Theme.neonSeam
            }
            // corner ticks
            Canvas { anchors.fill: parent; opacity: 0.85
                onPaint: { const ctx=getContext("2d"); ctx.reset(); ctx.strokeStyle=Theme.focus; ctx.lineWidth=1.6
                    const l=8; const paths=[[1,1,1,l],[1,1,l,1],[width-1,1,width-1,l],[width-1,1,width-l,1],[1,height-1,1,height-l],[1,height-1,l,height-1],[width-1,height-1,width-1,height-l],[width-1,height-1,width-l,height-1]]
                    for(const p of paths){ ctx.beginPath(); ctx.moveTo(p[0],p[1]); ctx.lineTo(p[2],p[3]); ctx.stroke() }
                }
            }
            Image {
                anchors.centerIn: parent
                width: 44; height: 44
                source: root.iconArtwork
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(88, 88)
                asynchronous: true
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: false }
            }
            Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border.width: 1; border.color: Qt.rgba(1,1,1,0.08) }
        }
        Column {
            x: iconFrame.width + 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                id: gameTitle
                width: Math.min(implicitWidth, parent.parent.width - iconFrame.width - 260)
                text: String(root.game && root.game.title || qsTr("GeForce NOW"))
                elide: Text.ElideRight
                color: Theme.label
                font.family: Theme.displayFont; font.pixelSize: 16; font.weight: Font.Black; font.letterSpacing: -0.3
            }
            Text {
                id: gameSubtitle
                visible: root.subtitle !== ""
                text: String(root.subtitle).toUpperCase()
                color: Theme.textMuted
                font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.0
            }
        }
        // Right: status chip — cyber pill with blinking LED
        Rectangle {
            objectName: "launchStatusChip"
            visible: root.statusText !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: statusRow.implicitWidth + 30; height: 32; radius: 8
            color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.48)
            Accessible.role: Accessible.StaticText
            Accessible.name: root.statusText
            // glow
            Rectangle { anchors.fill: parent; anchors.margins: -1; radius: parent.radius+1; color: "transparent"; border.width: 1; border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.18); visible: true }
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5; color: root.tone
                    SequentialAnimation on opacity { running: root.activityRunning && root.visible; loops: Animation.Infinite; NumberAnimation { to: 0.25; duration: 680 } NumberAnimation { to: 1; duration: 680 } }
                }
                Text {
                    text: root.statusText.toUpperCase()
                    color: root.tone
                    font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2
                }
            }
        }
    }

    SessionGlyphs { id: glyphs }

    // === COPY — headline with cyber treatment ===
    Item {
        id: copy
        objectName: "launchStageCopy"
        x: 48; y: 108
        width: Math.min(root.copyWidth, root.width - 860)
        // Eyebrow — terminal label with bracket
        Row {
            id: eyebrowRow
            spacing: 10
            visible: root.eyebrow !== ""
            Rectangle { width: 18; height: 2; radius: 1; color: root.tone; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: eyebrowText
                text: "[ " + root.eyebrow.toUpperCase() + " ]"
                color: root.tone
                font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 2.0
            }
            Rectangle { width: 18; height: 2; radius: 1; color: root.tone; anchors.verticalCenter: parent.verticalCenter; opacity: 0.42 }
        }
        Text {
            id: headlineText
            y: eyebrowRow.visible ? 26 : 0
            width: parent.width
            text: root.headline
            color: Theme.label
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.06
            font.family: Theme.displayFont; font.pixelSize: 62; font.weight: Font.Black; font.letterSpacing: -1.8
            Accessible.role: Accessible.Heading
            Accessible.name: text
            // Subtle neon glow behind text
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.18); blurMax: 22; shadowBlur: 0.9 }
        }
        // Accent underline
        Rectangle {
            y: headlineText.y + headlineText.height + 10
            width: 84; height: 3; radius: 1.5
            color: root.tone
            visible: root.headline !== ""
        }
        Text {
            id: detailText
            y: headlineText.y + headlineText.height + 26
            width: Math.min(parent.width, root.detailWidth)
            visible: root.detail !== ""
            text: root.detail
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            lineHeight: 1.45
            font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold
        }
    }

    Column {
        id: actionColumn
        objectName: "launchStageActions"
        x: 48; y: Math.max(copy.y + copy.height + 28, 420)
        width: 520
        spacing: 12
    }

    // === CYBER RAIL — horizontal neon timeline ===
    Item {
        objectName: "launchStageSteps"
        visible: root.railVisible
        x: 48
        y: Math.max(root.copyBottom + 28, 520)
        width: Math.min(720, root.width - 96)
        height: 72
        Accessible.role: Accessible.List
        Accessible.name: qsTr("Session steps")
        // Track line
        Rectangle {
            x: 22; y: 20
            width: parent.width - 44; height: 2; radius: 1
            color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.16)
        }
        Rectangle {
            x: 22; y: 20
            width: Math.max(0, (parent.width - 44) * Math.max(0, (root.activeStep - 1) / 3))
            height: 2; radius: 1
            color: root.tone
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; color: "transparent"
                layer.enabled: true
                Rectangle { anchors.fill: parent; color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.55); visible: false }
            }
        }
        Row {
            anchors.fill: parent
            spacing: 0
            Repeater {
                model: 4
                Item {
                    id: stepRow
                    required property int index
                    readonly property int step: index + 1
                    readonly property bool failed: root.failedStep === step
                    readonly property bool done: !failed && step < root.activeStep
                    readonly property bool current: !failed && step === root.activeStep
                    width: parent.width / 4
                    height: parent.height
                    Accessible.role: Accessible.ListItem
                    Accessible.name: root.stepLabel(step) + (done ? ", " + qsTr("done") : current ? ", " + qsTr("in progress") : failed ? ", " + qsTr("stopped here") : "")

                    // Node
                    Item {
                        x: (parent.width - 40)/2
                        y: 0
                        width: 40; height: 40
                        Rectangle {
                            anchors.centerIn: parent
                            width: 40; height: 40; radius: stepRow.current ? 8 : 20
                            rotation: stepRow.current ? 45 : 0
                            color: stepRow.done ? Theme.mint : stepRow.failed ? Theme.coral : stepRow.current ? Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.16) : Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.92)
                            border.width: stepRow.done || stepRow.failed ? 0 : 1.6
                            border.color: stepRow.current ? root.tone : Theme.neonSeam
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            Text {
                                anchors.centerIn: parent
                                rotation: stepRow.current ? -45 : 0
                                visible: !stepRow.current
                                text: stepRow.done ? "✓" : stepRow.failed ? "✕" : String(stepRow.step)
                                color: stepRow.done || stepRow.failed ? Theme.contrastText(stepRow.done ? Theme.mint : Theme.coral) : Theme.textMuted
                                font.family: Theme.monoFont; font.pixelSize: stepRow.done || stepRow.failed ? 13 : 11
                                font.weight: Font.Black
                            }
                            // pulsing dot when current
                            Rectangle {
                                anchors.centerIn: parent
                                width: 10; height: 10; radius: 2
                                rotation: 0
                                color: root.tone
                                visible: stepRow.current
                                SequentialAnimation on opacity { running: stepRow.current && root.activityRunning && root.visible; loops: Animation.Infinite; NumberAnimation { to: 0.18; duration: 620 } NumberAnimation { to: 1; duration: 620 } }
                            }
                        }
                        // rotating ring when current
                        Canvas {
                            anchors.fill: parent
                            visible: stepRow.current
                            rotation: 0
                            property color ink: root.tone
                            onPaint: {
                                const ctx=getContext("2d"); ctx.reset()
                                ctx.strokeStyle=ink; ctx.lineWidth=2; ctx.lineCap="round"
                                ctx.beginPath(); ctx.arc(width/2,height/2,width/2-2,-Math.PI/2,Math.PI*0.35); ctx.stroke()
                            }
                            RotationAnimator on rotation { from: 0; to: 360; duration: 1400; loops: Animation.Infinite; running: stepRow.current && root.activityRunning && root.visible && !AppController.reducedMotion }
                        }
                    }
                    Text {
                        x: 4; y: 48
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: root.stepLabel(stepRow.step)
                        color: stepRow.failed ? Theme.coral : stepRow.done || stepRow.current ? Theme.label : Theme.textMuted
                        font.family: Theme.monoFont
                        font.pixelSize: stepRow.current ? 10 : 9
                        font.weight: stepRow.current ? Font.Bold : Font.DemiBold
                        font.letterSpacing: 0.8
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: stepRow.current && root.activeStepDetail !== ""
                        x: 4; y: 68
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: root.activeStepDetail
                        color: Theme.textMuted
                        font.family: Theme.monoFont; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 0.6
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Item {
        id: asideSlot
        objectName: "launchStageAside"
        x: root.width - 860
        y: 108
        width: 780
        height: Math.max(0, root.height - y - 100)
    }

    // Wait timer — terminal style
    Row {
        visible: root.waitStartedMs > 0
        x: 48
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        spacing: 10
        Rectangle { width: 2; height: 14; color: Theme.textMuted; opacity: 0.5; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: ("SYS.UPTIME " + root.clock(root.waitedSeconds) + "  //  MEASURED ON DEVICE").toUpperCase()
            color: Theme.textMuted
            font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 1.0
        }
    }

    MouseArea {
        visible: root.footerVisible
        anchors.right: parent.right; anchors.rightMargin: 48
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        width: footerRow.implicitWidth + 16; height: 32
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: root.footerText
        Accessible.onPressAction: root.footerRequested()
        onClicked: root.footerRequested()
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Qt.rgba(Theme.coral.r, Theme.coral.g, Theme.coral.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(Theme.coral.r, Theme.coral.g, Theme.coral.b, 0.28)
        }
        Row {
            id: footerRow
            anchors.centerIn: parent
            spacing: 8
            ControllerGlyph {
                anchors.verticalCenter: parent.verticalCenter
                glyph: glyphs.button(root.footerGlyph)
                keyboard: glyphs.keyboard
                glyphColor: Theme.coral
                glyphSize: 20
                label: ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.footerText.toUpperCase()
                color: Theme.coral
                font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.8
            }
        }
    }
}
