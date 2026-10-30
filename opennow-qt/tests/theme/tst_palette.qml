import QtQuick
import QtTest
import OpenNOW.ThemeTests

TestCase {
    name: "ThemePalette"

    SettingsState {
        id: settingsState
        coreClient: null
        appController: AppController
        i18n: null
        ready: false
        subscription: null
        authSession: null
        nativeRuntimeReady: false
        nativeRuntimeCapabilities: ({})
        refreshAccountServices: function() {}
        refreshStreamerDetection: function() {}
        syncDiscordPresence: function() {}
        lastError: ""
    }

    function init() {
        ShellStore.previewThemePack = ""
        ShellStore.settings = {themePack:"nocturne", appTheme:"dark", appAccentColor:"green", themeAccentOverride:false}
        settingsState.settings = ShellStore.settings
    }

    function luminance(color) {
        const linear = value => value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        return linear(color.r) * 0.2126 + linear(color.g) * 0.7152 + linear(color.b) * 0.0722
    }

    function contrast(first, second) {
        const a = luminance(first)
        const b = luminance(second)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }

    function test_palette_data() {
        const rows = []
        for (const pack of Theme.packs) {
            for (const mode of ["light", "dark"]) {
                for (const accent of ["pack"].concat(Theme.accentChoices))
                    rows.push({tag:pack.id + "-" + mode + "-" + accent, pack:pack.id, mode:mode, accent:accent})
            }
        }
        return rows
    }

    function test_palette(data) {
        ShellStore.settings = {themePack:data.pack, appTheme:data.mode, appAccentColor:data.accent, themeAccentOverride:data.accent !== "pack"}
        compare(Theme.lightMode, data.mode === "light")
        verify(contrast(Theme.label, Theme.shell) >= 7)
        verify(contrast(Theme.focus, Theme.shell) >= 3)
        verify(contrast(Theme.focusText, Theme.focus) >= 4.5)
        compare(Theme.glass.r.toFixed(2), Theme.shell.r.toFixed(2))
        compare(Theme.atmosphere.toString(), Qt.color(Theme.pack.mid).toString())
        compare(Theme.focus, data.accent === "pack" ? Theme.packAccent : Theme.customAccent)
    }

    function test_themeCollection() {
        verify(Theme.packs.length >= 20)
        const ids = []
        for (const pack of Theme.packs) {
            verify(ids.indexOf(pack.id) < 0, "Duplicate theme id: " + pack.id)
            ids.push(pack.id)
            verify(pack.name.length > 0)
            verify(["Dark", "Light", "High contrast"].indexOf(pack.category) >= 0)
            verify(/^#[0-9A-Fa-f]{6}$/.test(pack.bg), pack.id + " background")
            verify(/^#[0-9A-Fa-f]{6}$/.test(pack.lightBg || pack.darkBg), pack.id + " alternate background")
            verify(/^#[0-9A-Fa-f]{6}$/.test(pack.mid), pack.id + " atmosphere")
            verify(/^#[0-9A-Fa-f]{6}$/.test(pack.accent), pack.id + " accent")
            verify(/^#[0-9A-Fa-f]{6}$/.test(pack.lightAccent || pack.darkAccent), pack.id + " alternate accent")
        }
    }

    function test_themeFusion() {
        const first = Theme.packs.find(pack => pack.id === "nocturne")
        const second = Theme.packs.find(pack => pack.id === "chapel")
        const mix = (a, b) => {
            const firstColor = Qt.color(a)
            const secondColor = Qt.color(b)
            return Qt.rgba((firstColor.r + secondColor.r) / 2, (firstColor.g + secondColor.g) / 2,
                           (firstColor.b + secondColor.b) / 2, 1)
        }
        ShellStore.settings = {themePack:first.id, appTheme:"dark", themeFusionEnabled:true,
            themeFusionPack:second.id, themeFusionBalance:50, themeAccentOverride:false}
        compare(Theme.shell.toString(), mix(first.bg, second.bg).toString())
        compare(Theme.atmosphere.toString(), mix(first.mid, second.mid).toString())
        verify(Theme.contrastRatio(Theme.focus, Theme.shell) >= 3)
        verify(Theme.contrastRatio(Theme.focusText, Theme.focus) >= 4.5)
        verify(Theme.contrastRatio(Theme.mediaAccent, "#04060A") >= 4.5)
        ShellStore.settings = Object.assign({}, ShellStore.settings, {themeFusionBalance:0})
        compare(Theme.shell.toString(), Qt.color(first.bg).toString())
        compare(Theme.focus.toString(), Qt.color(first.accent).toString())
        ShellStore.settings = Object.assign({}, ShellStore.settings, {themeFusionBalance:100})
        compare(Theme.shell.toString(), Qt.color(second.bg).toString())
        compare(Theme.focus.toString(), Qt.color(second.accent).toString())
        ShellStore.settings = Object.assign({}, ShellStore.settings, {themeFusionEnabled:false, themeFusionBalance:50})
        compare(Theme.shell.toString(), Qt.color(first.bg).toString())

        const bone = Theme.packs.find(pack => pack.id === "bone")
        const cobalt = Theme.packs.find(pack => pack.id === "cobalt")
        ShellStore.settings = {themePack:bone.id, appTheme:"light", themeFusionEnabled:true,
            themeFusionPack:cobalt.id, themeFusionBalance:50, themeAccentOverride:false}
        compare(Theme.shell.toString(), mix(bone.bg, cobalt.bg).toString())
    }

    function test_fusionContrastSafety() {
        for (const first of Theme.packs) {
            for (const second of Theme.packs) {
                for (const mode of ["light", "dark"]) {
                    const light = mode === "light"
                    const surface = Theme.mixColors(Theme.surfaceForPack(first, light),
                        Theme.surfaceForPack(second, light), 50)
                    const accent = Theme.fusedAccent(Theme.accentForPack(first, light),
                        Theme.accentForPack(second, light), surface)
                    const label = first.id + "+" + second.id + " " + mode
                    verify(Theme.contrastRatio(accent, surface) >= 3, label)
                    verify(Theme.contrastRatio(Theme.contrastText(accent), accent) >= 4.5, label)
                }
            }
        }
    }

    function test_dailyMuse() {
        const date = new Date(2026, 9, 30)
        const muse = Theme.dailyMuse(date, "profile-a")
        compare(JSON.stringify(muse), JSON.stringify(Theme.dailyMuse(date, "profile-a")))
        verify(Theme.packs.some(pack => pack.id === muse.primary))
        verify(Theme.packs.some(pack => pack.id === muse.secondary))
        verify(muse.primary !== muse.secondary)
        verify([25, 35, 50, 65, 75].indexOf(muse.balance) >= 0)
    }

    function test_customHexAccentAndFont() {
        compare(Theme.accentColor("#A1B2C3"), "#a1b2c3")
        ShellStore.settings = {themePack:"nocturne",appTheme:"dark",appAccentColor:"#12ABEF",themeAccentOverride:true,appFontFamily:"Verdana"}
        compare(Theme.focus, Theme.customAccent)
        compare(Theme.bodyFont, "Verdana")
        compare(Theme.displayFont, "Verdana")
        compare(Theme.monoFont, "IBM Plex Mono")
    }

    function test_autoFollowsSystem() {
        for (const pack of Theme.packs) {
            ShellStore.settings = {themePack:pack.id, appTheme:"auto"}
            compare(Theme.lightMode, Qt.styleHints.colorScheme === Qt.Light)
        }
    }

    function test_previewRestoresOverrides() {
        ShellStore.settings = {themePack:"aurora", appTheme:"dark", appAccentColor:"violet", themeAccentOverride:true}
        const originalShell = Theme.shell
        const originalAccent = Theme.focus
        ShellStore.previewThemePack = "bone"
        compare(Theme.lightMode, true)
        compare(Theme.accentOverridden, false)
        compare(Theme.focus, Theme.packAccent)
        ShellStore.previewThemePack = ""
        compare(Theme.lightMode, false)
        compare(Theme.shell, originalShell)
        compare(Theme.focus, originalAccent)
        ShellStore.settings = {themePack:"bone", appTheme:"light"}
        ShellStore.previewThemePack = "aurora"
        compare(Theme.lightMode, false)
        ShellStore.previewThemePack = ""
        compare(Theme.lightMode, true)
    }

    function test_optimisticSettingsMatchPersistedCoupling() {
        for (const pack of Theme.packs) {
            settingsState.applySetting("appAccentColor", "rose")
            compare(settingsState.settings.themeAccentOverride, true)
            settingsState.applySetting("themePack", pack.id)
            compare(settingsState.settings.themeAccentOverride, false)
            compare(settingsState.settings.appTheme, pack.category === "Light" ? "light" : "dark")
            settingsState.applySetting("appTheme", "auto")
            settingsState.applySetting("appAccentColor", "violet")
            compare(settingsState.settings.appTheme, "auto")
            compare(settingsState.settings.themePack, pack.id)
            compare(settingsState.settings.themeAccentOverride, true)
        }
    }
}
