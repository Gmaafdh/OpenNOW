pragma Singleton
import QtQuick

QtObject {
    // CYBERPUNK 2077 INSPIRED PALETTES — every pack is a neon district
    readonly property var packs: [
        {id:"neon-nocturne", name:"NEON NOCTURNE", author:"OPENNOW", category:"Cyberpunk", detail:"NEON GRID // CYAN", bg:"#05070E", lightBg:"#E6F0FF", mid:"#0A1435", accent:"#00F0FF", lightAccent:"#0077A6", darkAccent:"#00F0FF"},
        {id:"neo-tokyo", name:"NEO TOKYO", author:"OPENNOW", category:"Cyberpunk", detail:"SHIBUYA MAGENTA", bg:"#0A0308", lightBg:"#FFEAF4", mid:"#2A0A22", accent:"#FF2E97", lightAccent:"#9C0F4A", darkAccent:"#FF2E97"},
        {id:"blade-runner", name:"BLADE RUNNER", author:"OPENNOW", category:"Cyberpunk", detail:"VOLT YELLOW", bg:"#080A02", lightBg:"#FFF8DB", mid:"#1E2405", accent:"#FFE600", lightAccent:"#6B5900", darkAccent:"#FFE600"},
        {id:"ghostwire", name:"GHOSTWIRE", author:"OPENNOW", category:"Cyberpunk", detail:"NEON JADE", bg:"#020A08", lightBg:"#E6FFF6", mid:"#0A2A1E", accent:"#00FF9D", lightAccent:"#0A6B3E", darkAccent:"#00FF9D"},
        {id:"arasaka", name:"ARASAKA RED", author:"OPENNOW", category:"Cyberpunk", detail:"CORPO CRIMSON", bg:"#0E0404", lightBg:"#FFE9E9", mid:"#2D0A0A", accent:"#FF3B30", lightAccent:"#B51C1C", darkAccent:"#FF453A"},
        {id:"synthwave", name:"SYNTHWAVE", author:"OPENNOW", category:"Cyberpunk", detail:"SUNSET VIOLET", bg:"#0A0514", lightBg:"#F0E6FF", mid:"#1E0E33", accent:"#B14EFF", lightAccent:"#7B2CBF", darkAccent:"#B14EFF"},
        {id:"netrunner", name:"NETRUNNER", author:"OPENNOW", category:"Cyberpunk", detail:"ICE BLUE", bg:"#030A14", lightBg:"#E6F0FF", mid:"#0A1E35", accent:"#0A84FF", lightAccent:"#0051D5", darkAccent:"#0A84FF"},
        {id:"volt-edge", name:"VOLT EDGE", author:"OPENNOW", category:"Cyberpunk", detail:"ACID ORANGE", bg:"#0F0800", lightBg:"#FFF2E0", mid:"#2E1A00", accent:"#FF6A00", lightAccent:"#8F3300", darkAccent:"#FF6A00"},
        // legacy fallbacks kept for migration — mapped to cyber equivalents
        {id:"nocturne", name:"NOCTURNE", author:"OPENNOW", category:"Dark", detail:"SKY GLASS", bg:"#05070E", lightBg:"#EEF3FA", mid:"#0A1435", accent:"#00F0FF", lightAccent:"#0077A6", darkAccent:"#00F0FF"},
        {id:"bone", name:"BONE", author:"OPENNOW", category:"Light", detail:"WARM MINIMAL", bg:"#EEE7DB", darkBg:"#0A0508", mid:"#A89578", accent:"#00F0FF", lightAccent:"#0077A6", darkAccent:"#00F0FF"},
        {id:"cobalt", name:"COBALT", author:"OPENNOW", category:"Light", detail:"COBALT PAPER", bg:"#F7F9FF", darkBg:"#030A14", mid:"#ADC4FF", accent:"#0A84FF", lightAccent:"#0048B0", darkAccent:"#0A84FF"}
    ]
    readonly property string mode: String(ShellStore.settings.appTheme || "auto")
    readonly property string themePack: {
        const preview = String(ShellStore.previewThemePack || "")
        if (preview !== "")
            return preview
        const requested = String(ShellStore.settings.themePack || "neon-nocturne")
        // legacy pack ids migrate onto their cyberpunk equivalents
        const migrate = {aurora: "ghostwire", kraft: "volt-edge", phosphor: "ghostwire", chapel: "synthwave",
                         hibiscus: "neo-tokyo", cobalt: "netrunner", bone: "neon-nocturne", nocturne: "neon-nocturne"}
        return String(migrate[requested] || requested)
    }
    readonly property var pack: packs.find(item => item.id === themePack) || packs[0]
    readonly property bool packLight: pack.category === "Light"
    readonly property bool systemLight: Qt.styleHints.colorScheme === Qt.Light
    readonly property bool lightMode: ShellStore.previewThemePack !== "" ? packLight
        : mode === "light" || (mode === "auto" && systemLight)
    readonly property bool translucent: Boolean(ShellStore.settings.translucentUI)

    readonly property string accent: String(ShellStore.settings.appAccentColor || "blue")
    readonly property color shell: lightMode ? (pack.lightBg || pack.bg) : (pack.darkBg || pack.bg)
    readonly property color shellDeep: lightMode ? Qt.darker(pack.lightBg || pack.bg, 1.05) : Qt.rgba(0.02, 0.03, 0.07, 1)
    readonly property color face: lightMode ? "#0A0D14" : "#FFFFFF"
    readonly property color faceText: lightMode ? "#FFFFFF" : "#05070E"
    readonly property color mediaForeground: "#FFFFFF"
    readonly property color mediaMuted: Qt.rgba(mediaForeground.r, mediaForeground.g, mediaForeground.b, 0.58)
    readonly property color mediaAccent: accentOverridden ? accentColor(accent, false) : (pack.darkAccent || pack.accent)
    // Cyberpunk seams — neon tinted borders that glow
    readonly property color seam: lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.12) : Qt.rgba(0, 0.94, 1, 0.13)
    readonly property color seamStrong: lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.18) : Qt.rgba(0, 0.94, 1, 0.24)
    readonly property color neonSeam: Qt.rgba(focus.r, focus.g, focus.b, lightMode ? 0.16 : 0.32)
    readonly property color neonGlow: Qt.rgba(focus.r, focus.g, focus.b, 0.55)
    readonly property color gridLine: Qt.rgba(focus.r, focus.g, focus.b, lightMode ? 0.04 : 0.09)
    readonly property color label: lightMode ? "#0A0D14" : "#FFFFFF"
    readonly property color textMuted: lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.58) : Qt.rgba(1, 1, 1, 0.56)
    readonly property color textFaint: lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.38) : Qt.rgba(1, 1, 1, 0.36)
    readonly property var accentChoices: ["green", "blue", "violet", "rose", "coral", "amber", "white"]
    function accentColor(value, forLightMode = lightMode) {
        const dark = {cyan:"#00F0FF", magenta:"#FF2E97", yellow:"#FFE600", green:"#00FF9D", red:"#FF3B30", violet:"#B14EFF", blue:"#0A84FF", white:"#FFFFFF",
                      green_old:"#6EE7B7", blue_old:"#7FD4FF", violet_old:"#A78BFA", rose:"#FF8A9A", coral:"#FF8A80", amber:"#FFD166"}
        const light = {cyan:"#0077A6", magenta:"#9C0F4A", yellow:"#6B5900", green:"#0A6B3E", red:"#B51C1C", violet:"#7B2CBF", blue:"#0051D5", white:"#0A0D14",
                       green_old:"#126B4E", blue_old:"#12638C", violet_old:"#7042BA", rose:"#AA285B", coral:"#A9362C", amber:"#806017"}
        // legacy mappings
        const legacy = {green:"cyan", blue:"cyan", violet:"violet", rose:"magenta", coral:"red", amber:"yellow"}
        const key = legacy[value] || value
        return (forLightMode ? light : dark)[key] || (forLightMode ? light.cyan : dark.cyan)
    }
    readonly property color customAccent: accentColor(accent)
    readonly property color packAccent: lightMode ? (pack.lightAccent || pack.accent) : (pack.darkAccent || pack.accent)
    readonly property bool accentOverridden: ShellStore.previewThemePack === "" && ShellStore.settings.themeAccentOverride === true
    readonly property color focus: accentOverridden ? customAccent : packAccent
    readonly property color focusText: contrastText(focus)
    // Legacy aliases kept for existing QML — now cyberpunk neon
    readonly property color mint: "#00FF9D"
    readonly property color violet: "#B14EFF"
    readonly property color yellow: "#FFE600"
    readonly property color coral: "#FF3B30"
    // New cyberpunk palette
    readonly property color cyan: "#00F0FF"
    readonly property color magenta: "#FF2E97"
    readonly property color amber: "#FFE600"
    readonly property color jade: "#00FF9D"
    readonly property color danger: "#FF3B30"
    readonly property color glass: lightMode ? Qt.rgba(shell.r, shell.g, shell.b, translucent ? 0.62 : 0.82)
                                             : Qt.rgba(0.03, 0.05, 0.12, translucent ? 0.54 : 0.78)
    readonly property color glassStrong: lightMode ? Qt.rgba(shell.r, shell.g, shell.b, translucent ? 0.82 : 0.96)
                                                   : Qt.rgba(0.05, 0.08, 0.16, translucent ? 0.86 : 0.96)
    readonly property color cartSteam: "#26364A"
    readonly property color cartEpic: "#1B1B1F"
    readonly property color cartUbisoft: "#3A5BD9"
    readonly property color cartXbox: "#107C41"
    readonly property color cartGog: "#7B3FE4"
    readonly property color cartBattlenet: "#2E7CB8"

    function contrastText(background) {
        const linear = value => value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        const luminance = linear(background.r) * 0.2126 + linear(background.g) * 0.7152 + linear(background.b) * 0.0722
        return (luminance + 0.05) / 0.0592 > 1.05 / (luminance + 0.05) ? "#05070E" : "#FFFFFF"
    }

    readonly property string displayFont: "Nunito"
    readonly property string bodyFont: "Nunito"
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
