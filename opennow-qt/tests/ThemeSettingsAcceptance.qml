import QtQuick
import OpenNOW

QtObject {
    function check(ok, message) {
        if (!ok) {
            console.error("Theme settings: " + message)
            throw new Error("Theme settings: " + message)
        }
    }

    function find(parent, name) {
        if (parent.objectName === name) return parent
        for (const child of parent.children || []) {
            const match = find(child, name)
            if (match) return match
        }
        return null
    }

    function run(parent) {
        const screen = find(parent, "desktopSettingsScreen")
        check(screen !== null, "desktop settings exists")
        const picker = find(parent, "renewThemeChoice")
        check(picker !== null, "theme picker exists")
        const options = picker.items.filter(item => item.kind !== "heading")
        check(options.length === Theme.packs.length, "every theme appears in the desktop picker")
        for (const pack of Theme.packs)
            check(options.some(item => item.value === pack.id), "picker contains " + pack.id)
        const light = Qt.application.arguments.indexOf("--smoke-light-theme") >= 0
        for (const pack of Theme.packs) {
            screen.setChoice("themePack", pack.id)
            check(Theme.lightMode === (pack.category === "Light"), "pack applies appearance: " + pack.id)
            check(!Theme.accentOverridden, "pack resets override")
            for (const accent of Theme.accentChoices) {
                const swatch = find(parent, "themeAccent-" + accent)
                check(swatch !== null, "accent swatch exists: " + accent)
                swatch.clicked()
                check(swatch.checked && Theme.accentOverridden, "accent selection is active")
                check(Theme.focus === Theme.customAccent, "accent reaches palette")
            }
            const reset = find(parent, "themePackAccent")
            check(reset !== null, "pack accent reset exists")
            reset.clicked()
            check(!Theme.accentOverridden && Theme.focus === Theme.packAccent, "pack accent restored")
        }
        check(find(parent, "chooseProfileImage") !== null, "profile image picker exists")
        check(find(parent, "profileImageSize") !== null, "profile export dimensions exist")
        screen.setChoice("appAccentColor", "#12ABEF")
        check(Theme.accent.toLowerCase() === "#12abef", "custom hex accent is normalized")
        check(Theme.focus === Theme.customAccent, "custom hex accent reaches palette")
        screen.setChoice("appFontFamily", "Verdana")
        check(Theme.bodyFont === "Verdana" && Theme.displayFont === "Verdana", "font reaches live theme")
        screen.setChoice("appFontFamily", "Nunito")

        const first = {userId:"acceptance-avatar-a",displayName:"First"}
        const second = {userId:"acceptance-avatar-b",displayName:"Second"}
        ShellStore.setCustomProfileImage(first, "file:///C:/tmp/first.png")
        ShellStore.setCustomProfileImage(second, "file:///C:/tmp/second.png")
        check(ShellStore.customProfileImageFor(first) === "file:///C:/tmp/first.png", "first avatar is stored")
        check(ShellStore.customProfileImageFor(second) === "file:///C:/tmp/second.png", "avatar storage is per account")
        check(ShellStore.setCustomProfileImage(first, "https://example.com/avatar.png") === false, "remote avatar override is rejected")
        ShellStore.setCustomProfileImage(first, "")
        check(ShellStore.customProfileImageFor(first) === "", "avatar removal restores fallback")
        check(ShellStore.customProfileImageFor(second) === "file:///C:/tmp/second.png", "removal does not clear another account")
        ShellStore.setCustomProfileImage(second, "")

        const appearance = find(parent, "desktopAppearanceSettings")
        const fusionSlider = find(parent, "themeFusionBalance")
        check(appearance !== null && fusionSlider !== null, "Fusion controls exist")
        check(find(parent, "dailyMuseButton") !== null, "Daily Muse action exists")
        screen.setChoice("themePack", "nocturne")
        screen.setSetting("themeFusionPack", "chapel")
        screen.setSetting("themeFusionBalance", 50)
        screen.setSetting("themeFusionEnabled", true)
        const midpoint = Theme.shell.toString()
        fusionSlider.moved(65)
        check(Theme.fusionBalance === 65, "Fusion slider updates the theme before commit")
        check(Theme.shell.toString() !== midpoint, "Fusion slider changes live colors")
        fusionSlider.committed(65)
        const muse = appearance.applyDailyMuse(new Date(2026, 9, 30))
        check(ShellStore.settings.themePack === muse.primary
            && ShellStore.settings.themeFusionPack === muse.secondary
            && ShellStore.settings.themeFusionBalance === muse.balance
            && Theme.fusionEnabled, "Daily Muse applies its deterministic recipe")

        screen.setChoice("themePack", "lagoon")
        screen.setSetting("appTheme", "dark")
        screen.setChoice("appAccentColor", "#12ABEF")
        screen.setSetting("appFontFamily", "Verdana")
        screen.setSetting("posterSizeScale", 1.25)
        screen.setSetting("translucentUI", true)
        screen.setSetting("showTileLabels", false)
        screen.setSetting("desktopBackground", "gradient")
        screen.setSetting("desktopBackgroundOpacity", 45)
        screen.setSetting("themeFusionPack", "celestial")
        screen.setSetting("themeFusionBalance", 65)
        screen.setSetting("themeFusionEnabled", true)
        find(parent, "captureLookMemory").clicked()
        const memory = ShellStore.lookMemoryData()
        check(memory !== null && memory.themePack === "lagoon" && memory.themeFusionBalance === 65,
            "Look Memory captures the complete appearance")
        screen.setChoice("themePack", "bone")
        screen.setChoice("appAccentColor", "green")
        screen.setSetting("appFontFamily", "Arial")
        screen.setSetting("posterSizeScale", 0.9)
        screen.setSetting("translucentUI", false)
        screen.setSetting("showTileLabels", true)
        screen.setSetting("desktopBackground", "art")
        screen.setSetting("themeFusionEnabled", false)
        find(parent, "restoreLookMemory").clicked()
        check(ShellStore.settings.themePack === "lagoon" && ShellStore.settings.appTheme === "dark",
            "Look Memory restores theme and appearance mode")
        check(ShellStore.settings.appAccentColor === "#12ABEF" && ShellStore.settings.themeAccentOverride === true,
            "Look Memory restores custom accent coupling")
        check(ShellStore.settings.appFontFamily === "Verdana" && ShellStore.settings.posterSizeScale === 1.25,
            "Look Memory restores font and density")
        check(ShellStore.settings.translucentUI === true && ShellStore.settings.showTileLabels === false
            && ShellStore.settings.desktopBackground === "gradient" && ShellStore.settings.desktopBackgroundOpacity === 45,
            "Look Memory restores surface, labels and background")
        check(ShellStore.settings.themeFusionEnabled === true && ShellStore.settings.themeFusionPack === "celestial"
            && ShellStore.settings.themeFusionBalance === 65, "Look Memory restores Fusion")
        find(parent, "clearLookMemory").clicked()
        check(ShellStore.lookMemoryData() === null && ShellStore.settings.themePack === "lagoon",
            "Forget clears memory without changing the current look")
        appearance.lookStatus = ""
        screen.setSetting("themeFusionEnabled", false)
        screen.setSetting("appFontFamily", "Nunito")
        screen.setSetting("posterSizeScale", 1.05)
        screen.setSetting("translucentUI", false)
        screen.setSetting("showTileLabels", true)
        screen.setSetting("desktopBackground", "art")
        screen.setSetting("desktopBackgroundOpacity", 30)
        screen.setSetting("themeAccentOverride", false)
        screen.setChoice("themePack", light ? "porcelain" : "celestial")
        ShellStore.lastError = ""
        return true
    }
}
