pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.settings
import OpenNOW

Item {
    id: root
    objectName: "desktopWhileYouWait"
    property bool active: false
    property bool open: false
    property string gameId: ""
    property var saves: ({})
    signal closeRequested()

    readonly property bool showing: active && open
    readonly property var games: [
        { id: "dash", title: qsTr("Comet Courier"), subtitle: qsTr("A tiny starship. A very long way home."), mark: "✦", accent: "#7CE7FF", mood: qsTr("ARCADE · SKILL") },
        { id: "path", title: qsTr("Prism Path"), subtitle: qsTr("Bend light through a quiet little cosmos."), mark: "◇", accent: "#C8A7FF", mood: qsTr("PUZZLE · LOGIC") },
        { id: "garden", title: qsTr("Pocket Garden"), subtitle: qsTr("Grow a moonlit orchard, even while away."), mark: "✿", accent: "#9BE7A2", mood: qsTr("IDLE · COZY") }
    ]
    focus: showing
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        if (root.showing && event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        }
    }

    Settings {
        id: progressSettings
        category: "WhileYouWait"
        property string progressJson: "{}"
    }

    function loadSaves() {
        try {
            const parsed = JSON.parse(progressSettings.progressJson || "{}")
            root.saves = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({})
        } catch (error) {
            root.saves = ({})
        }
    }

    function saveGame(id, value) {
        const updated = Object.assign({}, root.saves)
        updated[id] = Object.assign({}, updated[id] || ({}), value, { savedAt: Date.now() })
        root.saves = updated
        progressSettings.progressJson = JSON.stringify(updated)
    }

    function chooseGame(id) {
        if (root.games.some(game => game.id === id))
            root.gameId = id
    }

    function showPicker() {
        root.gameId = ""
    }

    function currentTitle() {
        const game = root.games.find(item => item.id === root.gameId)
        return game ? game.title : qsTr("Pick up where you left off")
    }

    function savedSummary(id) {
        const saved = root.saves[id] || ({})
        if (id === "dash")
            return Number(saved.best || 0) > 0 ? qsTr("BEST FLIGHT  %1 SECTORS").arg(saved.best)
                : qsTr("A first flight is waiting")
        if (id === "path")
            return qsTr("SIGNALS  %1  ·  RECORD %2").arg(Number(saved.circuitsSolved || 0)).arg(Number(saved.bestLevel || 1))
        return qsTr("HARVESTS  %1  ·  GARDEN %2").arg(Number(saved.harvests || 0)).arg(Number(saved.gardenLevel || 1))
    }

    onActiveChanged: {
        if (!active) {
            if (root.gameId !== "")
                root.gameId = ""
            if (root.open)
                root.closeRequested()
        } else {
            root.forceActiveFocus()
        }
    }
    Component.onCompleted: loadSaves()

    Rectangle {
        anchors.fill: parent
        visible: root.showing
        z: 100
        color: "#D9080D16"
        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("While you wait")

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(1040, parent.width - 36)
            height: Math.min(740, parent.height - 36)
            radius: 26
            color: "#101823"
            border.width: 1
            border.color: "#344457"
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 17
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: root.gameId === "" ? qsTr("WHILE YOU WAIT") : qsTr("A LITTLE WORLD OF YOUR OWN")
                            color: "#83DDF5"
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1.8
                        }
                        Text {
                            text: root.currentTitle()
                            color: "#F3F6FA"
                            font.family: Theme.displayFont
                            font.pixelSize: 27
                            font.weight: Font.Black
                        }
                    }
                    Text {
                        visible: root.gameId !== ""
                        text: qsTr("SAVES LIVE ON THIS DEVICE")
                        color: "#8798AA"
                        font.family: Theme.monoFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.7
                    }
                    Button {
                        objectName: "whileYouWaitClose"
                        text: qsTr("Back to queue")
                        onClicked: root.closeRequested()
                        Accessible.name: qsTr("Close mini-games and return to the queue")
                        contentItem: Text {
                            text: parent.text
                            color: "#E6ECF3"
                            font.family: Theme.bodyFont
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 12
                            color: parent.down ? "#26364A" : "#1B2939"
                            border.width: 1
                            border.color: "#45566B"
                        }
                        padding: 12
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#263446" }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.gameId === ""
                    Flow {
                        anchors.fill: parent
                        spacing: 15
                        Repeater {
                            model: root.games
                            delegate: Button {
                                id: gameCard
                                required property var modelData
                                objectName: "whileYouWaitGame-" + modelData.id
                                width: Math.min(310, Math.max(224, (parent.width - 30) / 3))
                                height: Math.min(262, Math.max(210, parent.height - 4))
                                onClicked: root.chooseGame(modelData.id)
                                Accessible.name: modelData.title + ". " + modelData.subtitle
                                contentItem: Column {
                                    spacing: 9
                                    Text {
                                        text: gameCard.modelData.mark
                                        color: gameCard.modelData.accent
                                        font.pixelSize: 37
                                        font.weight: Font.Black
                                    }
                                    Text {
                                        width: parent.width
                                        text: gameCard.modelData.title
                                        color: "#F3F6FA"
                                        font.family: Theme.displayFont
                                        font.pixelSize: 22
                                        font.weight: Font.Black
                                    }
                                    Text {
                                        width: parent.width
                                        height: 42
                                        text: gameCard.modelData.subtitle
                                        wrapMode: Text.WordWrap
                                        color: "#AAB7C7"
                                        font.family: Theme.bodyFont
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        width: parent.width
                                        text: gameCard.modelData.mood
                                        color: gameCard.modelData.accent
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1.1
                                    }
                                    Rectangle { width: parent.width; height: 1; color: "#2A3A4D" }
                                    Text {
                                        width: parent.width
                                        text: root.savedSummary(gameCard.modelData.id)
                                        color: "#C0CBD5"
                                        font.family: Theme.monoFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                                padding: 20
                                background: Rectangle {
                                    radius: 21
                                    color: gameCard.down ? "#26384B" : "#172331"
                                    border.width: 1
                                    border.color: gameCard.hovered ? gameCard.modelData.accent : "#344457"
                                    Behavior on border.color { ColorAnimation { duration: 140 } }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: gameLoader
                    objectName: "whileYouWaitGameLoader"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.showing && root.gameId !== ""
                    visible: active
                    sourceComponent: root.gameId === "dash" ? cometComponent
                        : root.gameId === "path" ? prismComponent
                        : root.gameId === "garden" ? gardenComponent : undefined
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.gameId !== ""
                    Button {
                        objectName: "whileYouWaitAllGames"
                        text: qsTr("‹  All tiny worlds")
                        onClicked: root.showPicker()
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: qsTr("The queue continues in the background")
                        color: "#8798AA"
                        font.family: Theme.bodyFont
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Component {
        id: cometComponent
        DesktopCometCourier {
            active: root.showing && root.gameId === "dash"
            progress: root.saves.dash || ({})
            onSaveRequested: value => root.saveGame("dash", value)
        }
    }
    Component {
        id: prismComponent
        DesktopPrismPath {
            active: root.showing && root.gameId === "path"
            progress: root.saves.path || ({})
            onSaveRequested: value => root.saveGame("path", value)
        }
    }
    Component {
        id: gardenComponent
        DesktopPocketGarden {
            active: root.showing && root.gameId === "garden"
            progress: root.saves.garden || ({})
            onSaveRequested: value => root.saveGame("garden", value)
        }
    }
}
