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
        const studio = find(parent, "appearanceStudio")
        check(studio !== null, "Appearance Studio exists")
        check(find(parent, "matchWallpaperAccent") !== null, "wallpaper color extraction action exists")
        screen.setSetting("appearanceDayPack", "porcelain")
        screen.setSetting("appearanceNightPack", "celestial")
        screen.setSetting("appearanceDayStart", 420)
        screen.setSetting("appearanceNightStart", 1140)
        screen.setSetting("appearanceScheduleEnabled", true)
        Theme.studioNow = new Date(2026, 9, 30, 12, 0)
        check(Theme.themePack === "porcelain" && Theme.lightMode, "schedule applies the day look")
        Theme.studioNow = new Date(2026, 9, 30, 23, 0)
        check(Theme.themePack === "celestial" && !Theme.lightMode, "schedule applies the night look")
        screen.setSetting("appearanceScheduleEnabled", false)

        const expectedHarmony = Theme.accentHarmonies(Theme.customAccent)[0]
        const harmonyButton = find(parent, "accentHarmony-0")
        check(harmonyButton !== null, "accent harmony swatch exists")
        harmonyButton.clicked()
        check(ShellStore.settings.appAccentColor.toLowerCase() === expectedHarmony.toLowerCase(),
            "harmony swatch applies its generated color")
        screen.setChoice("appAccentColor", "#444444")
        find(parent, "repairAccent").clicked()
        check(Theme.usableAccent(Theme.focus, Theme.shell), "smart repair produces a readable accent")

        const contrastSlider = find(parent, "interfaceContrast")
        contrastSlider.moved(80)
        check(Theme.contrastLevel === 0.8, "contrast slider previews live")
        contrastSlider.committed(80)
        const glassSlider = find(parent, "glassDepth")
        glassSlider.moved(75)
        check(Theme.glassLevel === 0.75, "glass slider previews live")
        glassSlider.committed(75)
        screen.setSetting("ambientPattern", "constellation")
        screen.setSetting("ambientPatternOpacity", 45)
        check(Theme.ambientPattern === "constellation" && Theme.patternOpacity === 0.45,
            "procedural pattern reaches the shared renderer")
        screen.setSetting("backgroundDim", 55)
        screen.setSetting("backgroundFit", "fit")
        screen.setSetting("motionTempo", "calm")
        screen.setSetting("cornerStyle", "round")
        check(Theme.backgroundDim === 0.55 && Theme.backgroundFillMode === Image.PreserveAspectFit,
            "wallpaper controls reach the theme")
        check(Theme.motionMultiplier === 1.5 && Theme.cornerScale === 1.65,
            "motion and corner geometry reach shared components")

        screen.setChoice("themePack", "lagoon")
        screen.setSetting("glassDepth", 85)
        find(parent, "captureLookSlot-1").clicked()
        check(ShellStore.lookSlotData(1) !== null, "first look slot captures")
        screen.setChoice("themePack", "bone")
        screen.setSetting("glassDepth", 15)
        find(parent, "captureLookSlot-2").clicked()
        check(ShellStore.lookSlotData(2) !== null, "second look slot captures independently")
        find(parent, "restoreLookSlot-1").clicked()
        check(ShellStore.settings.themePack === "lagoon" && ShellStore.settings.glassDepth === 85,
            "first slot restores its complete look")
        check(ShellStore.lookSlotData(2) !== null, "restoring one slot preserves another")
        find(parent, "clearLookSlot-1").clicked()
        check(ShellStore.lookSlotData(1) === null && ShellStore.lookSlotData(2) !== null,
            "forget removes only the selected slot")
        for (const slot of [3, 4]) {
            find(parent, "captureLookSlot-" + slot).clicked()
            check(ShellStore.lookSlotData(slot) !== null, "additional look slot captures: " + slot)
            find(parent, "clearLookSlot-" + slot).clicked()
            check(ShellStore.lookSlotData(slot) === null, "additional look slot clears: " + slot)
        }

        screen.setChoice("themePack", "ember")
        screen.setSetting("desktopBackground", "custom")
        screen.setSetting("desktopBackgroundImage", "file:///C:/private/appearance-wallpaper.png")
        screen.setSetting("appearanceScheduleEnabled", true)
        const lookCode = ShellStore.portableLookCode()
        check(lookCode.indexOf("private") < 0 && lookCode.indexOf("wallpaper") < 0,
            "portable look excludes local wallpaper paths")
        check(AppController.writeClipboardText(lookCode), "portable look can be copied")
        screen.setChoice("themePack", "bone")
        screen.setSetting("desktopBackground", "art")
        screen.setSetting("appearanceScheduleEnabled", false)
        studio.pasteLook()
        check(ShellStore.settings.themePack === "ember" && ShellStore.settings.desktopBackground === "gradient"
            && ShellStore.settings.desktopBackgroundImage === "" && ShellStore.settings.appearanceScheduleEnabled === true,
            "clipboard look imports with portable background fallback")
        const beforeInvalid = ShellStore.settings.themePack
        check(!ShellStore.importLookCode('{"kind":"opennow-appearance","version":1,"look":{"version":1,"themePack":"lagoon","glassDepth":"invalid"}}'),
            "malformed portable look is rejected")
        check(ShellStore.settings.themePack === beforeInvalid, "invalid import does not change appearance")
        studio.copyLook()
        check(AppController.readClipboardText().indexOf("opennow-appearance") >= 0, "studio copy action writes a look code")

        appearance.lookStatus = ""
        studio.status = ""
        Theme.studioNow = new Date()
        for (const slot of [1, 2, 3, 4]) ShellStore.clearLookSlot(slot)
        screen.setSetting("appearanceScheduleEnabled", false)
        screen.setSetting("appearanceDayPack", "porcelain")
        screen.setSetting("appearanceNightPack", "nocturne")
        screen.setSetting("appearanceDayStart", 420)
        screen.setSetting("appearanceNightStart", 1140)
        screen.setSetting("interfaceContrast", 0)
        screen.setSetting("glassDepth", 50)
        screen.setSetting("ambientGlow", 60)
        screen.setSetting("ambientPattern", "none")
        screen.setSetting("ambientPatternOpacity", 25)
        screen.setSetting("backgroundDim", 0)
        screen.setSetting("backgroundFit", "cover")
        screen.setSetting("motionTempo", "standard")
        screen.setSetting("cornerStyle", "soft")
        screen.setSetting("desktopBackgroundImage", "")
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
