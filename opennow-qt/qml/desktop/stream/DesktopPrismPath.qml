pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

Item {
    id: root
    objectName: "prismPathGame"
    property bool active: false
    property var progress: ({})
    property int level: 1
    property int bestLevel: 1
    property int movesLeft: 12
    property int hintsLeft: 2
    property int circuitsSolved: 0
    property int perfectCircuits: 0
    property int rotation: 0
    property int sourceCell: 20
    property int targetCell: 4
    property int startDirection: 1
    property bool solved: false
    property int hintedCell: -1
    property var mirrors: []
    property var beamCells: []
    property bool beamReachedTarget: false
    signal saveRequested(var value)

    readonly property var directionX: [0, 1, 0, -1]
    readonly property var directionY: [-1, 0, 1, 0]
    readonly property string resultText: root.solved ? qsTr("SIGNAL LOCKED · CIRCUIT COMPLETE")
        : root.beamReachedTarget ? qsTr("ALIGNMENT FOUND · CONFIRM THE CIRCUIT")
        : root.movesLeft <= 3 ? qsTr("LOW POWER · MAKE YOUR LAST MOVES COUNT")
        : qsTr("FOLLOW THE LIGHT · EVERY MIRROR MATTERS")

    function rotateCell(cell, turns) {
        let x = cell % 5
        let y = Math.floor(cell / 5)
        for (let i = 0; i < turns; ++i) {
            const oldX = x
            x = 4 - y
            y = oldX
        }
        return y * 5 + x
    }

    function buildPuzzle(puzzleLevel, savedMirrors) {
        root.rotation = (puzzleLevel - 1) % 4
        root.sourceCell = rotateCell(20, root.rotation)
        root.targetCell = rotateCell(4, root.rotation)
        root.startDirection = (1 + root.rotation) % 4
        const core = [22, 12, 14]
        const decoyPool = [6, 8, 16, 18, 2, 10, 24]
        const list = []
        const requiredSlash = root.rotation % 2 === 0
        for (let i = 0; i < core.length; ++i) {
            const cell = rotateCell(core[i], root.rotation)
            const stored = savedMirrors && savedMirrors.find(entry => Number(entry.cell) === cell)
            list.push({ cell: cell, slash: stored ? stored.slash === true : !requiredSlash,
                requiredSlash: requiredSlash, essential: true })
        }
        const decoyCount = Math.min(5, 2 + Math.floor((puzzleLevel - 1) / 2))
        for (let i = 0; i < decoyCount; ++i) {
            const cell = rotateCell(decoyPool[i], root.rotation)
            if (cell === root.sourceCell || cell === root.targetCell || list.some(mirror => mirror.cell === cell))
                continue
            const stored = savedMirrors && savedMirrors.find(entry => Number(entry.cell) === cell)
            list.push({ cell: cell, slash: stored ? stored.slash === true : ((i + puzzleLevel) % 2 === 0),
                requiredSlash: false, essential: false })
        }
        root.mirrors = list
        root.traceBeam()
    }

    function restoreProgress() {
        const saved = root.progress || ({})
        root.level = Math.max(1, Number(saved.level || 1))
        root.bestLevel = Math.max(root.level, Number(saved.bestLevel || 1))
        root.movesLeft = Math.max(0, Number(saved.movesLeft === undefined ? 12 : saved.movesLeft))
        root.hintsLeft = Math.max(0, Math.min(2, Number(saved.hintsLeft === undefined ? 2 : saved.hintsLeft)))
        root.circuitsSolved = Math.max(0, Number(saved.circuitsSolved || 0))
        root.perfectCircuits = Math.max(0, Number(saved.perfectCircuits || 0))
        root.solved = saved.solved === true
        root.outOfPower = saved.outOfPower === true
        root.buildPuzzle(root.level, Array.isArray(saved.mirrors) ? saved.mirrors : [])
        if (root.solved) {
            root.beamReachedTarget = true
            solveTimer.start()
        }
    }

    function persist() {
        root.saveRequested({ level: root.level, bestLevel: root.bestLevel,
            movesLeft: root.movesLeft, hintsLeft: root.hintsLeft,
            circuitsSolved: root.circuitsSolved, perfectCircuits: root.perfectCircuits,
            solved: root.solved, outOfPower: root.outOfPower,
            mirrors: root.mirrors.map(mirror => ({ cell: mirror.cell, slash: mirror.slash })),
            savedAt: Date.now() })
    }

    function findMirror(cell) {
        for (let i = 0; i < root.mirrors.length; ++i) {
            if (Number(root.mirrors[i].cell) === cell)
                return i
        }
        return -1
    }

    function traceBeam() {
        let x = root.sourceCell % 5
        let y = Math.floor(root.sourceCell / 5)
        let direction = root.startDirection
        const trace = []
        const visited = ({})
        let reached = false
        for (let step = 0; step < 60; ++step) {
            x += root.directionX[direction]
            y += root.directionY[direction]
            if (x < 0 || x >= 5 || y < 0 || y >= 5)
                break
            const cell = y * 5 + x
            trace.push(cell)
            if (cell === root.targetCell) {
                reached = true
                break
            }
            const signature = cell + ":" + direction
            if (visited[signature])
                break
            visited[signature] = true
            const mirrorIndex = findMirror(cell)
            if (mirrorIndex >= 0) {
                const mirror = root.mirrors[mirrorIndex]
                direction = mirror.slash
                    ? [1, 0, 3, 2][direction]
                    : [3, 2, 1, 0][direction]
            }
        }
        root.beamCells = trace
        root.beamReachedTarget = reached
        if (reached && !root.solved)
            root.solveCircuit()
    }

    function toggleMirror(cell) {
        if (root.solved || !root.active)
            return
        const index = findMirror(cell)
        if (index < 0)
            return
        const next = root.mirrors.slice()
        const selected = Object.assign({}, next[index], { slash: !next[index].slash })
        next[index] = selected
        root.mirrors = next
        root.movesLeft = Math.max(0, root.movesLeft - 1)
        root.hintedCell = -1
        root.traceBeam()
        if (root.movesLeft === 0 && !root.solved)
            root.outOfPower = true
        root.persist()
    }

    function offerHint() {
        if (root.solved || root.hintsLeft <= 0 || !root.active)
            return
        root.hintsLeft -= 1
        root.hintedCell = -1
        for (let i = 0; i < root.mirrors.length; ++i) {
            const mirror = root.mirrors[i]
            if (mirror.essential && mirror.slash !== mirror.requiredSlash) {
                root.hintedCell = mirror.cell
                break
            }
        }
        root.persist()
    }

    function solveCircuit() {
        root.solved = true
        root.circuitsSolved += 1
        if (root.movesLeft >= 6 && root.hintsLeft === 2)
            root.perfectCircuits += 1
        root.bestLevel = Math.max(root.bestLevel, root.level + 1)
        root.persist()
        solveTimer.restart()
    }

    function advanceCircuit() {
        root.level += 1
        root.movesLeft = 12 + Math.min(8, Math.floor((root.level - 1) / 2))
        root.hintsLeft = 2
        root.solved = false
        root.outOfPower = false
        root.hintedCell = -1
        root.buildPuzzle(root.level, null)
        root.persist()
    }

    function recharge() {
        root.movesLeft = 12 + Math.min(8, Math.floor((root.level - 1) / 2))
        root.hintsLeft = 2
        root.solved = false
        root.outOfPower = false
        root.hintedCell = -1
        root.buildPuzzle(root.level, null)
        root.persist()
    }

    property bool outOfPower: false
    onActiveChanged: {
        if (root.active)
            root.forceActiveFocus()
        else
            root.persist()
    }
    Component.onCompleted: restoreProgress()

    Timer {
        id: solveTimer
        interval: 950
        repeat: false
        onTriggered: root.advanceCircuit()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: qsTr("PRISM PATH · CIRCUIT %1").arg(root.level); color: "#C8A7FF"; font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2 }
                Text { text: qsTr("Bend the signal home"); color: "#F1F3F8"; font.family: Theme.displayFont; font.pixelSize: 23; font.weight: Font.Black }
            }
            Text { text: qsTr("✧ %1   ◇ %2   BEST %3").arg(root.circuitsSolved).arg(root.perfectCircuits).arg(root.bestLevel); color: "#D4C0F7"; font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold }
            Button { text: qsTr("⌕ Hint · %1").arg(root.hintsLeft); enabled: root.hintsLeft > 0 && !root.solved && !root.outOfPower; onClicked: root.offerHint() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 22
            Grid {
                id: puzzleGrid
                columns: 5
                spacing: 7
                Layout.preferredWidth: Math.min(360, parent.height)
                Layout.preferredHeight: Math.min(360, parent.height)
                Repeater {
                    model: 25
                    delegate: Button {
                        id: tile
                        required property int index
                        width: (Math.min(puzzleGrid.width, puzzleGrid.height) - 28) / 5
                        height: width
                        readonly property int mirrorIndex: root.findMirror(index)
                        readonly property bool hasMirror: mirrorIndex >= 0
                        readonly property var mirror: hasMirror ? root.mirrors[mirrorIndex] : ({})
                        readonly property bool source: index === root.sourceCell
                        readonly property bool target: index === root.targetCell
                        readonly property bool onBeam: root.beamCells.indexOf(index) >= 0
                        readonly property bool hinted: index === root.hintedCell
                        enabled: hasMirror && !root.solved && !root.outOfPower
                        onClicked: root.toggleMirror(index)
                        contentItem: Item {
                            Text {
                                anchors.centerIn: parent
                                text: tile.source ? "◉" : tile.target ? (root.beamReachedTarget ? "✦" : "◎")
                                    : tile.hasMirror ? (tile.mirror.slash ? "/" : "\\") : tile.onBeam ? "·" : ""
                                color: tile.source ? "#E0C8FF" : tile.target ? "#FFE79B"
                                    : tile.hinted ? "#FFFFFF" : tile.onBeam ? "#BCEBFF"
                                    : tile.hasMirror ? "#D2C0F0" : "#526176"
                                font.pixelSize: tile.hasMirror ? 31 : 21
                                font.weight: Font.Black
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        background: Rectangle {
                            radius: 12
                            color: tile.source ? "#302248" : tile.target ? "#3C3320"
                                : tile.hinted ? "#7254A5" : tile.hasMirror ? "#222238"
                                : tile.onBeam ? "#153147" : "#151E2A"
                            border.width: tile.hinted ? 2 : 1
                            border.color: tile.hinted ? "#F1E8FF" : tile.onBeam ? "#59BDE8"
                                : tile.source ? "#9971CD" : tile.target ? "#BDA55C" : "#2A3748"
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 86
                    radius: 16
                    color: "#171A27"
                    border.width: 1
                    border.color: "#3D3552"
                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 8
                        Text { text: root.resultText; color: root.solved ? "#BFF3D0" : "#C8A7FF"; font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                        Text {
                            width: parent.width
                            text: qsTr("Start at ◉. Turn each mirror with a click. The beam preview shows exactly where the signal travels.")
                            color: "#AEB9C7"
                            font.family: Theme.bodyFont
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: qsTr("MOVES LEFT  %1").arg(root.movesLeft); color: root.movesLeft <= 3 ? "#FFAA97" : "#D6C8EC"; font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold }
                    Button { text: qsTr("Recharge circuit"); visible: root.outOfPower; onClicked: root.recharge() }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 100
                    radius: 16
                    color: "#111A27"
                    border.width: 1
                    border.color: "#28394D"
                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 8
                        Text { text: qsTr("SIGNAL TRACE"); color: "#8395A8"; font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: root.beamReachedTarget ? qsTr("The light found its receiver. Circuit %1 is solved.").arg(root.level)
                                : root.outOfPower ? qsTr("The signal faded. Recharge to reset the mirrors; your circuit record stays saved.")
                                : qsTr("%1 mirrors · %2 spare hint lenses · the trace is saved after every move.").arg(root.mirrors.length).arg(root.hintsLeft)
                            color: "#AEB9C7"
                            font.family: Theme.bodyFont
                            font.pixelSize: 12
                        }
                        Item { width: 1; height: 1; Layout.fillHeight: true }
                    }
                }
                Text { text: qsTr("Rotate the circuit each level. Perfect solves build your signal record."); color: "#8395A6"; font.family: Theme.bodyFont; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
        }
    }
}
