pragma Singleton
import QtQuick

QtObject {
    readonly property var packs: [
        {id:"nocturne", name:"Nocturne", author:"OPENNOW", category:"Dark", detail:"SKY GLASS", bg:"#0B0F1A", lightBg:"#EEF3FA", mid:"#252A48", accent:"#7FD4FF", lightAccent:"#12638C"},
        {id:"aurora", name:"Aurora", author:"OPENNOW", category:"Dark", detail:"MINT AURORA", bg:"#071A20", lightBg:"#EAF5F2", mid:"#16434A", accent:"#6EE7B7", lightAccent:"#126B4E"},
        {id:"kraft", name:"Kraft", author:"OPENNOW", category:"Dark", detail:"WARM BRASS", bg:"#211D17", lightBg:"#F4ECDD", mid:"#756346", accent:"#D3A85C", lightAccent:"#796020"},
        {id:"phosphor", name:"Phosphor", author:"OPENNOW", category:"High contrast", detail:"CRT GLOW", bg:"#07120B", lightBg:"#EDF8EA", mid:"#12351D", accent:"#6BFF8A", lightAccent:"#216C31"},
        {id:"bone", name:"Bone", author:"OPENNOW", category:"Light", detail:"WARM MINIMAL", bg:"#EEE7DB", darkBg:"#201D18", mid:"#A89578", accent:"#7F6A4D", darkAccent:"#D3BA91"},
        {id:"cobalt", name:"Cobalt", author:"OPENNOW", category:"Light", detail:"COBALT PAPER", bg:"#F7F9FF", darkBg:"#0E1730", mid:"#ADC4FF", accent:"#245BDB", darkAccent:"#93B5FF"},
        {id:"hibiscus", name:"Hibiscus", author:"OPENNOW", category:"Dark", detail:"ROSE GLASS", bg:"#1F0C18", lightBg:"#FAEDF3", mid:"#642343", accent:"#FF6F9F", lightAccent:"#AA285B"},
        {id:"chapel", name:"Chapel", author:"OPENNOW", category:"Dark", detail:"GOLD GLASS", bg:"#151225", lightBg:"#F3EFF9", mid:"#40355D", accent:"#FFD166", lightAccent:"#806017"},
        {id:"celestial", name:"Celestial", author:"OPENNOW", category:"Dark", detail:"STARLIGHT LILAC", bg:"#0D1026", lightBg:"#F0F0FF", mid:"#403A78", accent:"#B9A7FF", lightAccent:"#5B3FA8"},
        {id:"sakura", name:"Sakura", author:"OPENNOW", category:"Dark", detail:"CHERRY NIGHT", bg:"#21101D", lightBg:"#FFF0F6", mid:"#71314F", accent:"#FFB3D1", lightAccent:"#9E285D"},
        {id:"lagoon", name:"Lagoon", author:"OPENNOW", category:"Dark", detail:"ABYSSAL CYAN", bg:"#071E2B", lightBg:"#E9F8FC", mid:"#14536B", accent:"#69E3F2", lightAccent:"#0C6675"},
        {id:"ember", name:"Ember", author:"OPENNOW", category:"Dark", detail:"WARM AFTERGLOW", bg:"#241310", lightBg:"#FFF2E9", mid:"#74392B", accent:"#FFB07C", lightAccent:"#9A421F"},
        {id:"evergreen", name:"Evergreen", author:"OPENNOW", category:"Dark", detail:"FOREST SAGE", bg:"#0D1C17", lightBg:"#EDF7F0", mid:"#285844", accent:"#A8D5A2", lightAccent:"#356B45"},
        {id:"ultraviolet", name:"Ultraviolet", author:"OPENNOW", category:"Dark", detail:"ELECTRIC ORCHID", bg:"#170D2B", lightBg:"#F4EFFF", mid:"#522A85", accent:"#C39AFF", lightAccent:"#6537A5"},
        {id:"rosewood", name:"Rosewood", author:"OPENNOW", category:"Dark", detail:"ROSE GOLD", bg:"#251419", lightBg:"#FCF0F1", mid:"#75404B", accent:"#F2A6A6", lightAccent:"#934147"},
        {id:"porcelain", name:"Porcelain", author:"OPENNOW", category:"Light", detail:"PORCELAIN SLATE", bg:"#F4F6F8", darkBg:"#171B21", mid:"#B7C3CF", accent:"#40566F", darkAccent:"#AFC6DE"},
        {id:"daybreak", name:"Daybreak", author:"OPENNOW", category:"Light", detail:"IVORY CORAL", bg:"#FFF4E8", darkBg:"#2A1917", mid:"#E5B49D", accent:"#A64732", darkAccent:"#FFB08E"},
        {id:"meadow", name:"Meadow", author:"OPENNOW", category:"Light", detail:"MINT PAPER", bg:"#F1F8EC", darkBg:"#172217", mid:"#ACC9A1", accent:"#3D6C35", darkAccent:"#B3D99A"},
        {id:"lavender", name:"Lavender", author:"OPENNOW", category:"Light", detail:"LILAC PAPER", bg:"#F7F2FC", darkBg:"#21182C", mid:"#C8B4DD", accent:"#67458D", darkAccent:"#D1B4F0"},
        {id:"monochrome", name:"Monochrome", author:"OPENNOW", category:"High contrast", detail:"MONO SIGNAL", bg:"#050505", lightBg:"#FFFFFF", mid:"#4A4A4A", accent:"#FFFFFF", lightAccent:"#111111"}
    ]
    readonly property string mode: String(ShellStore.settings.appTheme || "auto")
    readonly property string themePack: ShellStore.previewThemePack !== ""
                                        ? ShellStore.previewThemePack
                                        : String(ShellStore.settings.themePack || "nocturne")
    readonly property var pack: packs.find(item => item.id === themePack) || packs[0]
    readonly property var fusionPack: packs.find(item => item.id === String(ShellStore.settings.themeFusionPack || "aurora")) || packs[1]
    readonly property bool fusionEnabled: ShellStore.settings.themeFusionEnabled === true
    readonly property real fusionBalance: {
        const value = Number(ShellStore.settings.themeFusionBalance)
        return isFinite(value) ? Math.max(0, Math.min(100, value)) : 50
    }
    readonly property bool packLight: pack.category === "Light"
    readonly property bool systemLight: Qt.styleHints.colorScheme === Qt.Light
    readonly property bool lightMode: ShellStore.previewThemePack !== "" ? packLight
        : mode === "light" || (mode === "auto" && systemLight)
    readonly property bool translucent: Boolean(ShellStore.settings.translucentUI)
    readonly property string accent: String(ShellStore.settings.appAccentColor || "blue")
    readonly property color shell: fusionEnabled ? mixColors(surfaceForPack(pack), surfaceForPack(fusionPack)) : surfaceForPack(pack)
    readonly property color face: lightMode ? "#111827" : "#FFFFFF"
    readonly property color faceText: lightMode ? "#FFFFFF" : "#111827"
    // Artwork scrims and dark store-color fallbacks always need a light foreground,
    // independently of the shell's light/dark mode.
    readonly property color mediaForeground: "#FFFFFF"
    readonly property color mediaMuted: Qt.rgba(mediaForeground.r, mediaForeground.g, mediaForeground.b, 0.64)
    readonly property color mediaAccent: accentOverridden ? accentColor(accent, false)
        : fusionEnabled ? fusedAccent(pack.darkAccent || pack.accent, fusionPack.darkAccent || fusionPack.accent, "#04060A", 4.5)
        : (pack.darkAccent || pack.accent)
    readonly property color seam: lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.14) : Qt.rgba(1, 1, 1, 0.14)
    readonly property color label: lightMode ? "#111827" : "#FFFFFF"
    readonly property color textMuted: lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.64) : Qt.rgba(1, 1, 1, 0.64)
    readonly property var accentChoices: ["green", "blue", "violet", "rose", "coral", "amber", "white"]
    function accentColor(value, forLightMode = lightMode) {
        if (/^#[0-9a-fA-F]{6}$/.test(value)) return value.toLowerCase()
        const dark = {green:"#6EE7B7", blue:"#7FD4FF", violet:"#A78BFA", rose:"#FF8A9A", coral:"#FF8A80", amber:"#FFD166", white:"#FFFFFF"}
        const light = {green:"#126B4E", blue:"#12638C", violet:"#7042BA", rose:"#AA285B", coral:"#A9362C", amber:"#806017", white:"#374151"}
        return (forLightMode ? light : dark)[value] || (forLightMode ? light.blue : dark.blue)
    }

    function surfaceForPack(pack, forLightMode = lightMode) {
        return forLightMode ? (pack.lightBg || pack.bg) : (pack.darkBg || pack.bg)
    }

    function accentForPack(pack, forLightMode = lightMode) {
        return forLightMode ? (pack.lightAccent || pack.accent) : (pack.darkAccent || pack.accent)
    }

    function mixColors(first, second, balance = fusionBalance) {
        const a = Qt.color(first)
        const b = Qt.color(second)
        const amount = Math.max(0, Math.min(100, Number(balance))) / 100
        return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount,
                       a.b + (b.b - a.b) * amount, a.a + (b.a - a.a) * amount)
    }

    function luminance(value) {
        const color = Qt.color(value)
        const linear = channel => channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        return linear(color.r) * 0.2126 + linear(color.g) * 0.7152 + linear(color.b) * 0.0722
    }

    function contrastRatio(first, second) {
        const a = luminance(first)
        const b = luminance(second)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }

    function usableAccent(accent, surface, minimum = 3) {
        return contrastRatio(accent, surface) >= minimum && contrastRatio(contrastText(accent), accent) >= 4.5
    }

    function fusedAccent(first, second, surface, minimum = 3) {
        const mixed = mixColors(first, second)
        if (usableAccent(mixed, surface, minimum)) return mixed
        const a = Qt.color(first)
        const b = Qt.color(second)
        const aScore = usableAccent(a, surface, minimum) ? contrastRatio(a, surface) : -1
        const bScore = usableAccent(b, surface, minimum) ? contrastRatio(b, surface) : -1
        if (aScore >= 0 || bScore >= 0) return aScore >= bScore ? a : b
        return contrastRatio("#FFFFFF", surface) >= contrastRatio("#111827", surface) ? "#FFFFFF" : "#111827"
    }

    function dailyMuse(date, identity) {
        const when = date === undefined ? new Date() : date
        const stamp = when.getFullYear() + "-" + (when.getMonth() + 1) + "-" + when.getDate()
        const seed = stamp + "|" + String(identity || "guest")
        let hash = 0
        for (let index = 0; index < seed.length; ++index)
            hash = (hash * 31 + seed.charCodeAt(index)) >>> 0
        const primary = hash % packs.length
        const offset = Math.floor(hash / packs.length) % (packs.length - 1) + 1
        const secondary = (primary + offset) % packs.length
        const balances = [25, 35, 50, 65, 75]
        return {primary:packs[primary].id, secondary:packs[secondary].id,
            balance:balances[Math.floor(hash / 17) % balances.length]}
    }

    readonly property color customAccent: accentColor(accent)
    readonly property color packAccent: fusionEnabled
        ? fusedAccent(accentForPack(pack), accentForPack(fusionPack), shell)
        : accentForPack(pack)
    readonly property color atmosphere: fusionEnabled
        ? mixColors(pack.mid || accentForPack(pack), fusionPack.mid || accentForPack(fusionPack))
        : (pack.mid || packAccent)
    readonly property bool accentOverridden: ShellStore.previewThemePack === "" && ShellStore.settings.themeAccentOverride === true
    readonly property color focus: accentOverridden ? customAccent : packAccent
    readonly property color focusText: contrastText(focus)
    readonly property color mint: "#6EE7B7"
    readonly property color violet: "#A78BFA"
    readonly property color yellow: "#FFD166"
    readonly property color coral: "#FF8A80"
    readonly property color glass: Qt.rgba(shell.r, shell.g, shell.b, translucent ? 0.52 : 0.72)
    readonly property color glassStrong: Qt.rgba(shell.r, shell.g, shell.b, translucent ? 0.74 : 0.94)
    readonly property color cartSteam: "#26364A"
    readonly property color cartEpic: "#1B1B1F"
    readonly property color cartUbisoft: "#3A5BD9"
    readonly property color cartXbox: "#107C41"
    readonly property color cartGog: "#7B3FE4"
    readonly property color cartBattlenet: "#2E7CB8"

    function contrastText(background) {
        const value = luminance(background)
        return (value + 0.05) / 0.0592 > 1.05 / (value + 0.05) ? "#111827" : "#FFFFFF"
    }

    readonly property string fontFamily: String(ShellStore.settings.appFontFamily || "Nunito")
    readonly property string displayFont: fontFamily
    readonly property string bodyFont: fontFamily
    readonly property string monoFont: "IBM Plex Mono"

    readonly property int focusDuration: AppController.reducedMotion ? 0 : 140
    readonly property int enterDuration: AppController.reducedMotion ? 0 : 260
    readonly property int heroDuration: AppController.reducedMotion ? 0 : 200
    readonly property int overlayDuration: AppController.reducedMotion ? 0 : 180
    readonly property int panelDuration: AppController.reducedMotion ? 0 : 220
    readonly property var easeOut: [0.16, 1.0, 0.3, 1.0]
    readonly property var easeEmphasized: [0.2, 0.9, 0.1, 1.0]

    function unit(windowWidth, windowHeight) {
        return Math.min(windowWidth / 100, windowHeight / 56.25)
    }
}
