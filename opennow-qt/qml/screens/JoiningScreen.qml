import QtQuick
import OpenNOW

FocusScope {
    id: root
    objectName: "consoleJoiningScreen"
    readonly property int connected: ControllerInput.controllers.length
    readonly property bool playerTwoReady: connected >= 2
    readonly property var game: ShellStore.selectedGame || ({ title: qsTr("GeForce NOW session") })

    Component.onCompleted: returnButton.forceActiveFocus()

    SessionGlyphs { id: glyphs }

    LaunchStage {
        anchors.fill: parent
        game: root.game
        tone: root.playerTwoReady ? Theme.jade : Theme.focus
        statusText: qsTr("%1 CONNECTED").arg(root.connected)
        eyebrow: qsTr("GRID CO-OP // LOCAL LINK")
        headline: root.playerTwoReady ? qsTr("Player two jacked in") : qsTr("Bring player two online")
        detail: root.playerTwoReady
            ? qsTr("Both decks routed with distinct player slots. Guide remains reserved for the grid overlay.")
            : qsTr("OpenNOW forwards up to four controllers directly to the active rig. Connect a second pad, then jack back to the game.")

        actions: [
            LaunchStage.LaunchAction {
                id: returnButton
                objectName: "joiningReturnButton"
                primary: root.playerTwoReady || !ShellStore.activeSession
                text: ShellStore.activeSession ? (root.playerTwoReady ? qsTr("Return to game") : qsTr("Return without p2")) : qsTr("Back to input")
                detail: root.playerTwoReady ? "" : qsTr("Updates the moment P2 connects.")
                glyph: glyphs.button("A")
                keyboardGlyph: glyphs.keyboard
                onClicked: AppController.navigate(ShellStore.activeSession ? "stream" : "controllers")
            }
        ]

        aside: [
            Column {
                x: Math.round((parent.width - width) / 2)
                width: 554
                spacing: 10
                Accessible.role: Accessible.List
                Accessible.name: qsTr("Controller slots")
                Repeater {
                    model: 4
                    Rectangle {
                        id: slotCard
                        required property int index
                        readonly property var controller: ControllerInput.controllers.length > index ? ControllerInput.controllers[index] : null
                        width: parent.width
                        height: 84
                        radius: 12
                        color: controller ? Qt.rgba(0.02, 0.05, 0.14, 0.92) : Qt.rgba(0.02, 0.04, 0.10, 0.52)
                        border.width: 1
                        border.color: controller ? (index===0 ? Theme.jade : Theme.focus) : Theme.neonSeam
                        Accessible.role: Accessible.ListItem
                        Accessible.name: controller ? qsTr("Player %1, %2").arg(index + 1).arg(controller.name)
                            : qsTr("Player %1, waiting for controller").arg(index + 1)
                        // corner brackets when active
                        Canvas {
                            anchors.fill: parent
                            visible: slotCard.controller !== null
                            opacity: 0.85
                            onPaint: {
                                const ctx=getContext("2d"); ctx.reset(); ctx.strokeStyle= slotCard.index===0 ? Theme.jade : Theme.focus; ctx.lineWidth=1.4
                                const l=10, r=12, w=width, h=height
                                ctx.beginPath(); ctx.moveTo(1, r+l); ctx.lineTo(1, r); ctx.arc(r, r, r-1, Math.PI, 1.5*Math.PI); ctx.lineTo(r+l,1); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(w - r - l,1); ctx.lineTo(w - r,1); ctx.arc(w - r,r,r-1,1.5*Math.PI,0); ctx.lineTo(w-1,r+l); ctx.stroke()
                            }
                        }
                        Rectangle {
                            x: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46; height: 46; radius: slotCard.controller ? 6 : 23
                            rotation: slotCard.controller ? 45 : 0
                            color: slotCard.controller ? (slotCard.index === 0 ? Theme.jade : Theme.focus) : "transparent"
                            border.width: slotCard.controller ? 0 : 1.4
                            border.color: Theme.neonSeam
                            Text {
                                anchors.centerIn: parent
                                rotation: slotCard.controller ? -45 : 0
                                text: "P" + (slotCard.index + 1)
                                color: slotCard.controller ? "#02040A" : Theme.textMuted
                                font.family: Theme.monoFont; font.pixelSize: 14; font.weight: Font.Black; font.letterSpacing: 0.8
                            }
                        }
                        Column {
                            x: 80
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80 - 90
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: slotCard.controller ? String(slotCard.controller.name).toUpperCase() : qsTr("AWAITING CONTROLLER")
                                color: slotCard.controller ? "#FFFFFF" : Theme.textMuted
                                font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Black; font.letterSpacing: 0.6
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: slotCard.controller ? qsTr("LINKED // READY") : qsTr("CONNECT OR WAKE PAD")
                                color: slotCard.controller ? Theme.textMuted : Qt.rgba(1,1,1,0.36)
                                font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.8
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            visible: slotCard.controller !== null && Number(slotCard.controller.batteryPercent) >= 0
                            width: battText.implicitWidth + 12; height: 22; radius: 6
                            color: Qt.rgba(0,0,0,0.42); border.width: 1; border.color: Theme.neonSeam
                            Text {
                                id: battText
                                anchors.centerIn: parent
                                text: slotCard.controller ? qsTr("%1%").arg(slotCard.controller.batteryPercent) : ""
                                color: slotCard.controller && Number(slotCard.controller.batteryPercent) <= 20 ? Theme.yellow : "#FFFFFF"
                                font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold
                            }
                        }
                    }
                }
            }
        ]
    }
}
