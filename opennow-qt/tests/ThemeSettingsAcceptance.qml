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

        screen.setChoice("themePack", light ? "bone" : "aurora")
        if (!light) find(parent, "themeAccent-violet").clicked()
        ShellStore.lastError = ""
        return true
    }
}
