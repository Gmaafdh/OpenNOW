import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

Column {
    id: studio
    objectName: "appearanceStudio"
    required property real availableWidth
    required property var settingsScreen
    required property var themeItems
    property string status: ""
    property bool statusIsError: false

    width: studio.availableWidth
    spacing: DesktopTokens.px(12)
    readonly property bool scheduleEnabled: settingsScreen.boolSetting("appearanceScheduleEnabled", false)
    readonly property string wallpaper: String(settingsScreen.valueSetting("desktopBackgroundImage", ""))

    function timeOptions() {
        const options = []
        for (let hour = 0; hour < 24; ++hour)
            options.push({label:String(hour).padStart(2, "0") + ":00", value:hour * 60})
        return options
    }

    function report(message, isError = false) {
        status = message
        statusIsError = isError
    }

    function repairAccent() {
        const current = Theme.focus.toString()
        const repaired = Theme.readableAccent(current, Theme.shell)
        if (current.toLowerCase() === repaired.toLowerCase()) {
            report(qsTr("This accent already passes the contrast checks."))
            return
        }
        settingsScreen.setChoice("appAccentColor", repaired.toUpperCase())
        report(qsTr("Readable accent %1 applied while preserving its hue.").arg(repaired.toUpperCase()))
    }

    function matchWallpaper() {
        if (wallpaper === "") {
            report(qsTr("Choose a custom background image first."), true)
            return
        }
        const result = ProfileImages.dominantColor(wallpaper)
        if (!result || result.ok !== true) {
            report(qsTr("OpenNOW could not read colors from this wallpaper. Try another local image."), true)
            return
        }
        const repaired = Theme.readableAccent(result.color, Theme.shell)
        settingsScreen.setChoice("appAccentColor", repaired.toUpperCase())
        report(qsTr("Wallpaper accent %1 extracted and contrast-checked.").arg(repaired.toUpperCase()))
    }

    function captureSlot(slot) {
        const result = ShellStore.captureLookSlot(slot)
        report(result === false || result === "" ? qsTr("OpenNOW could not save this look slot.") : qsTr("Look %1 captured on this device.").arg(slot),
            result === false || result === "")
    }

    function restoreSlot(slot) {
        const result = ShellStore.restoreLookSlot(slot)
        report(result === false || result === "" ? qsTr("This look slot is empty or invalid.") : qsTr("Look %1 restored.").arg(slot),
            result === false || result === "")
    }

    function clearSlot(slot) {
        const result = ShellStore.clearLookSlot(slot)
        report(result === false || result === "" ? qsTr("OpenNOW could not clear this look slot.") : qsTr("Look %1 cleared. Your current appearance is unchanged.").arg(slot),
            result === false || result === "")
    }

    function copyLook() {
        const copied = AppController.writeClipboardText(ShellStore.portableLookCode())
        report(copied ? qsTr("Portable look code copied. Local wallpaper paths and account data are not included.")
            : qsTr("The look code could not be copied to the clipboard."), !copied)
    }

    function pasteLook() {
        const imported = ShellStore.importLookCode(AppController.readClipboardText())
        report(imported ? qsTr("Portable look imported and applied.")
            : qsTr("The clipboard does not contain a valid OpenNOW look code."), !imported)
    }

    function slotTime(entry) {
        if (!entry || !entry.capturedAt) return ""
        const date = new Date(entry.capturedAt)
        return isNaN(date.getTime()) ? "" : Qt.formatDateTime(date, "yyyy-MM-dd · HH:mm")
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        objectName: "adaptiveAppearanceSettings"
        DesktopSettingsSection { text: qsTr("ADAPTIVE DAY & NIGHT") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sun"; title: qsTr("Appearance schedule")
            description: qsTr("Automatically switch complete looks at local times · overnight schedules supported")
            DesktopSettingsToggle {
                objectName: "appearanceScheduleEnabled"
                checked: studio.scheduleEnabled
                onValueChangedByUser: value => studio.settingsScreen.setSetting("appearanceScheduleEnabled", value)
            }
        }
        DesktopSettingsChoice {
            objectName: "appearanceDayPack"
            visible: studio.scheduleEnabled
            width: parent.width; glyph: "sun"; title: qsTr("Day look")
            description: qsTr("Theme used during the day portion of the schedule")
            items: studio.themeItems
            value: studio.settingsScreen.valueSetting("appearanceDayPack", "porcelain")
            onSelected: value => studio.settingsScreen.setSetting("appearanceDayPack", value)
        }
        DesktopSettingsChoice {
            objectName: "appearanceNightPack"
            visible: studio.scheduleEnabled
            width: parent.width; glyph: "moon"; title: qsTr("Night look")
            description: qsTr("Theme used during the night portion of the schedule")
            items: studio.themeItems
            value: studio.settingsScreen.valueSetting("appearanceNightPack", "nocturne")
            onSelected: value => studio.settingsScreen.setSetting("appearanceNightPack", value)
        }
        DesktopSettingsChoice {
            objectName: "appearanceDayStart"
            visible: studio.scheduleEnabled
            width: parent.width; glyph: "sun"; title: qsTr("Day starts")
            description: qsTr("Equal start times keep Day mode active")
            items: studio.timeOptions()
            value: Number(studio.settingsScreen.valueSetting("appearanceDayStart", 420))
            onSelected: value => studio.settingsScreen.setSetting("appearanceDayStart", value)
        }
        DesktopSettingsChoice {
            objectName: "appearanceNightStart"
            visible: studio.scheduleEnabled
            width: parent.width; glyph: "moon"; title: qsTr("Night starts")
            description: qsTr("Night can cross midnight without a second rule"); showDivider: false
            items: studio.timeOptions()
            value: Number(studio.settingsScreen.valueSetting("appearanceNightStart", 1140))
            onSelected: value => studio.settingsScreen.setSetting("appearanceNightStart", value)
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        objectName: "accentLaboratorySettings"
        DesktopSettingsSection { text: qsTr("ACCENT LABORATORY") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "palette"; title: qsTr("Accent harmonies")
            description: qsTr("Complement, analogous and triadic colors derived from your current accent")
            Row {
                spacing: DesktopTokens.px(8)
                Repeater {
                    model: Theme.accentHarmonies(Theme.customAccent)
                    delegate: AbstractButton {
                        required property string modelData
                        required property int index
                        objectName: "accentHarmony-" + index
                        width: DesktopTokens.px(36); height: DesktopTokens.px(30)
                        Accessible.name: [qsTr("Complement"), qsTr("Warm analogous"), qsTr("Cool analogous"), qsTr("First triadic"), qsTr("Second triadic")][index]
                        onClicked: studio.settingsScreen.setChoice("appAccentColor", modelData.toUpperCase())
                        background: Rectangle {
                            radius: DesktopTokens.radius(9); color: parent.modelData
                            border.width: parent.activeFocus ? 3 : 1; border.color: parent.activeFocus ? Theme.label : Theme.seam
                        }
                    }
                }
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "check"; title: qsTr("Smart accent repair")
            description: qsTr("Preserve the hue while finding a lightness that is readable on the current surfaces")
            DesktopSettingsButton {
                objectName: "repairAccent"; text: qsTr("Repair contrast"); compact: true
                onClicked: studio.repairAccent()
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "image"; title: qsTr("Wallpaper Color Match")
            description: qsTr("Extract a dominant color from your custom local wallpaper, then contrast-check it"); showDivider: false
            DesktopSettingsButton {
                objectName: "matchWallpaperAccent"; text: qsTr("Match wallpaper"); compact: true
                enabled: studio.wallpaper !== ""
                onClicked: studio.matchWallpaper()
            }
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        objectName: "surfaceStudioSettings"
        DesktopSettingsSection { text: qsTr("READABILITY, GLASS & MOTION") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sun"; title: qsTr("Contrast boost")
            description: qsTr("Strengthen secondary text and separators without changing the theme colors")
            DesktopSettingsSlider {
                objectName: "interfaceContrast"; from: 0; to: 100; stepSize: 5
                value: Number(studio.settingsScreen.valueSetting("interfaceContrast", 0))
                onMoved: value => ShellStore.applySetting("interfaceContrast", Math.round(value))
                onCommitted: value => studio.settingsScreen.setSetting("interfaceContrast", Math.round(value))
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "grid"; title: qsTr("Glass depth")
            description: qsTr("Tune panel opacity from airy to substantial across desktop and console")
            DesktopSettingsSlider {
                objectName: "glassDepth"; from: 0; to: 100; stepSize: 5
                value: Number(studio.settingsScreen.valueSetting("glassDepth", 50))
                onMoved: value => ShellStore.applySetting("glassDepth", Math.round(value))
                onCommitted: value => studio.settingsScreen.setSetting("glassDepth", Math.round(value))
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "wave"; title: qsTr("Motion tempo")
            description: qsTr("Calm slows transitions; Swift shortens them · Reduce motion still wins")
            DesktopSettingsSegmented {
                objectName: "motionTempo"
                options: [{label:qsTr("Calm"),value:"calm"},{label:qsTr("Standard"),value:"standard"},{label:qsTr("Swift"),value:"swift"}]
                selectedIndex: options.findIndex(item => item.value === studio.settingsScreen.valueSetting("motionTempo", "standard"))
                onSelected: (index,item) => studio.settingsScreen.setSetting("motionTempo", item.value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "grid"; title: qsTr("Corner geometry")
            description: qsTr("Reshape shared cards, artwork, panels and buttons"); showDivider: false
            DesktopSettingsSegmented {
                objectName: "cornerStyle"
                options: [{label:qsTr("Sharp"),value:"sharp"},{label:qsTr("Soft"),value:"soft"},{label:qsTr("Round"),value:"round"}]
                selectedIndex: options.findIndex(item => item.value === studio.settingsScreen.valueSetting("cornerStyle", "soft"))
                onSelected: (index,item) => studio.settingsScreen.setSetting("cornerStyle", item.value)
            }
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        objectName: "ambientStudioSettings"
        DesktopSettingsSection { text: qsTr("AMBIENT ENVIRONMENT") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sun"; title: qsTr("Ambient glow")
            description: qsTr("Control the colored light wash behind the interface · 0% removes it")
            DesktopSettingsSlider {
                objectName: "ambientGlow"; from: 0; to: 100; stepSize: 5
                value: Number(studio.settingsScreen.valueSetting("ambientGlow", 60))
                onMoved: value => ShellStore.applySetting("ambientGlow", Math.round(value))
                onCommitted: value => studio.settingsScreen.setSetting("ambientGlow", Math.round(value))
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "grid"; title: qsTr("Procedural pattern")
            description: qsTr("Resolution-independent Grid, Constellation or Contour linework")
            DesktopSettingsSegmented {
                objectName: "ambientPattern"; optionWidth: 72
                options: [{label:qsTr("None"),value:"none"},{label:qsTr("Grid"),value:"grid"},{label:qsTr("Stars"),value:"constellation"},{label:qsTr("Contour"),value:"contour"}]
                selectedIndex: options.findIndex(item => item.value === studio.settingsScreen.valueSetting("ambientPattern", "none"))
                onSelected: (index,item) => studio.settingsScreen.setSetting("ambientPattern", item.value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sliders"; title: qsTr("Pattern intensity")
            visible: Theme.ambientPattern !== "none"
            description: qsTr("Keep linework subtle or make it a visible part of the theme")
            DesktopSettingsSlider {
                objectName: "ambientPatternOpacity"; from: 0; to: 100; stepSize: 5
                value: Number(studio.settingsScreen.valueSetting("ambientPatternOpacity", 25))
                onMoved: value => ShellStore.applySetting("ambientPatternOpacity", Math.round(value))
                onCommitted: value => studio.settingsScreen.setSetting("ambientPatternOpacity", Math.round(value))
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "moon"; title: qsTr("Background dimming")
            description: qsTr("Add a readability scrim over artwork and ambience")
            DesktopSettingsSlider {
                objectName: "backgroundDim"; from: 0; to: 100; stepSize: 5
                value: Number(studio.settingsScreen.valueSetting("backgroundDim", 0))
                onMoved: value => ShellStore.applySetting("backgroundDim", Math.round(value))
                onCommitted: value => studio.settingsScreen.setSetting("backgroundDim", Math.round(value))
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "image"; title: qsTr("Wallpaper fit")
            description: qsTr("Fill crops, Fit preserves the whole image, Stretch fills exactly"); showDivider: false
            DesktopSettingsSegmented {
                objectName: "backgroundFit"; optionWidth: 78
                options: [{label:qsTr("Fill"),value:"cover"},{label:qsTr("Fit"),value:"fit"},{label:qsTr("Stretch"),value:"stretch"}]
                selectedIndex: options.findIndex(item => item.value === studio.settingsScreen.valueSetting("backgroundFit", "cover"))
                onSelected: (index,item) => studio.settingsScreen.setSetting("backgroundFit", item.value)
            }
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        objectName: "lookLibrarySettings"
        DesktopSettingsSection { text: qsTr("LOOK LIBRARY") }
        Repeater {
            model: 4
            delegate: DesktopSettingsRow {
                id: slotRow
                required property int index
                readonly property int slot: index + 1
                readonly property var saved: ShellStore.lookSlotData(slot)
                objectName: "lookSlot-" + slot
                width: studio.availableWidth; paperStyle: true; glyph: "folder"; title: qsTr("Look %1").arg(slot)
                description: saved ? qsTr("Captured %1 · recapture to replace").arg(studio.slotTime(saved)) : qsTr("Empty local slot · capture your current complete appearance")
                Row {
                    spacing: DesktopTokens.px(6)
                    DesktopSettingsButton {
                        objectName: "captureLookSlot-" + slotRow.slot
                        text: qsTr("Capture"); primary: true; compact: true
                        onClicked: studio.captureSlot(slotRow.slot)
                    }
                    DesktopSettingsButton {
                        objectName: "restoreLookSlot-" + slotRow.slot
                        text: qsTr("Restore"); compact: true; visible: slotRow.saved !== null
                        onClicked: studio.restoreSlot(slotRow.slot)
                    }
                    DesktopSettingsButton {
                        objectName: "clearLookSlot-" + slotRow.slot
                        text: qsTr("Forget"); compact: true; visible: slotRow.saved !== null
                        onClicked: studio.clearSlot(slotRow.slot)
                    }
                }
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "reset"; title: qsTr("Portable look code")
            description: qsTr("Copy or paste a validated appearance recipe · no account data or local image paths")
            Row {
                spacing: DesktopTokens.px(8)
                DesktopSettingsButton {
                    objectName: "copyLookCode"; text: qsTr("Copy"); compact: true
                    onClicked: studio.copyLook()
                }
                DesktopSettingsButton {
                    objectName: "pasteLookCode"; text: qsTr("Paste & apply"); primary: true; compact: true
                    onClicked: studio.pasteLook()
                }
            }
        }
        DesktopSettingsRow {
            objectName: "appearanceStudioStatus"
            width: parent.width; paperStyle: true; glyph: studio.statusIsError ? "info" : "check"
            visible: studio.status !== ""
            title: studio.statusIsError ? qsTr("Appearance Studio") : qsTr("Appearance Studio updated")
            description: studio.status; showDivider: false
        }
    }
}
