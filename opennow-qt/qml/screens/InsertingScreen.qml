import QtQuick
import QtQuick.Effects
import OpenNOW

FocusScope {
    id: root
    objectName: "consoleLaunchScreen"
    readonly property var game: ShellStore.selectedGame
        || ({ title: ShellStore.pendingLaunchParams && ShellStore.pendingLaunchParams.title || qsTr("GeForce NOW") })
    readonly property var session: ShellStore.activeSession
    readonly property var progress: ShellStore.sessionSetupProgress
    readonly property string phase: ShellStore.streamState
    readonly property bool failed: phase === "error" || phase === "failed"
    readonly property bool stopping: phase === "stopping"
    readonly property bool resuming: phase === "resuming" || Boolean(session && session.resumePending)
    readonly property bool queued: Boolean(session) && progress.queued
    readonly property int setupStep: session ? progress.setupStep : -1
    readonly property bool preparingStorage: setupStep === 5 || setupStep === 6
    readonly property int step: !session || resuming ? 1
        : queued || preparingStorage ? 2
        : setupStep >= 2 && setupStep <= 4 ? 3 : 1
    property int reachedStep: 1
    readonly property bool canRetry: phase === "error" && (ShellStore.pendingLaunchParams !== null
        || ShellStore.activeSession !== null || ShellStore.conflictSession !== null)
    readonly property bool leavesWithoutConfirmation: (phase === "error" || phase === "checking")
        && !session && ShellStore.streamCreateRequestId === "" && ShellStore.sessionClaimRequestId === ""
        && ShellStore.streamStopRequestId === ""
    readonly property double appearedAtMs: Date.now()
    readonly property var rigRows: {
        const rows = []
        const current = session || ({})
        if (current.gpuType) rows.push({label: qsTr("GPU"), value: String(current.gpuType)})
        if (current.serverLocation || current.zone) rows.push({label: qsTr("Zone"), value: String(current.serverLocation || current.zone)})
        const settings = ShellStore.settings || ({})
        const requested = [settings.resolution ? String(settings.resolution) : "",
            settings.fps ? qsTr("%1 FPS").arg(settings.fps) : ""].filter(part => part !== "").join(" · ")
        if (requested !== "") rows.push({label: qsTr("Requested"), value: requested})
        return rows
    }

    onStepChanged: if (!failed) reachedStep = step
    Component.onCompleted: {
        reachedStep = step
        if (failed)
            Qt.callLater(focusDefault)
        else
            forceActiveFocus()
    }
    onFailedChanged: Qt.callLater(focusDefault)

    function focusDefault() {
        if (!root.failed)
            root.forceActiveFocus()
        else if (retryButton.visible && retryButton.enabled)
            retryButton.forceActiveFocus()
        else
            backButton.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (event.isAutoRepeat)
            return
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            event.accepted = true
            if (!root.stopping)
                ShellStore.requestStreamExitConfirmation()
        }
    }

    SessionGlyphs { id: glyphs }

    LaunchStage {
        id: stage
        anchors.fill: parent
        game: root.game
        tone: root.failed ? Theme.coral : root.stopping ? Theme.textMuted : root.queued || root.preparingStorage ? Theme.yellow : Theme.focus
        statusText: root.failed ? qsTr("LINK SEVERED")
            : root.stopping ? qsTr("TERMINATING")
            : root.resuming ? qsTr("RECONNECTING")
            : root.queued ? qsTr("QUEUED — NODE BUSY")
            : root.setupStep === 5 ? qsTr("PURGE CYCLE")
            : root.setupStep === 6 ? qsTr("STORAGE SYNC")
            : root.step === 3 ? qsTr("RIG ONLINE")
            : qsTr("UPLINKING")
        eyebrow: root.failed ? qsTr("Link could not be established")
            : root.stopping ? qsTr("Ending session")
            : root.resuming ? qsTr("Your rig is still running")
            : qsTr("Initiating cyberlink")
        headline: root.failed ? qsTr("LINK FAILED")
            : root.stopping ? (ShellStore.conflictSession ? qsTr("Closing other session") : qsTr("Closing session"))
            : root.resuming ? qsTr("Rejacking in")
            : root.queued ? (root.progress.queuePosition > 0 ? qsTr("You're jacked in") : qsTr("Waiting for a rig"))
            : root.session ? root.progress.title
            : root.phase === "requesting" ? qsTr("Requesting a rig")
            : qsTr("Scanning nodes")
        detail: root.failed || root.stopping || root.resuming || !root.session
            ? I18n.source(ShellStore.streamMessage, I18n.revision)
            : root.queued ? qsTr("Hold position — your rig boots automatically. Keep the deck connected and stay in queue.")
            : root.progress.detail
        railVisible: !root.failed && !root.stopping
        activeStep: root.step
        activeStepDetail: root.queued ? qsTr("Live from GeForce NOW grid")
            : root.preparingStorage ? root.progress.title : ""
        waitStartedMs: root.failed || root.stopping ? 0 : root.appearedAtMs
        footerVisible: !root.failed && !root.stopping
        footerText: root.leavesWithoutConfirmation ? qsTr("Cancel")
            : root.queued ? qsTr("Leave queue…") : qsTr("Cancel…")
        copyWidth: root.failed ? 860 : 1060
        detailWidth: root.failed ? 780 : 880
        onFooterRequested: ShellStore.requestStreamExitConfirmation()

        actions: [
            LaunchStage.LaunchAction {
                id: retryButton
                objectName: "launchRetryButton"
                visible: root.canRetry
                enabled: !ShellStore.streamBusy
                primary: true
                text: qsTr("Retry jack-in")
                detail: qsTr("Same game, same settings")
                glyph: glyphs.button("A")
                keyboardGlyph: glyphs.keyboard
                KeyNavigation.down: backButton
                onClicked: ShellStore.retrySessionLaunch()
            },
            LaunchStage.LaunchAction {
                id: backButton
                objectName: "launchBackButton"
                visible: root.failed
                text: root.session ? qsTr("End session…") : qsTr("Back to %1").arg(String(root.game.title || qsTr("GeForce NOW")))
                glyph: glyphs.button("B")
                keyboardGlyph: glyphs.keyboard
                KeyNavigation.up: retryButton
                onClicked: ShellStore.requestStreamExitConfirmation()
            }
        ]

        aside: [
            // === CYBER QUEUE HOLOGRAM ===
            Item {
                anchors.fill: parent
                visible: !root.failed && root.queued && root.progress.queuePosition > 0

                // Holographic card with rotating border
                Item {
                    objectName: "launchQueueRing"
                    x: parent.width - width - 32
                    y: 12
                    width: 520; height: 620
                    Accessible.role: Accessible.StaticText
                    Accessible.name: qsTr("Queue position %1").arg(root.progress.queuePosition)

                    // Outer glow
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -8
                        radius: 18
                        color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.08)
                    }
                    // Main panel — dark glass with neon border
                    Rectangle {
                        id: holoPanel
                        anchors.fill: parent
                        radius: 16
                        color: Qt.rgba(0.02, 0.04, 0.10, 0.92)
                        border.width: 1.4
                        border.color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.42)
                        clip: true

                        // Scanlines inside
                        Canvas {
                            anchors.fill: parent
                            opacity: 0.06
                            onPaint: {
                                const ctx=getContext("2d"); ctx.reset(); ctx.strokeStyle="#FFFFFF"; ctx.lineWidth=1
                                for(let y=0;y<height;y+=4){ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(width,y); ctx.stroke()}
                            }
                        }
                        // Top bar — terminal header
                        Rectangle {
                            width: parent.width; height: 36; radius: 16
                            color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.12)
                            // keep bottom flat
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 16; color: parent.color }
                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Rectangle { width: 8; height: 8; radius: 4; color: "#FF3B30" }
                                Rectangle { width: 8; height: 8; radius: 4; color: "#FFE600" }
                                Rectangle { width: 8; height: 8; radius: 4; color: "#00FF9D" }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "GRID QUEUE // NODE BUSY"
                                color: Theme.focus
                                font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.4
                            }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                text: "LIVE"
                                color: "#FF3B30"
                                font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0
                            }
                        }
                        // Animated scanning line
                        Rectangle {
                            id: scanBeam
                            x: 1; width: parent.width - 2; height: 2
                            color: Theme.focus
                            opacity: 0.55
                            y: 42
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                running: visible && !AppController.reducedMotion
                                NumberAnimation { from: 42; to: holoPanel.height - 6; duration: 2400; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: holoPanel.height - 6; to: 42; duration: 2400; easing.type: Easing.InOutQuad }
                            }
                            Rectangle { anchors.fill: parent; color: "transparent"; layer.enabled: true }
                        }

                        // Content
                        Column {
                            x: 24
                            y: 56
                            width: parent.width - 48
                            spacing: 0
                            // Label row
                            Row {
                                spacing: 8
                                Rectangle { width: 2; height: 10; color: Theme.yellow; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: qsTr("POSITION IN GRID").toUpperCase()
                                    color: Theme.textMuted
                                    font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.6
                                }
                                Item { width: 6; height: 1 }
                                Rectangle { width: 28; height: 1; color: Theme.textMuted; opacity: 0.42; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Item { width: 1; height: 18 }
                            // HUGE number — cyber yellow with offset glitch duplicate
                            Item {
                                width: parent.width; height: 172
                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 2
                                    text: String(root.progress.queuePosition)
                                    color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.22)
                                    font.family: Theme.displayFont; font.pixelSize: root.progress.queuePosition > 9999 ? 108 : 152
                                    font.weight: Font.Black; font.letterSpacing: root.progress.queuePosition > 9999 ? -3 : -6
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: String(root.progress.queuePosition)
                                    color: Theme.yellow
                                    font.family: Theme.displayFont; font.pixelSize: root.progress.queuePosition > 9999 ? 108 : 152
                                    font.weight: Font.Black; font.letterSpacing: root.progress.queuePosition > 9999 ? -3 : -6
                                    style: Text.Outline; styleColor: Qt.rgba(0,0,0,0.42)
                                }
                                // Subtle scanline clip over number
                                Rectangle {
                                    x: 0; y: 72; width: parent.width; height: 1
                                    color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.24)
                                }
                            }
                            // Data grid — two cols
                            Item { width: 1; height: 14 }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.16) }
                            Item { width: 1; height: 14 }
                            Row {
                                width: parent.width
                                spacing: 16
                                Column {
                                    width: (parent.width - 16)/2 - 4
                                    spacing: 6
                                    Text { text: qsTr("EST. WAIT").toUpperCase(); color: Theme.textMuted; font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2 }
                                    Text { text: root.progress.etaLabel || qsTr("CALCULATING…"); color: Theme.label; font.family: Theme.monoFont; font.pixelSize: 13; font.weight: Font.Black }
                                    Text { text: qsTr("Syncs with GFN grid"); color: Theme.textMuted; font.family: Theme.monoFont; font.pixelSize: 9 }
                                }
                                Rectangle { width: 1; height: 48; color: Theme.neonSeam; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    width: (parent.width - 16)/2 - 4
                                    spacing: 6
                                    Text { text: qsTr("STATUS").toUpperCase(); color: Theme.textMuted; font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2 }
                                    Row { spacing: 6
                                        Rectangle { width: 7; height: 7; radius: 3.5; color: Theme.yellow; anchors.verticalCenter: parent.verticalCenter
                                            SequentialAnimation on opacity { running: true; loops: Animation.Infinite; NumberAnimation { to: 0.25; duration: 540 } NumberAnimation { to: 1; duration: 540 } }
                                        }
                                        Text { text: qsTr("HOLD POSITION"); color: Theme.yellow; font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                                    }
                                    Text { text: qsTr("Auto-boot on ready"); color: Theme.textMuted; font.family: Theme.monoFont; font.pixelSize: 9 }
                                }
                            }
                            Item { width: 1; height: 16 }
                            Rectangle { width: parent.width; height: 1; color: Theme.neonSeam; opacity: 0.6 }
                            Item { width: 1; height: 12 }
                            Text {
                                width: parent.width
                                text: qsTr("Your session auto-starts — keep the deck connected. Position live from NVIDIA grid.")
                                color: Theme.textMuted
                                font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.3
                                wrapMode: Text.WordWrap
                            }
                        }
                        // Corner brackets — cyber frame
                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                const ctx=getContext("2d"); ctx.reset()
                                ctx.strokeStyle=Theme.focus; ctx.lineWidth=1.6
                                const l=16, r=16, w=width, h=height
                                // TL
                                ctx.beginPath(); ctx.moveTo(1, r+l); ctx.lineTo(1, r); ctx.arc(r, r, r-1, Math.PI, 1.5*Math.PI); ctx.lineTo(r+l, 1); ctx.stroke()
                                // TR
                                ctx.beginPath(); ctx.moveTo(w - r - l, 1); ctx.lineTo(w - r, 1); ctx.arc(w - r, r, r-1, 1.5*Math.PI, 0); ctx.lineTo(w-1, r+l); ctx.stroke()
                                // BL
                                ctx.beginPath(); ctx.moveTo(1, h - r - l); ctx.lineTo(1, h - r); ctx.arc(r, h - r, r-1, Math.PI, 0.5*Math.PI); ctx.lineTo(r+l, h-1); ctx.stroke()
                                // BR
                                ctx.beginPath(); ctx.moveTo(w - r - l, h-1); ctx.lineTo(w - r, h-1); ctx.arc(w - r, h - r, r-1, 0.5*Math.PI, 0); ctx.lineTo(w-1, h - r - l); ctx.stroke()
                            }
                        }
                    }
                    // Floating data tags around the panel
                    Rectangle {
                        x: -10; y: 88; width: tag1.implicitWidth + 14; height: 22; radius: 6
                        color: Qt.rgba(0,0,0,0.72); border.width: 1; border.color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.32)
                        Text { id: tag1; anchors.centerIn: parent; text: "⟡ QUEUE NODE ACTIVE"; color: Theme.focus; font.family: Theme.monoFont; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                    }
                    Rectangle {
                        x: parent.width - (tag2.implicitWidth + 14) + 10; y: parent.height - 18; width: tag2.implicitWidth + 14; height: 20; radius: 6
                        color: Qt.rgba(0,0,0,0.72); border.width: 1; border.color: Theme.neonSeam
                        Text { id: tag2; anchors.centerIn: parent; text: "◈ " + String(root.game.title || "GRID").toUpperCase().slice(0,18); color: Theme.textMuted; font.family: Theme.monoFont; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 0.6 }
                    }
                }
            },
            LaunchStage.RigCard {
                x: parent.width - width - 32
                y: 20
                visible: !root.failed && root.step === 3 && rows.length > 0
                rows: root.rigRows
            },
            LaunchStage.StopCard {
                x: parent.width - width - 32
                y: 20
                visible: root.failed
                reachedStep: root.reachedStep
            }
        ]
    }
}
