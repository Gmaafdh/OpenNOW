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

    signal cancelRequested()
    signal refreshRequested()
    signal requeueRequested()

    readonly property bool compact: height < 820
    readonly property bool veryCompact: height < 700
    readonly property color cardInk: Theme.mediaForeground
    readonly property color cardMuted: Theme.mediaMuted
    readonly property color cardAccent: Theme.mediaAccent
    readonly property color cardSoft: "#12FFFFFF"
    readonly property color cardSurface: "#E60B1422"

    Accessible.role: Accessible.Pane
    Accessible.name: root.statusText

    function restoreFocus() {
        cancelButton.forceActiveFocus()
    }

    function stepLabel(index) {
        if (index === 0) return qsTr("Session requested")
        if (index === 1) return qsTr("Waiting for a rig")
        return qsTr("Connecting the stream")
    }

    Item {
        id: layout
        anchors.fill: parent
        anchors.margins: DesktopTokens.px(root.veryCompact ? 22 : 38)
        anchors.topMargin: DesktopTokens.px(root.veryCompact ? 72 : 96)
        anchors.bottomMargin: DesktopTokens.px(root.veryCompact ? 20 : 36)

        Column {
            id: story
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(DesktopTokens.px(250), parent.width - queuePass.width - DesktopTokens.px(54))
            spacing: 0

            Row {
                spacing: DesktopTokens.px(10)
                height: DesktopTokens.px(24)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(7)
                    height: width
                    radius: width / 2
                    color: Theme.mediaAccent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("STARTING SESSION")
                    color: Theme.mediaAccent
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.px(11)
                    font.weight: Font.Bold
                    font.letterSpacing: DesktopTokens.px(1.8)
                }
            }
            Item { width: 1; height: DesktopTokens.px(root.veryCompact ? 12 : 20) }
            Text {
                width: parent.width
                text: String(root.game.title || qsTr("GeForce NOW"))
                color: Theme.mediaForeground
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.px(root.veryCompact ? 32 : root.compact ? 42 : 54)
                font.weight: Font.Black
                font.letterSpacing: -DesktopTokens.px(1.4)
                lineHeight: 1.02
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }
            Item { width: 1; height: DesktopTokens.px(root.veryCompact ? 14 : 24) }
            Text {
                objectName: "sessionQueueStatus"
                width: parent.width
                text: root.statusText
                color: Theme.mediaForeground
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.px(root.veryCompact ? 19 : 26)
                font.weight: Font.ExtraBold
                font.letterSpacing: -DesktopTokens.px(0.35)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Item { width: 1; height: DesktopTokens.px(8) }
            Text {
                width: parent.width
                text: root.detailText
                color: Theme.mediaMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.px(14)
                lineHeight: 1.4
                wrapMode: Text.WordWrap
                maximumLineCount: root.veryCompact ? 3 : 4
                elide: Text.ElideRight
            }
            Item { width: 1; height: DesktopTokens.px(root.veryCompact ? 16 : 24) }
            Rectangle {
                width: parent.width
                height: DesktopTokens.px(78)
                radius: DesktopTokens.px(16)
                color: "#0DFFFFFF"
                border.width: 1
                border.color: "#1FFFFFFF"
                visible: !root.veryCompact
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: DesktopTokens.px(12)
                    width: DesktopTokens.px(3)
                    radius: width / 2
                    color: Theme.mediaAccent
                }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: DesktopTokens.px(22)
                    anchors.rightMargin: DesktopTokens.px(16)
                    spacing: DesktopTokens.px(12)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(36)
                        height: width
                        radius: width / 2
                        color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.28)
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: Theme.mediaAccent
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: DesktopTokens.px(18)
                            font.weight: Font.Black
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - DesktopTokens.px(48)
                        spacing: DesktopTokens.px(3)
                        Text {
                            text: qsTr("You can relax")
                            color: Theme.mediaForeground
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: DesktopTokens.px(15)
                            font.weight: Font.ExtraBold
                        }
                        Text {
                            width: parent.width
                            text: qsTr("We'll take it from here. Your game opens automatically when your rig is ready.")
                            color: Theme.mediaMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: DesktopTokens.px(12)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            Item {
                width: 1
                height: DesktopTokens.px(root.veryCompact ? 16 : 24)
                visible: !root.veryCompact
            }
            Flow {
                width: parent.width
                spacing: DesktopTokens.px(10)
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

        Rectangle {
            anchors.right: queuePass.right
            anchors.verticalCenter: queuePass.verticalCenter
            anchors.rightMargin: -DesktopTokens.px(30)
            width: queuePass.width + DesktopTokens.px(60)
            height: queuePass.height + DesktopTokens.px(60)
            radius: DesktopTokens.px(44)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.10)
            visible: !root.veryCompact
        }

        Rectangle {
            id: queuePass
            objectName: "desktopQueuePass"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(DesktopTokens.px(420), parent.width * 0.42)
            height: Math.min(parent.height, DesktopTokens.px(root.veryCompact ? 430 : root.compact ? 500 : 560))
            radius: DesktopTokens.px(32)
            color: root.cardSurface
            border.width: 1
            border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.28)
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: DesktopTokens.px(3)
                color: root.cardAccent
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -DesktopTokens.px(72)
                anchors.topMargin: -DesktopTokens.px(84)
                width: DesktopTokens.px(230)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: DesktopTokens.px(26)
                border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.045)
            }
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: -DesktopTokens.px(110)
                anchors.bottomMargin: -DesktopTokens.px(120)
                width: DesktopTokens.px(260)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: "#0EFFFFFF"
            }

            Column {
                id: passContent
                x: DesktopTokens.px(root.veryCompact ? 18 : root.compact ? 22 : 28)
                y: DesktopTokens.px(root.veryCompact ? 18 : root.compact ? 22 : 28)
                width: parent.width - 2 * x
                spacing: DesktopTokens.px(root.veryCompact ? 8 : 11)

                Item {
                    width: parent.width
                    height: DesktopTokens.px(28)
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("ALLOCATION CONSOLE")
                        color: root.cardInk
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.px(10)
                        font.weight: Font.Bold
                        font.letterSpacing: DesktopTokens.px(1.35)
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: liveRow.implicitWidth + DesktopTokens.px(16)
                        height: DesktopTokens.px(26)
                        radius: height / 2
                        color: root.cardSoft
                        border.width: 1
                        border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.20)
                        Row {
                            id: liveRow
                            anchors.centerIn: parent
                            spacing: DesktopTokens.px(6)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: DesktopTokens.px(6)
                                height: width
                                radius: width / 2
                                color: root.cardAccent
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: root.visible && !AppController.reducedMotion
                                    NumberAnimation { to: 0.3; duration: 700 }
                                    NumberAnimation { to: 1; duration: 700 }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("LIVE")
                                color: root.cardAccent
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: DesktopTokens.px(9)
                                font.weight: Font.Bold
                                font.letterSpacing: DesktopTokens.px(1)
                            }
                        }
                    }
                }

                Text {
                    text: qsTr("YOUR PLACE IN LINE")
                    color: root.cardMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.px(10)
                    font.weight: Font.Bold
                    font.letterSpacing: DesktopTokens.px(1.4)
                }

                Item {
                    id: orbit
                    width: parent.width
                    height: DesktopTokens.px(root.veryCompact ? 118 : root.compact ? 154 : 190)
                    readonly property real ringDiameter: Math.min(height - DesktopTokens.px(8), width - DesktopTokens.px(20))

                    Rectangle {
                        anchors.centerIn: parent
                        width: orbit.ringDiameter
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.28)
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: orbit.ringDiameter * 0.78
                        height: width
                        radius: width / 2
                        color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.035)
                        border.width: 1
                        border.color: "#16FFFFFF"
                    }
                    Item {
                        anchors.centerIn: parent
                        width: orbit.ringDiameter
                        height: width
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 18000
                            loops: Animation.Infinite
                            running: root.visible && !AppController.reducedMotion
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -DesktopTokens.px(4)
                            width: DesktopTokens.px(8)
                            height: width
                            radius: width / 2
                            color: root.cardAccent
                            border.width: 1
                            border.color: Theme.mediaForeground
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: DesktopTokens.px(2)
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.queuePosition > 0 ? String(root.queuePosition) : "—"
                            color: root.cardInk
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: DesktopTokens.px(root.queuePosition > 999
                                ? (root.veryCompact ? 54 : 76) : (root.veryCompact ? 68 : root.compact ? 88 : 108))
                            font.weight: Font.Black
                            font.letterSpacing: -DesktopTokens.px(4)
                            Accessible.role: Accessible.StaticText
                            Accessible.name: root.statusText
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("IN QUEUE")
                            color: root.cardAccent
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: DesktopTokens.px(9)
                            font.weight: Font.Bold
                            font.letterSpacing: DesktopTokens.px(1.6)
                        }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Your session starts automatically")
                    color: root.cardMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.px(12)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#18FFFFFF"
                }

                Item {
                    width: parent.width
                    height: stepColumn.implicitHeight
                    Rectangle {
                        x: DesktopTokens.px(10)
                        y: DesktopTokens.px(16)
                        width: 1
                        height: Math.max(0, parent.height - DesktopTokens.px(32))
                        color: "#24FFFFFF"
                    }
                    Column {
                        id: stepColumn
                        width: parent.width
                        spacing: DesktopTokens.px(4)
                        Repeater {
                            model: 3
                            delegate: Item {
                                id: step
                                required property int index
                                width: parent.width
                                height: DesktopTokens.px(root.veryCompact ? 28 : 34)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: DesktopTokens.px(21)
                                height: width
                                radius: width / 2
                                color: step.index === 1 ? Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.16) : "#0BFFFFFF"
                                border.width: 1
                                border.color: step.index === 1 ? root.cardAccent : "#38FFFFFF"
                                Text {
                                    anchors.centerIn: parent
                                    text: step.index === 0 ? "✓" : String(step.index + 1)
                                    color: step.index === 1 ? root.cardAccent : step.index === 0 ? root.cardInk : root.cardMuted
                                    font.family: step.index === 0 ? DesktopTokens.bodyFont : DesktopTokens.monoFont
                                    font.pixelSize: DesktopTokens.px(10)
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: DesktopTokens.px(36)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.stepLabel(step.index)
                                color: step.index === 2 ? root.cardMuted : root.cardInk
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: DesktopTokens.px(12)
                                font.weight: step.index === 1 ? Font.ExtraBold : Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: step.index === 1
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("NOW")
                                color: root.cardAccent
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: DesktopTokens.px(9)
                                font.weight: Font.Bold
                                font.letterSpacing: DesktopTokens.px(1)
                            }
                        }
                    }
                }
                }

            }

            Rectangle {
                x: passContent.x
                width: parent.width - 2 * x
                anchors.bottom: parent.bottom
                anchors.bottomMargin: passContent.y
                height: DesktopTokens.px(50)
                radius: DesktopTokens.px(14)
                color: root.cardSoft
                border.width: 1
                border.color: "#16FFFFFF"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: DesktopTokens.px(14)
                    anchors.rightMargin: DesktopTokens.px(14)
                    spacing: DesktopTokens.px(10)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(7)
                        height: width
                        radius: width / 2
                        color: root.queueStalled ? DesktopTokens.amber : root.cardAccent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - DesktopTokens.px(17)
                        text: root.activityText
                        color: root.cardInk
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.px(11)
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
