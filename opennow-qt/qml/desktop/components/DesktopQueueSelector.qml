import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

Dialog {
    id: root
    objectName: "desktopQueueSelector"
    title: qsTr("Choose a server")
    header: null
    required property var selector
    required property var settingsStore
    property string selectedZoneId: ""
    readonly property bool compact: height < DesktopTokens.px(600)
    readonly property bool narrow: width < DesktopTokens.px(570)
    readonly property var selectedLocation: selector.locations.find(item => item.zoneId === selectedZoneId) || null
    readonly property bool higherLatency: {
        if (!selectedLocation || selectedLocation.pingMs === null || selectedLocation.pingMs === undefined)
            return false
        return selector.locations.some(item => item.pingMs !== null && item.pingMs !== undefined
                                       && item.pingMs < selectedLocation.pingMs)
    }

    function choose(zoneId) {
        const hide = dontShow.checked
        selector.choose(zoneId)
        if (hide && !selector.opened)
            settingsStore.setSetting("hideQueueSelector", true)
    }

    function waitLabel(etaMs) {
        if (etaMs === null || etaMs === undefined)
            return qsTr("Unavailable")
        const minutes = Math.max(1, Math.ceil(etaMs / 60000))
        return minutes < 60 ? qsTr("~%1 min").arg(minutes)
                            : qsTr("~%1 hr %2 min").arg(Math.floor(minutes / 60)).arg(minutes % 60)
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(DesktopTokens.px(800), parent.width - DesktopTokens.px(32))
    height: Math.min(DesktopTokens.px(700), parent.height - DesktopTokens.px(32))
    padding: DesktopTokens.px(compact ? 16 : 24)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    visible: selector.opened
    onOpened: {
        dontShow.checked = false
        selectedZoneId = selector.recommendedZoneId
        defaultButton.forceActiveFocus()
    }
    onClosed: if (selector.opened) selector.dismiss()

    background: Rectangle {
        radius: DesktopTokens.px(20)
        color: Theme.shell
        border.color: DesktopTokens.seam
    }

    Connections {
        target: root.selector
        function onLocationsChanged() { root.selectedZoneId = "" }
        function onRecommendedZoneIdChanged() { root.selectedZoneId = root.selector.recommendedZoneId }
    }

    contentItem: ColumnLayout {
        spacing: DesktopTokens.px(root.compact ? 8 : 14)

        RowLayout {
            Layout.fillWidth: true
            spacing: DesktopTokens.px(12)
            Rectangle {
                Layout.preferredWidth: DesktopTokens.px(42)
                Layout.preferredHeight: DesktopTokens.px(42)
                radius: DesktopTokens.px(12)
                color: DesktopTokens.raisedStrong
                Text {
                    anchors.centerIn: parent
                    text: "↗"
                    color: DesktopTokens.focus
                    font.pixelSize: DesktopTokens.headingSize
                    font.weight: Font.Bold
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: DesktopTokens.px(2)
                Text {
                    Layout.fillWidth: true
                    text: qsTr("READY TO PLAY")
                    color: DesktopTokens.focus
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: DesktopTokens.titleSize
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }
            DesktopSettingsButton {
                objectName: "queueSelectorCancel"
                text: qsTr("Cancel")
                onClicked: root.selector.dismiss()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: gameInfo.implicitHeight + DesktopTokens.px(20)
            radius: DesktopTokens.px(12)
            color: DesktopTokens.raised
            border.color: DesktopTokens.seamSoft
            RowLayout {
                id: gameInfo
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: DesktopTokens.px(12)
                spacing: DesktopTokens.px(12)
                Text {
                    text: qsTr("LAUNCHING")
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
                Text {
                    Layout.fillWidth: true
                    text: root.selector.gameTitle
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    font.weight: Font.DemiBold
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !root.compact
            text: qsTr("Pick the best balance for you. Shorter queues may come with higher latency.")
            color: DesktopTokens.textBody
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.captionSize
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: DesktopTokens.px(2)
                Text {
                    text: qsTr("Available locations")
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.headingSize
                    font.weight: Font.Bold
                }
                Text {
                    visible: !root.compact
                    text: root.selector.loading ? qsTr("Checking live queue information…")
                          : qsTr("Compare queue, estimated wait and latency")
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                }
            }
            DesktopSettingsButton {
                objectName: "queueSelectorRefresh"
                text: qsTr("Refresh")
                compact: true
                enabled: !root.selector.loading
                onClicked: root.selector.refresh()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: DesktopTokens.px(80)
            Rectangle {
                anchors.fill: parent
                radius: DesktopTokens.px(14)
                color: DesktopTokens.raised
                border.color: DesktopTokens.seamSoft
                visible: root.selector.loading || root.selector.error !== ""
                Column {
                    anchors.centerIn: parent
                    width: parent.width - DesktopTokens.px(32)
                    spacing: DesktopTokens.px(10)
                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.selector.loading
                        running: visible
                    }
                    Text {
                        width: parent.width
                        text: root.selector.loading ? qsTr("Finding queue and connection information…")
                                                   : root.selector.error
                        textFormat: Text.PlainText
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.bodySize
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            ListView {
                id: locations
                objectName: "queueSelectorLocations"
                anchors.fill: parent
                clip: true
                spacing: DesktopTokens.px(8)
                visible: !root.selector.loading && root.selector.error === ""
                model: root.selector.locations
                ScrollBar.vertical: ScrollBar {}
                delegate: ItemDelegate {
                    id: option
                    required property var modelData
                    required property int index
                    objectName: "queueLocation_" + modelData.zoneId
                    width: Math.max(0, ListView.view.width - DesktopTokens.px(12))
                    implicitHeight: contentItem.implicitHeight + padding * 2
                    padding: DesktopTokens.px(root.compact ? 10 : 14)
                    highlighted: root.selectedZoneId === modelData.zoneId
                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: highlighted
                    Accessible.name: modelData.title + ", " + qsTr("%1 in queue").arg(modelData.queuePosition)
                                     + ", " + (modelData.pingMs === null || modelData.pingMs === undefined
                                                ? qsTr("Latency unavailable") : qsTr("%1 ms").arg(modelData.pingMs))
                    onClicked: root.selectedZoneId = modelData.zoneId
                    background: Rectangle {
                        radius: DesktopTokens.px(12)
                        color: option.highlighted ? DesktopTokens.raisedStrong
                                                  : option.hovered ? DesktopTokens.raised : "transparent"
                        border.color: option.highlighted || option.activeFocus ? DesktopTokens.focus : DesktopTokens.seam
                        border.width: option.activeFocus ? 2 : 1
                    }
                    contentItem: ColumnLayout {
                        spacing: DesktopTokens.px(10)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: DesktopTokens.px(10)
                            Rectangle {
                                Layout.preferredWidth: DesktopTokens.px(18)
                                Layout.preferredHeight: DesktopTokens.px(18)
                                radius: width / 2
                                color: "transparent"
                                border.color: option.highlighted ? DesktopTokens.focus : DesktopTokens.textMuted
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: DesktopTokens.px(8)
                                    height: width
                                    radius: width / 2
                                    color: DesktopTokens.focus
                                    visible: option.highlighted
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: DesktopTokens.px(3)
                                Text {
                                    Layout.fillWidth: true
                                    text: option.modelData.title
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: DesktopTokens.textHigh
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.bodySize
                                    font.weight: Font.Bold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: option.modelData.region + " · " + option.modelData.zoneId
                                          + (option.modelData.alternateCount > 0
                                             ? qsTr(" · %1 servers").arg(option.modelData.alternateCount + 1) : "")
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: DesktopTokens.textMuted
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.smallSize
                                }
                            }
                            Rectangle {
                                visible: option.modelData.zoneId === root.selector.recommendedZoneId
                                implicitWidth: badge.implicitWidth + DesktopTokens.px(16)
                                implicitHeight: badge.implicitHeight + DesktopTokens.px(8)
                                radius: DesktopTokens.px(8)
                                color: DesktopTokens.raisedStrong
                                Text {
                                    id: badge
                                    anchors.centerIn: parent
                                    text: root.narrow ? qsTr("Best") : qsTr("Recommended")
                                    color: DesktopTokens.focus
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.smallSize
                                    font.weight: Font.Bold
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: DesktopTokens.px(28)
                            spacing: DesktopTokens.px(8)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: DesktopTokens.px(2)
                                Text {
                                    text: qsTr("QUEUE")
                                    color: DesktopTokens.textMuted
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.microSize
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: qsTr("%1 waiting").arg(option.modelData.queuePosition)
                                    color: DesktopTokens.textHigh
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.captionSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: DesktopTokens.px(2)
                                Text {
                                    text: qsTr("EST. WAIT")
                                    color: DesktopTokens.textMuted
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.microSize
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: root.waitLabel(option.modelData.etaMs)
                                    color: DesktopTokens.textHigh
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.captionSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: DesktopTokens.px(2)
                                Text {
                                    text: qsTr("LATENCY")
                                    color: DesktopTokens.textMuted
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.microSize
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: option.modelData.pingMs === null || option.modelData.pingMs === undefined
                                          ? qsTr("Unavailable") : qsTr("%1 ms").arg(option.modelData.pingMs)
                                    color: DesktopTokens.textHigh
                                    font.family: DesktopTokens.monoFont
                                    font.pixelSize: DesktopTokens.monoSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.higherLatency
            implicitHeight: warningText.implicitHeight + DesktopTokens.px(16)
            radius: DesktopTokens.px(10)
            color: DesktopTokens.raised
            border.color: Theme.lightMode ? DesktopTokens.seam : DesktopTokens.amber
            Text {
                id: warningText
                objectName: "queueSelectorLatencyWarning"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: DesktopTokens.px(10)
                text: qsTr("Higher latency than your closest location may make gameplay less responsive.")
                color: Theme.lightMode ? Theme.textMuted : DesktopTokens.amber
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            CheckBox {
                id: dontShow
                objectName: "queueSelectorDontShow"
                Layout.fillWidth: true
                text: qsTr("Don't show again")
                spacing: DesktopTokens.px(10)
                padding: DesktopTokens.px(4)
                indicator: Rectangle {
                    x: dontShow.leftPadding
                    y: (dontShow.height - height) / 2
                    width: DesktopTokens.px(18)
                    height: width
                    radius: DesktopTokens.px(4)
                    color: dontShow.checked ? Theme.focus : "transparent"
                    border.color: dontShow.activeFocus ? Theme.focus : Theme.textMuted
                    border.width: dontShow.activeFocus ? 2 : 1
                    Text {
                        anchors.centerIn: parent
                        visible: dontShow.checked
                        text: "✓"
                        color: Theme.focusText
                        font.pixelSize: DesktopTokens.captionSize
                    }
                }
                contentItem: Text {
                    leftPadding: dontShow.indicator.width + dontShow.spacing
                    text: dontShow.text
                    color: DesktopTokens.textBody
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                objectName: "queueSelectorCredit"
                text: qsTr("Data by PrintedWaste")
                Accessible.name: qsTr("Powered by PrintedWaste")
                padding: DesktopTokens.px(3)
                background: Rectangle {
                    color: "transparent"
                    border.color: parent.activeFocus ? DesktopTokens.focus : "transparent"
                    radius: DesktopTokens.px(3)
                }
                contentItem: Text {
                    text: parent.text
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.microSize
                    font.underline: true
                }
                onClicked: Qt.openUrlExternally("https://printedwaste.com/gfn")
            }
        }
        Text {
            Layout.fillWidth: true
            visible: !root.compact
            text: qsTr("Estimates can change. Your selection applies to this launch only.")
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: DesktopTokens.px(8)
            Item { Layout.fillWidth: true }
            DesktopSettingsButton {
                id: defaultButton
                objectName: "queueSelectorDefault"
                text: root.narrow ? qsTr("Use default") : qsTr("Use default region")
                onClicked: root.choose("")
            }
            DesktopSettingsButton {
                objectName: "queueSelectorPlay"
                text: qsTr("Play here")
                primary: true
                enabled: root.selectedLocation !== null && !root.selector.loading
                onClicked: root.choose(root.selectedZoneId)
            }
        }
    }
}
