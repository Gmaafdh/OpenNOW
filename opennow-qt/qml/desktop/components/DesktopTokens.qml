pragma Singleton
import QtQuick
import OpenNOW

QtObject {
    id: tokens

    function relativeLastPlayed(raw, nowMs) {
        const timestamp = Date.parse(String(raw || ""))
        if (isNaN(timestamp))
            return ""
        const seconds = Math.max(0, Math.floor((nowMs - timestamp) / 1000))
        if (seconds < 1)
            return qsTr("Just now")
        if (seconds < 60)
            return seconds === 1 ? qsTr("1 second ago") : qsTr("%1 seconds ago").arg(seconds)
        const minutes = Math.floor(seconds / 60)
        if (minutes < 60)
            return minutes === 1 ? qsTr("1 minute ago") : qsTr("%1 minutes ago").arg(minutes)
        const hours = Math.floor(minutes / 60)
        if (hours < 24)
            return hours === 1 ? qsTr("1 hour ago") : qsTr("%1 hours ago").arg(hours)
        const days = Math.floor(hours / 24)
        return days === 1 ? qsTr("1 day ago") : qsTr("%1 days ago").arg(days)
    }

    readonly property color shell: Theme.shell
    readonly property color rail: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.90)
    readonly property color topBar: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.66)
    readonly property color statusBar: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.78)
    readonly property color surface: Theme.glass
    readonly property color raised: Theme.lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.08) : "#14FFFFFF"
    readonly property color raisedStrong: Theme.lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.12) : "#1FFFFFFF"
    readonly property color seam: Theme.seam
    readonly property color seamSoft: Theme.lightMode ? Qt.rgba(0.04, 0.06, 0.10, 0.06) : "#0FFFFFFF"
    readonly property color text: Theme.label
    readonly property color textHigh: Theme.label
    readonly property color textBody: Theme.textMuted
    readonly property color textMuted: Theme.textMuted
    readonly property color textFaint: Theme.textFaint
    readonly property color focus: Theme.focus
    readonly property color green: "#1DB954"
    readonly property color mint: "#56E6A5"
    readonly property color amber: "#FFD166"
    readonly property color ledAmber: "#F5A623"
    readonly property color danger: "#FF8A80"
    readonly property color flightReady: Theme.lightMode ? "#126B4E" : green
    readonly property color flightMint: "#6EE7B7"
    readonly property color flightWarning: Theme.lightMode ? "#806017" : amber
    readonly property color flightDeclined: Theme.lightMode ? "#A9362C" : danger
    readonly property string displayFont: Theme.displayFont
    readonly property string bodyFont: Theme.bodyFont
    readonly property string monoFont: Theme.monoFont
    property real uiScale: 1
    // Type ramp. Every desktop font size must come from here so text stays
    // proportionate on any display size; raw pixelSize literals drift.
    readonly property int titleSize: px(26)
    readonly property int headingSize: px(17)
    readonly property int bodySize: px(15)
    readonly property int captionSize: px(13)
    readonly property int monoSize: px(12)
    readonly property int smallSize: px(11)
    readonly property int microSize: px(10)
    readonly property int tinySize: px(9)
    readonly property int railWidth: px(232)
    readonly property int railCollapsedWidth: px(72)
    readonly property int topBarHeight: px(64)
    readonly property int statusBarHeight: px(52)
    readonly property int rowHeight: px(60)
    readonly property int controlHeight: px(38)
    readonly property int settingsInset: px(20)
    readonly property int settingsLabelInset: px(76)
    readonly property int settingsControlWidth: px(300)
    readonly property int settingsCompactWidth: px(760)
    readonly property int posterWidth: px(112)
    readonly property int posterHeight: px(168)
    readonly property int libraryCellWidth: px(146)
    readonly property int libraryCellHeight: px(214)
    readonly property int libraryArtWidth: px(132)
    readonly property int libraryArtHeight: px(198)
    // Landscape library cards: 16:9 key art over a title line and a status chip.
    // The grid and the card share every term of this contract, so a cell can
    // never clip its card at any UI scale (each px() rounds on its own).
    readonly property int libraryCardGutter: 6
    readonly property int libraryCardChipGap: px(12)
    readonly property int libraryCardChipHeight: px(24)
    readonly property int libraryCardBottomPad: px(10)
    readonly property int libraryCardTitleGap: px(11)
    readonly property int libraryCardTitleHeight: px(20)
    readonly property int libraryCardTitleSpacing: px(6)
    readonly property int libraryCardBaseWidth: px(300)
    function libraryCardArtWidth(cellWidth) {
        return Math.max(1, Math.round(Number(cellWidth)) - 2 * libraryCardGutter)
    }
    function libraryCardArtHeight(cellWidth) {
        return Math.max(1, Math.round(libraryCardArtWidth(cellWidth) * 9 / 16))
    }
    function libraryCardHeight(cellWidth, labelsVisible) {
        return 2 * libraryCardGutter + libraryCardArtHeight(cellWidth)
            + libraryCardChipHeight + libraryCardBottomPad
            + (labelsVisible
                ? libraryCardTitleGap + libraryCardTitleHeight + libraryCardTitleSpacing
                : libraryCardChipGap)
    }
    // Accent-to-violet sweep for hero actions: the PLAY pill on a library card
    // and the primary action of the full-screen detail view. Both stops stay
    // light, so the fixed dark ink keeps its contrast on any user accent.
    function tintToward(value, amount) {
        const color = Qt.color(value)
        const mix = Math.max(0, Math.min(1, Number(amount)))
        return Qt.rgba(color.r + (1 - color.r) * mix, color.g + (1 - color.g) * mix,
                       color.b + (1 - color.b) * mix, 1)
    }
    readonly property color actionViolet: Theme.mixColors(Theme.focus, Theme.violet, 70)
    // The stops stay light enough for the fixed dark ink, but no lighter: the
    // sweep has to read as the accent, not as a pale wash over the artwork.
    readonly property color actionStart: tintToward(Theme.mixColors(Theme.focus, Theme.violet, 18), 0.40)
    readonly property color actionEnd: tintToward(actionViolet, 0.16)
    readonly property color actionStartHover: tintToward(Theme.mixColors(Theme.focus, Theme.violet, 18), 0.52)
    readonly property color actionEndHover: tintToward(actionViolet, 0.28)
    readonly property color actionStartDown: tintToward(Theme.mixColors(Theme.focus, Theme.violet, 18), 0.28)
    readonly property color actionEndDown: tintToward(actionViolet, 0.06)
    readonly property color actionInk: "#0A0D14"
    property FontMetrics storeTitleMetrics: FontMetrics {
        font.family: Theme.bodyFont
        font.pixelSize: tokens.monoSize
        font.weight: Font.Bold
    }
    readonly property int storeCardInfoHeight: px(8) + Math.ceil(storeTitleMetrics.height) * 2 + px(4) + px(17) + px(4)
    readonly property int quickDuration: Theme.duration(120)
    readonly property int motionDuration: Theme.duration(220)
    readonly property int revealDuration: Theme.duration(320)
    readonly property real cardHoverScale: 1.025
    readonly property int cardOutlinePad: 2
    readonly property color cardOutlineIdle: Theme.seam

    function px(value) {
        return Math.max(1, Math.round(Number(value) * uiScale))
    }

    function radius(value) {
        return Math.max(0, Math.round(Number(value) * uiScale * Theme.cornerScale))
    }

    function scaleForWindow(width, height) {
        // Qt already accounts for display DPI. Keep logical text readable;
        // use reflow, not aggressive downscaling, for smaller windows.
        return Math.max(0.95, Math.min(1.15, Math.min(width / 1440, height / 900)))
    }

    function storeKey(value) {
        const key = String(value || "").toLowerCase()
        if (key.indexOf("steam") >= 0) return "steam"
        if (key.indexOf("epic") >= 0) return "epic"
        if (key.indexOf("ubisoft") >= 0 || key.indexOf("uplay") >= 0) return "ubisoft"
        if (key.indexOf("battle") >= 0) return "battlenet"
        if (key.indexOf("xbox") >= 0) return "xbox"
        if (key.indexOf("gog") >= 0) return "gog"
        if (key.indexOf("gaijin") >= 0) return "gaijin"
        if (key === "nvidia") return "nvidia"
        if (key === "ea" || key === "ea_app" || key === "origin") return "ea"
        return ""
    }
    function storeIconUrl(value) {
        const key = storeKey(value)
        return key ? "qrc:/qt/qml/OpenNOW/res/icons/store-" + key + ".svg" : ""
    }
    function storeLabel(value) {
        const labels = {steam:"Steam", epic:"Epic Games", ubisoft:"Ubisoft Connect", battlenet:"Battle.net",
            xbox:"Xbox", gog:"GOG", gaijin:"Gaijin", ea:"EA app", nvidia:"NVIDIA"}
        return labels[storeKey(value)] || (String(value).toUpperCase() === "NONE" ? qsTr("Direct launch") : String(value))
    }
    readonly property var gameFeatureKeys: ["rtx", "hdr", "reflex", "dlss"]
    function gameFeatures(game) {
        const found = {}
        const variants = game && game.variants || []
        for (let i = 0; i < variants.length; ++i) {
            const features = variants[i] && variants[i].features || []
            for (let j = 0; j < features.length; ++j)
                found[features[j]] = true
        }
        found.dlss = Boolean(game && game.dlss)
        return gameFeatureKeys.filter(key => found[key] === true)
    }
    function featureIconUrl(key) {
        return gameFeatureKeys.indexOf(key) >= 0 ? "qrc:/qt/qml/OpenNOW/res/icons/desktop-" + key + ".svg" : ""
    }
    function featureLabel(key) {
        if (key === "rtx") return qsTr("RTX ray tracing")
        if (key === "hdr") return qsTr("HDR")
        if (key === "reflex") return qsTr("Reflex low latency")
        if (key === "dlss") return qsTr("DLSS")
        return ""
    }
    function featureTip(key) {
        return key === "dlss" ? qsTr("DLSS — per NVIDIA's DLSS games list") : featureLabel(key)
    }
    function genreLabel(value) {
        return String(value).toLowerCase().replace(/_/g, " ").replace(/\b\w/g, letter => letter.toUpperCase())
    }

    function artworkUrl(game, preferHero, wantedWidth) {
        if (!game)
            return ""
        const raw = preferHero
            ? String(game.heroImageUrl || game.imageUrl || game.screenshotUrl || game.boxArtUrl || "")
            : String(game.imageUrl || game.heroImageUrl || game.screenshotUrl || game.boxArtUrl || "")
        return decodeArtworkUrl(raw, wantedWidth)
    }

    function decodeArtworkUrl(url, wantedWidth) {
        let out = String(url || "").split(";f=webp").join(";f=jpg")
        const wanted = Math.round(wantedWidth || 0)
        if (wanted > 0 && out.indexOf(";w=") >= 0)
            out = out.replace(/;w=[0-9]+/, ";w=" + wanted)
        return out
    }

    // The image service renders whatever width is asked for, up to the native
    // size of the art. The catalog requests 1200px heroes, which a full-bleed
    // backdrop then stretches across a 2000px or wider window - exactly the
    // softness a upscaled download shows. Ask for the smallest standard step
    // that covers the surface, so the bytes arrive at the size they are shown.
    function backdropWidthStep(deviceWidth) {
        const steps = [1280, 1600, 1920, 2240, 2560]
        for (let i = 0; i < steps.length; ++i)
            if (deviceWidth <= steps[i])
                return steps[i]
        return steps[steps.length - 1]
    }

    function backdropArtworkUrl(game, deviceWidth) {
        return artworkUrl(game, true, backdropWidthStep(deviceWidth))
    }

    function consoleModeOn(win) {
        return win
            ? Boolean(win.forceConsole || win.desktopSurfaceActive === false)
            : ShellStore.settings.launchInConsoleMode === true
    }
    function consoleModeTargetOn(win) {
        return win
            ? !Boolean(win.targetDesktopSurface)
            : ShellStore.settings.launchInConsoleMode === true
    }
    function consoleModePending(win) {
        return ShellStore.consoleSurfaceRequestId !== "" || Boolean(win
            && win.targetDesktopSurface !== undefined
            && win.targetDesktopSurface !== win.desktopSurfaceActive)
    }
}
