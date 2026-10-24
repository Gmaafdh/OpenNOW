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
    readonly property color cardInk: "#14251F"
    readonly property color cardMuted: "#5B6961"
    readonly property color cardAccent: "#286548"
    readonly property color cardSoft: "#E5EAE1"

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
                font.pixelSize: DesktopTokens.px(root.veryCompact ? 32 : root.compact ? 40 : 50)
                font.weight: Font.Black
                font.letterSpacing: -DesktopTokens.px(1.2)
                lineHeight: 1.04
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
                font.pixelSize: DesktopTokens.px(root.veryCompact ? 19 : 25)
                font.weight: Font.ExtraBold
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
                height: DesktopTokens.px(76)
                radius: DesktopTokens.px(18)
                color: "#14FFFFFF"
                border.width: 1
                border.color: "#1FFFFFFF"
                visible: !root.veryCompact
                Row {
                    anchors.fill: parent
                    anchors.margins: DesktopTokens.px(16)
                    spacing: DesktopTokens.px(14)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(40)
                        height: width
                        radius: width / 2
                        color: Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: Theme.mediaAccent
                            font.family: DesktopTokens.displayFont
                            font.pixelSize: DesktopTokens.px(20)
                            font.weight: Font.Black
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - DesktopTokens.px(54)
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
            anchors.rightMargin: -DesktopTokens.px(34)
            width: queuePass.width + DesktopTokens.px(68)
            height: queuePass.height + DesktopTokens.px(68)
            radius: DesktopTokens.px(42)
            color: "transparent"
            border.width: 1
            border.color: "#12FFFFFF"
            visible: !root.veryCompact
        }

        Rectangle {
            id: queuePass
            objectName: "desktopQueuePass"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(DesktopTokens.px(400), parent.width * 0.42)
            height: Math.min(parent.height, DesktopTokens.px(root.veryCompact ? 410 : root.compact ? 540 : 610))
            radius: DesktopTokens.px(30)
            color: "#F4F3EB"
            border.width: 1
            border.color: "#FFFFFFFF"
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: DesktopTokens.px(5)
                color: root.cardAccent
            }
            CircleAccent {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -DesktopTokens.px(60)
                anchors.topMargin: -DesktopTokens.px(72)
                diameter: DesktopTokens.px(190)
                tone: root.cardAccent
            }

            Column {
                id: passContent
                x: DesktopTokens.px(root.veryCompact ? 16 : root.compact ? 20 : 28)
                y: DesktopTokens.px(root.veryCompact ? 16 : root.compact ? 20 : 28)
                width: parent.width - 2 * x
                spacing: DesktopTokens.px(root.veryCompact || root.compact ? 8 : 10)

                Item {
                    width: parent.width
                    height: DesktopTokens.px(28)
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("CLOUD QUEUE")
                        color: root.cardInk
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.px(10)
                        font.weight: Font.Bold
                        font.letterSpacing: DesktopTokens.px(1.5)
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: liveRow.implicitWidth + DesktopTokens.px(16)
                        height: DesktopTokens.px(26)
                        radius: height / 2
                        color: root.cardSoft
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
                Item { width: 1; height: DesktopTokens.px(root.veryCompact ? 2 : root.compact ? 4 : 8) }
                Text {
                    text: qsTr("YOUR PLACE IN LINE")
                    color: root.cardMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.px(10)
                    font.weight: Font.Bold
                    font.letterSpacing: DesktopTokens.px(1.4)
                }
                Item {
                    width: parent.width
                    height: DesktopTokens.px(root.veryCompact ? 82 : root.compact ? 96 : 116)
                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.queuePosition > 0 ? String(root.queuePosition) : "—"
                        color: root.cardInk
                        font.family: DesktopTokens.displayFont
                        font.pixelSize: DesktopTokens.px(root.queuePosition > 999
                            ? (root.veryCompact ? 64 : 88) : (root.veryCompact ? 84 : root.compact ? 96 : 116))
                        font.weight: Font.Black
                        font.letterSpacing: -DesktopTokens.px(4)
                        Accessible.role: Accessible.StaticText
                        Accessible.name: root.statusText
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Your session starts automatically")
                    color: root.cardMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.px(13)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Item { width: 1; height: DesktopTokens.px(root.veryCompact ? 2 : root.compact ? 4 : 6) }
                Rectangle { width: parent.width; height: 1; color: "#D9DED4" }
                Column {
                    width: parent.width
                    spacing: DesktopTokens.px(8)
                    visible: !root.veryCompact
                    Repeater {
                        model: 3
                        delegate: Item {
                            id: step
                            required property int index
                            width: parent.width
                            height: DesktopTokens.px(root.compact ? 32 : 36)
                            Accessible.role: Accessible.ListItem
                            Accessible.name: root.stepLabel(index) + (index === 0 ? ", " + qsTr("done")
                                : index === 1 ? ", " + qsTr("in progress") : "")
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: DesktopTokens.px(26)
                                height: width
                                radius: width / 2
                                color: step.index === 0 ? root.cardAccent : step.index === 1 ? root.cardSoft : "transparent"
                                border.width: step.index === 2 ? 1 : 0
                                border.color: "#C7CFC3"
                                Text {
                                    anchors.centerIn: parent
                                    text: step.index === 0 ? "✓" : String(step.index + 1)
                                    color: step.index === 0 ? "#FFFFFF" : step.index === 1 ? root.cardAccent : root.cardMuted
                                    font.family: DesktopTokens.monoFont
                                    font.pixelSize: DesktopTokens.px(11)
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: DesktopTokens.px(38)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.stepLabel(step.index)
                                color: step.index === 2 ? root.cardMuted : root.cardInk
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: DesktopTokens.px(13)
                                font.weight: step.index === 1 ? Font.ExtraBold : Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                visible: step.index === 1
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: DesktopTokens.px(7)
                                height: width
                                radius: width / 2
                                color: root.cardAccent
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: DesktopTokens.px(root.veryCompact ? 16 : root.compact ? 20 : 24)
                height: DesktopTokens.px(52)
                radius: DesktopTokens.px(15)
                color: root.cardSoft
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

    component CircleAccent: Rectangle {
        property real diameter: 100
        property color tone: "#286548"
        width: diameter
        height: diameter
        radius: diameter / 2
        color: "transparent"
        border.width: DesktopTokens.px(28)
        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.055)
    }
}
