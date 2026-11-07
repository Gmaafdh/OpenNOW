pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

Item {
    id: root
    objectName: "cometCourierGame"
    property bool active: false
    property var progress: ({})
    property int lane: 1
    property int score: 0
    property int best: 0
    property int runTicks: 0
    property int runs: 0
    property int lives: 3
    property int shields: 0
    property int shieldUpgrade: 0
    property int hullUpgrade: 0
    property int shards: 0
    property int combo: 0
    property int ticksSinceSave: 0
    property bool paused: false
    property bool gameOver: false
    property bool restored: false
    property var objects: []
    signal saveRequested(var value)

    readonly property int playerRow: 4
    readonly property int tickMs: Math.max(340, 760 - Math.floor(root.score / 18) * 28)
    focus: active
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { root.move(-1); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { root.move(1); event.accepted = true }
        else if (event.key === Qt.Key_Space) { root.paused = !root.paused; event.accepted = true }
    }
    readonly property string statusLine: root.gameOver ? qsTr("RUN ENDED · YOUR CARGO IS SAFE")
        : root.paused ? qsTr("ENGINES IDLE · TAKE YOUR TIME")
        : root.shields > 0 ? qsTr("SHIELD CHARGED · THREAD THE NEEDLE")
        : qsTr("KEEP MOVING · WATCH THE NEXT WAVE")

    function restoreProgress() {
        const saved = root.progress || ({})
        root.best = Math.max(0, Number(saved.best || 0))
        root.runs = Math.max(0, Number(saved.runs || 0))
        root.shards = Math.max(0, Number(saved.shards || 0))
        root.hullUpgrade = Math.max(0, Math.min(3, Number(saved.hullUpgrade || 0)))
        root.shieldUpgrade = Math.max(0, Math.min(2, Number(saved.shieldUpgrade || 0)))
        const run = saved.currentRun || null
        if (run && Number(run.lives) > 0 && Number(run.ticks) > 0) {
            root.lane = Math.max(0, Math.min(2, Number(run.lane || 1)))
            root.score = Math.max(0, Number(run.score || 0))
            root.runTicks = Math.max(0, Number(run.ticks || 0))
            root.lives = Math.max(1, Math.min(6, Number(run.lives)))
            root.shields = Math.max(0, Math.min(3, Number(run.shields || 0)))
            root.combo = Math.max(0, Number(run.combo || 0))
            root.objects = Array.isArray(run.objects) ? run.objects.slice(0, 24) : []
        } else {
            root.startRun()
        }
        root.best = Math.max(root.best, root.score)
        root.restored = true
        root.persist()
    }

    function runSnapshot() {
        return {
            lane: root.lane,
            score: root.score,
            ticks: root.runTicks,
            lives: root.lives,
            shields: root.shields,
            combo: root.combo,
            objects: root.objects.slice(0, 24)
        }
    }

    function persist() {
        if (!root.restored && !root.gameOver)
            return
        const currentRun = root.gameOver ? null : root.runSnapshot()
        root.saveRequested({ best: Math.max(root.best, root.score), runs: root.runs,
            shards: root.shards, hullUpgrade: root.hullUpgrade, shieldUpgrade: root.shieldUpgrade,
            currentRun: currentRun, lastPlayedAt: Date.now() })
    }

    function startRun() {
        root.lane = 1
        root.score = 0
        root.runTicks = 0
        root.ticksSinceSave = 0
        root.lives = Math.min(6, 3 + root.hullUpgrade)
        root.shields = root.shieldUpgrade
        root.combo = 0
        root.objects = []
        root.paused = false
        root.gameOver = false
        root.persist()
        if (root.active)
            root.forceActiveFocus()
    }

    function move(direction) {
        if (!root.active || root.paused || root.gameOver)
            return
        root.lane = Math.max(0, Math.min(2, root.lane + direction))
    }

    function buyUpgrade(kind) {
        if (kind === "hull" && root.hullUpgrade < 3 && root.shards >= 18 + root.hullUpgrade * 12) {
            root.shards -= 18 + root.hullUpgrade * 12
            root.hullUpgrade += 1
            root.persist()
        } else if (kind === "shield" && root.shieldUpgrade < 2 && root.shards >= 24 + root.shieldUpgrade * 16) {
            root.shards -= 24 + root.shieldUpgrade * 16
            root.shieldUpgrade += 1
            root.persist()
        }
    }

    function step() {
        if (!root.active || root.paused || root.gameOver)
            return
        root.runTicks += 1
        root.score += 1 + (root.combo >= 4 ? 1 : 0)
        const next = []
        let wasHit = false
        for (let i = 0; i < root.objects.length; ++i) {
            const object = root.objects[i]
            const row = Number(object.row) + 1
            if (row >= root.playerRow) {
                if (Number(object.lane) === root.lane) {
                    if (object.kind === "shard") {
                        root.shards += 1
                        root.combo += 1
                    } else if (object.kind === "shield") {
                        root.shields = Math.min(3, root.shields + 1)
                        root.combo += 1
                    } else if (object.kind === "meteor") {
                        if (root.shields > 0) {
                            root.shields -= 1
                            root.combo = 0
                            wasHit = true
                        } else {
                            root.lives -= 1
                            root.combo = 0
                            wasHit = true
                        }
                    }
                }
            } else {
                next.push({ lane: Number(object.lane), row: row, kind: String(object.kind) })
            }
        }
        if (root.runTicks % 2 === 0) {
            const laneA = Math.floor(Math.random() * 3)
            next.push({ lane: laneA, row: 0, kind: "meteor" })
            if (root.runTicks % 6 === 0) {
                let laneB = Math.floor(Math.random() * 3)
                if (laneB === laneA)
                    laneB = (laneB + 1 + Math.floor(Math.random() * 2)) % 3
                next.push({ lane: laneB, row: 0, kind: "shard" })
            }
        }
        if (root.runTicks % 17 === 0)
            next.push({ lane: Math.floor(Math.random() * 3), row: 0, kind: "shield" })
        root.objects = next
        root.best = Math.max(root.best, root.score)
        root.ticksSinceSave += 1
        if (root.lives <= 0) {
            root.gameOver = true
            root.runs += 1
            root.paused = false
        }
        if (root.ticksSinceSave >= 3 || wasHit || root.gameOver) {
            root.ticksSinceSave = 0
            root.persist()
        }
    }

    function onActiveChanged() {
        if (root.active) {
            root.forceActiveFocus()
        } else if (root.restored) {
            root.persist()
        }
    }

    onActiveChanged: root.onActiveChanged()
    Component.onCompleted: restoreProgress()

    Timer {
        interval: root.tickMs
        repeat: true
        running: root.active && !root.paused && !root.gameOver
        onTriggered: root.step()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: qsTr("COURIER FLIGHT DECK")
                    color: "#80E8FF"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
                Text {
                    text: qsTr("Run %1  ·  Best %2").arg(root.score).arg(root.best)
                    color: "#F0F5FA"
                    font.family: Theme.displayFont
                    font.pixelSize: 23
                    font.weight: Font.Black
                }
            }
            Text {
                text: qsTr("◆ %1   ♥ %2   ◈ %3").arg(root.shards).arg(root.lives).arg(root.shields)
                color: "#C5E7F0"
                font.family: Theme.monoFont
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Button {
                text: root.paused ? qsTr("Resume") : qsTr("Pause")
                enabled: !root.gameOver
                onClicked: root.paused = !root.paused
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 230
            radius: 18
            color: "#07111D"
            border.width: 1
            border.color: "#263C51"
            clip: true

            Repeater {
                model: 30
                delegate: Rectangle {
                    required property int index
                    readonly property real xSeed: ((index * 73 + 19) % 997) / 997
                    readonly property real ySeed: ((index * 137 + 31) % 991) / 991
                    x: xSeed * parent.width
                    y: (ySeed * parent.height + (root.runTicks * (index % 4 + 1) * 0.8)) % parent.height
                    width: index % 6 === 0 ? 3 : 2
                    height: width
                    radius: width
                    color: index % 5 === 0 ? "#7CE7FF" : "#56718A"
                    opacity: 0.22 + (index % 4) * 0.13
                }
            }

            Repeater {
                model: 2
                delegate: Rectangle {
                    required property int index
                    width: 1
                    x: parent.width * (index + 1) / 3
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: "#244055"
                    opacity: 0.75
                }
            }

            Repeater {
                model: root.objects
                delegate: Item {
                    required property var modelData
                    width: 46
                    height: 38
                    x: (Number(modelData.lane) + 0.5) * parent.width / 3 - width / 2
                    y: 12 + Number(modelData.row) * ((parent.height - 66) / root.playerRow)
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: modelData.kind === "meteor" ? "#462B35"
                            : modelData.kind === "shield" ? "#1A3C55" : "#493E22"
                        border.width: 1
                        border.color: modelData.kind === "meteor" ? "#FF857B"
                            : modelData.kind === "shield" ? "#64D9FF" : "#F3CC68"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.kind === "meteor" ? "◆" : modelData.kind === "shield" ? "⬡" : "✦"
                            color: modelData.kind === "meteor" ? "#FFAAA0"
                                : modelData.kind === "shield" ? "#9CEBFF" : "#FFE39B"
                            font.pixelSize: 20
                            font.weight: Font.Black
                        }
                    }
                }
            }

            Rectangle {
                id: courier
                width: 42
                height: 42
                radius: 14
                x: (root.lane + 0.5) * parent.width / 3 - width / 2
                y: parent.height - height - 13
                color: root.shields > 0 ? "#173F56" : "#172B3D"
                border.width: 2
                border.color: root.shields > 0 ? "#7CE7FF" : "#6CA6C5"
                Text {
                    anchors.centerIn: parent
                    text: "✦"
                    color: "#EAFBFF"
                    font.pixelSize: 23
                    font.weight: Font.Black
                }
                Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.paused || root.gameOver
                color: "#C907111D"
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.gameOver ? qsTr("SHIP DOWN · CARGO SECURED") : qsTr("PAUSED BETWEEN THE STARS")
                        color: root.gameOver ? "#FFB09D" : "#BCEEFF"
                        font.family: Theme.monoFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.gameOver ? qsTr("You flew %1 sectors and brought home %2 shards.").arg(root.score).arg(root.shards)
                            : qsTr("The queue is still moving. Your flight is safely paused.")
                        color: "#D8E1E9"
                        font.family: Theme.bodyFont
                        font.pixelSize: 14
                    }
                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.gameOver
                        text: qsTr("Launch another run")
                        onClicked: root.startRun()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: root.statusLine; color: "#A9BECE"; font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.Bold }
                Text { text: qsTr("Every shard is yours to keep. Upgrade the ship between runs."); color: "#8395A6"; font.family: Theme.bodyFont; font.pixelSize: 12 }
            }
            Button { text: qsTr("◀  PORT"); onClicked: root.move(-1); enabled: root.lane > 0 && !root.paused && !root.gameOver }
            Button { text: qsTr("STARBOARD  ▶"); onClicked: root.move(1); enabled: root.lane < 2 && !root.paused && !root.gameOver }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 14
            color: "#111E2B"
            border.width: 1
            border.color: "#263C51"
            implicitHeight: upgrades.implicitHeight + 22
            RowLayout {
                id: upgrades
                anchors.fill: parent
                anchors.margins: 11
                spacing: 12
                Text {
                    Layout.fillWidth: true
                    text: qsTr("HANGAR  ·  %1 LIFETIME RUNS").arg(root.runs)
                    color: "#91A7B8"
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
                Button {
                    text: qsTr("Hull +1  ·  %1 shards").arg(18 + root.hullUpgrade * 12)
                    enabled: root.hullUpgrade < 3 && root.shards >= 18 + root.hullUpgrade * 12
                    onClicked: root.buyUpgrade("hull")
                }
                Button {
                    text: qsTr("Start shield  ·  %1 shards").arg(24 + root.shieldUpgrade * 16)
                    enabled: root.shieldUpgrade < 2 && root.shards >= 24 + root.shieldUpgrade * 16
                    onClicked: root.buyUpgrade("shield")
                }
            }
        }
    }

}
