pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

Item {
    id: root
    objectName: "pocketGardenGame"
    property bool active: false
    property var progress: ({})
    property var seedBank: ({ moonmint: 3, glassbell: 1, emberpear: 1 })
    property var plots: []
    property int dew: 5
    property int pollen: 0
    property int gardenLevel: 1
    property int harvests: 0
    property string selectedCrop: "moonmint"
    property string dayToken: ""
    property string dailyCrop: "moonmint"
    property int dailyProgress: 0
    property bool dailyClaimed: false
    property double lastGrowthAt: 0
    property double offlineSeconds: 0
    property string gardenNote: ""
    signal saveRequested(var value)

    readonly property var cropCatalog: [
        { id: "moonmint", name: qsTr("Moonmint"), seed: qsTr("mint seeds"), icon: "♧", tint: "#A8F0C1", duration: 85, pollen: 1, dewYield: 1 },
        { id: "glassbell", name: qsTr("Glassbell"), seed: qsTr("glass seeds"), icon: "♢", tint: "#BAACFF", duration: 185, pollen: 3, dewYield: 0 },
        { id: "emberpear", name: qsTr("Emberpear"), seed: qsTr("ember pips"), icon: "✿", tint: "#FFC58F", duration: 340, pollen: 2, dewYield: 2 }
    ]
    readonly property int plotCount: Math.min(5, 2 + root.gardenLevel)
    readonly property int plotRows: Math.ceil(root.plotCount / 3)
    readonly property int weatherKind: Math.floor(Date.now() / 86400000) % 3
    readonly property string weatherName: [qsTr("MISTFALL"), qsTr("STARWIND"), qsTr("SUNSHOWER")][root.weatherKind]
    readonly property string dailyPrompt: qsTr("Gather 3 %1 harvests").arg(root.cropName(root.dailyCrop))

    function crop(id) {
        for (let i = 0; i < root.cropCatalog.length; ++i) {
            if (root.cropCatalog[i].id === id)
                return root.cropCatalog[i]
        }
        return root.cropCatalog[0]
    }

    function cropName(id) {
        return root.crop(id).name
    }

    function todayToken() {
        const date = new Date()
        return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate()
    }

    function defaultPlots() {
        return Array.from({ length: root.plotCount }, () => ({ crop: "", growth: 0, moisture: 0 }))
    }

    function loadProgress() {
        const saved = root.progress || ({})
        const legacyGarden = Array.isArray(saved.plots) && saved.plots.length > 0
            && typeof saved.plots[0] === "number"
        const seedDefaults = { moonmint: 3, glassbell: 1, emberpear: 1 }
        if (legacyGarden && saved.seeds !== undefined)
            seedDefaults.moonmint = Math.max(0, Number(saved.seeds))
        root.seedBank = Object.assign(seedDefaults, saved.seedBank || ({}))
        root.dew = Math.max(0, Number(saved.dew === undefined ? 5 : saved.dew))
        root.pollen = Math.max(0, Number(saved.pollen || 0))
        root.gardenLevel = Math.max(1, Math.min(4, Number(saved.gardenLevel || 1)))
        root.harvests = Math.max(0, Number(saved.harvests || 0))
        root.selectedCrop = String(saved.selectedCrop || "moonmint")
        root.dayToken = String(saved.dayToken || root.todayToken())
        root.dailyCrop = String(saved.dailyCrop || root.dailyForToday())
        root.dailyProgress = Math.max(0, Math.min(3, Number(saved.dailyProgress || 0)))
        root.dailyClaimed = saved.dailyClaimed === true
        const storedPlots = legacyGarden ? saved.plots.map(stage => ({ crop: Number(stage) > 0 ? "moonmint" : "",
                growth: Math.max(0, Math.min(0.92, Number(stage) / 3)), moisture: Number(stage) > 0 ? 35 : 0 }))
            : Array.isArray(saved.plots) ? saved.plots : []
        root.plots = root.defaultPlots().map((plot, index) => {
            const stored = storedPlots[index] || plot
            return { crop: String(stored.crop || ""), growth: Math.max(0, Math.min(1, Number(stored.growth || 0))),
                moisture: Math.max(0, Number(stored.moisture || 0)) }
        })
        root.lastGrowthAt = Number(saved.lastGrowthAt || saved.savedAt || Date.now())
        const currentDay = root.todayToken()
        if (root.dayToken !== currentDay) {
            root.dayToken = currentDay
            root.dailyCrop = root.dailyForToday()
            root.dailyProgress = 0
            root.dailyClaimed = false
        }
        root.advanceGrowth(Date.now())
        root.persist()
    }

    function dailyForToday() {
        const day = Math.floor(Date.now() / 86400000)
        return ["moonmint", "glassbell", "emberpear"][day % 3]
    }

    function weatherMultiplier(cropId) {
        if (root.weatherKind === 0 && cropId === "moonmint") return 1.45
        if (root.weatherKind === 1 && cropId === "glassbell") return 1.40
        if (root.weatherKind === 2 && cropId === "emberpear") return 1.35
        return 1
    }

    function advanceGrowth(now) {
        if (!root.lastGrowthAt) {
            root.lastGrowthAt = now
            return
        }
        const elapsed = Math.max(0, Math.min(8 * 3600, (now - root.lastGrowthAt) / 1000))
        if (elapsed <= 0)
            return
        root.offlineSeconds += elapsed
        const next = root.plots.map(plot => {
            if (!plot.crop || Number(plot.growth) >= 1)
                return plot
            const definition = root.crop(plot.crop)
            const hydratedTime = Math.min(elapsed, Number(plot.moisture || 0))
            const dryTime = elapsed - hydratedTime
            const growth = Number(plot.growth)
                + hydratedTime / definition.duration * root.weatherMultiplier(plot.crop)
                + dryTime / definition.duration * 0.28 * root.weatherMultiplier(plot.crop)
            return { crop: plot.crop, growth: Math.min(1, growth),
                moisture: Math.max(0, Number(plot.moisture || 0) - elapsed) }
        })
        root.plots = next
        root.lastGrowthAt = now
    }

    function persist() {
        root.saveRequested({ seedBank: Object.assign({}, root.seedBank), plots: root.plots.map(plot => ({
                crop: plot.crop, growth: plot.growth, moisture: plot.moisture })),
            dew: root.dew, pollen: root.pollen, gardenLevel: root.gardenLevel,
            harvests: root.harvests, selectedCrop: root.selectedCrop, dayToken: root.dayToken,
            dailyCrop: root.dailyCrop, dailyProgress: root.dailyProgress, dailyClaimed: root.dailyClaimed,
            lastGrowthAt: root.lastGrowthAt, savedAt: Date.now() })
    }

    function plant(index) {
        root.advanceGrowth(Date.now())
        const plot = root.plots[index]
        if (!plot || plot.crop || Number(root.seedBank[root.selectedCrop] || 0) <= 0)
            return
        const nextSeeds = Object.assign({}, root.seedBank)
        nextSeeds[root.selectedCrop] = Number(nextSeeds[root.selectedCrop]) - 1
        const nextPlots = root.plots.slice()
        nextPlots[index] = { crop: root.selectedCrop, growth: 0.015, moisture: 75 }
        root.seedBank = nextSeeds
        root.plots = nextPlots
        root.gardenNote = qsTr("A %1 seed found its home.").arg(root.cropName(root.selectedCrop))
        root.persist()
    }

    function water(index) {
        root.advanceGrowth(Date.now())
        const plot = root.plots[index]
        if (!plot || !plot.crop || plot.growth >= 1 || root.dew <= 0)
            return
        const next = root.plots.slice()
        next[index] = { crop: plot.crop, growth: Math.min(1, plot.growth + 0.12), moisture: Math.min(120, plot.moisture + 70) }
        root.plots = next
        root.dew -= 1
        root.gardenNote = qsTr("A little dew goes a long way.")
        root.persist()
    }

    function harvest(index) {
        root.advanceGrowth(Date.now())
        const plot = root.plots[index]
        if (!plot || !plot.crop || plot.growth < 1)
            return
        const definition = root.crop(plot.crop)
        const seeds = Object.assign({}, root.seedBank)
        seeds[plot.crop] = Number(seeds[plot.crop] || 0) + 2
        root.seedBank = seeds
        root.dew = Math.min(12, root.dew + definition.dewYield)
        root.pollen += definition.pollen
        root.harvests += 1
        if (plot.crop === root.dailyCrop)
            root.dailyProgress = Math.min(3, root.dailyProgress + 1)
        const next = root.plots.slice()
        next[index] = { crop: "", growth: 0, moisture: 0 }
        root.plots = next
        root.gardenNote = qsTr("Harvest gathered · %1 pollen, %2 seeds returned.").arg(definition.pollen).arg(2)
        root.persist()
    }

    function tend(index) {
        const plot = root.plots[index]
        if (!plot || !plot.crop) {
            root.plant(index)
        } else if (plot.growth >= 1) {
            root.harvest(index)
        } else {
            root.water(index)
        }
    }

    function claimDaily() {
        if (root.dailyProgress < 3 || root.dailyClaimed)
            return
        root.dailyClaimed = true
        root.pollen += 5
        root.dew = Math.min(12, root.dew + 2)
        root.gardenNote = qsTr("Garden spirit pleased · 5 pollen and 2 dew added.")
        root.persist()
    }

    function expandGarden() {
        const cost = root.gardenLevel === 1 ? 10 : 22
        if (root.gardenLevel >= 4 || root.pollen < cost)
            return
        root.gardenLevel += 1
        while (root.plots.length < root.plotCount)
            root.plots = root.plots.concat([{ crop: "", growth: 0, moisture: 0 }])
        root.pollen -= cost
        root.gardenNote = qsTr("A new patch of moonlit soil is yours.")
        root.persist()
    }

    function refillDew() {
        if (root.pollen < 2 || root.dew >= 12)
            return
        root.pollen -= 2
        root.dew = Math.min(12, root.dew + 3)
        root.gardenNote = qsTr("Three dew drops bottled for the next dry spell.")
        root.persist()
    }

    Component.onCompleted: loadProgress()
    onActiveChanged: {
        if (root.active) {
            root.forceActiveFocus()
        } else {
            root.advanceGrowth(Date.now())
            root.persist()
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.active
        onTriggered: {
            const before = root.lastGrowthAt
            root.advanceGrowth(Date.now())
            if (root.lastGrowthAt !== before)
                root.persist()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 13
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: qsTr("MOON ORCHARD · GARDEN %1").arg(root.gardenLevel); color: "#9BE7A2"; font.family: Theme.monoFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2 }
                Text { text: qsTr("A small place to grow"); color: "#F1F6F1"; font.family: Theme.displayFont; font.pixelSize: 23; font.weight: Font.Black }
            }
            Text { text: qsTr("✿ %1   ◌ %2   ☾ %3").arg(root.pollen).arg(root.dew).arg(root.harvests); color: "#C7E4CE"; font.family: Theme.monoFont; font.pixelSize: 13; font.weight: Font.Bold }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: qsTr("SEED SATCHEL"); color: "#82988A"; font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1 }
            Repeater {
                model: root.cropCatalog
                delegate: Button {
                    id: seedChoice
                    required property var modelData
                    readonly property bool selected: root.selectedCrop === modelData.id
                    text: modelData.icon + "  " + modelData.name + " · " + Number(root.seedBank[modelData.id] || 0)
                    onClicked: root.selectedCrop = modelData.id
                    enabled: Number(root.seedBank[modelData.id] || 0) > 0
                    background: Rectangle {
                        radius: 11
                        color: seedChoice.selected ? "#254133" : "#15251F"
                        border.width: 1
                        border.color: seedChoice.selected ? seedChoice.modelData.tint : "#30493A"
                    }
                    contentItem: Text {
                        text: seedChoice.text
                        color: seedChoice.enabled ? "#E2F1E5" : "#718176"
                        font.family: Theme.bodyFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    padding: 10
                }
            }
            Item { Layout.fillWidth: true }
            Text { text: qsTr("%1 · %2% growth").arg(root.weatherName).arg(Math.round(root.weatherMultiplier(root.dailyCrop) * 100)); color: "#A9C4AE"; font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold }
        }

        GridLayout {
            id: gardenGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 10
            columnSpacing: 10
            Repeater {
                model: root.plotCount
                delegate: Button {
                    id: plotCard
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readonly property var plot: root.plots[index] || ({ crop: "", growth: 0, moisture: 0 })
                    readonly property var definition: plot.crop ? root.crop(plot.crop) : root.crop(root.selectedCrop)
                    readonly property int stage: plot.growth >= 1 ? 4 : plot.growth >= 0.66 ? 3 : plot.growth >= 0.32 ? 2 : plot.crop ? 1 : 0
                    onClicked: root.tend(index)
                    contentItem: Column {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        spacing: 6
                        Text {
                            width: parent.width
                            text: plotCard.plot.crop ? (plotCard.stage === 4 ? "✿" : plotCard.definition.icon)
                                : (root.seedBank[root.selectedCrop] > 0 ? "＋" : "·")
                            color: plotCard.definition.tint
                            font.pixelSize: 34 + plotCard.stage * 3
                            font.weight: Font.Black
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            width: parent.width
                            text: qsTr("PATCH %1 · %2").arg(plotCard.index + 1)
                                .arg(plotCard.plot.crop ? plotCard.definition.name.toUpperCase() : qsTr("RESTING"))
                            color: "#ECF5ED"
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: parent.width * 0.78
                            height: 5
                            radius: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "#263A2D"
                            visible: plotCard.plot.crop !== ""
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, Number(plotCard.plot.growth)))
                                height: parent.height
                                radius: 3
                                color: plotCard.definition.tint
                                Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            }
                        }
                        Text {
                            width: parent.width
                            text: !plotCard.plot.crop ? qsTr("Plant %1").arg(root.cropName(root.selectedCrop))
                                : plotCard.stage === 4 ? qsTr("Ready · harvest")
                                : qsTr("Growing · %1% · water %2s").arg(Math.floor(plotCard.plot.growth * 100)).arg(Math.ceil(plotCard.plot.moisture))
                            color: "#AFC3B2"
                            font.family: Theme.bodyFont
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: plotCard.plot.crop ? (plotCard.stage === 4 ? qsTr("Gather +2 seeds") : root.dew > 0 ? qsTr("Tap to water · 1 dew") : qsTr("Waiting for dew"))
                                : Number(root.seedBank[root.selectedCrop] || 0) > 0 ? qsTr("Tap to plant") : qsTr("Choose another seed")
                            color: plotCard.stage === 4 ? "#C8F0CF" : "#82988A"
                            font.family: Theme.bodyFont
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    background: Rectangle {
                        radius: 17
                        color: plotCard.down ? "#21372B" : plotCard.plot.crop ? "#192A21" : "#14221B"
                        border.width: plotCard.stage === 4 ? 2 : 1
                        border.color: plotCard.stage === 4 ? "#8BE5A3" : plotCard.definition.tint
                        opacity: plotCard.enabled ? 1 : 0.75
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: dailyColumn.implicitHeight + 22
                radius: 14
                color: "#17231E"
                border.width: 1
                border.color: "#344A3A"
                Column {
                    id: dailyColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    spacing: 5
                    Text { text: qsTr("TODAY'S LITTLE PROMISE · %1").arg(root.weatherName); color: "#93B89C"; font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold }
                    Text { text: root.dailyPrompt + "  ·  " + root.dailyProgress + "/3"; color: "#E2F0E4"; font.family: Theme.bodyFont; font.pixelSize: 12; font.weight: Font.Bold }
                    Text { text: root.gardenNote !== "" ? root.gardenNote : qsTr("Offline growth is gentle; moisture lasts longer when you visit and water."); color: "#94A998"; font.family: Theme.bodyFont; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                }
            }
            Button {
                text: root.dailyClaimed ? qsTr("Promise kept") : qsTr("Claim dew + pollen")
                enabled: root.dailyProgress >= 3 && !root.dailyClaimed
                onClicked: root.claimDaily()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: root.gardenLevel >= 4 ? qsTr("Garden fully expanded")
                    : qsTr("Expand garden · %1 pollen").arg(root.gardenLevel === 1 ? 10 : 22)
                enabled: root.gardenLevel < 4 && root.pollen >= (root.gardenLevel === 1 ? 10 : 22)
                onClicked: root.expandGarden()
            }
            Button {
                text: qsTr("Bottle 3 dew · 2 pollen")
                enabled: root.pollen >= 2 && root.dew < 12
                onClicked: root.refillDew()
            }
            Item { Layout.fillWidth: true }
            Text { text: qsTr("THE ORCHARD GROWS WHILE YOU'RE AWAY"); color: "#718678"; font.family: Theme.monoFont; font.pixelSize: 9; font.weight: Font.Bold; horizontalAlignment: Text.AlignRight }
        }
    }
}
