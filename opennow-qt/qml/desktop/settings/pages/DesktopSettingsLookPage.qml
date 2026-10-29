import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import OpenNOW

Column {
    id: page
    objectName: "desktopAppearanceSettings"
    required property real availableWidth
    required property var settingsScreen
    required property Component interfacePageComponent

    width: page.availableWidth; spacing: DesktopTokens.px(12)
    readonly property string backgroundImage: String(page.settingsScreen.valueSetting("desktopBackgroundImage", ""))
    readonly property string profileImage: ShellStore.customProfileImageFor(page.settingsScreen.profileUser())
    readonly property int profileImageSize: Number(page.settingsScreen.valueSetting("profileImageSize", 256))
    readonly property bool customAccent: /^#[0-9a-fA-F]{6}$/.test(Theme.accent)
    property string customAccentDraft: page.customAccent ? Theme.accent.toUpperCase() : "#7FD4FF"
    property bool accentEditorOpen: false
    property string accentMessage: ""
    property string profileStatus: ""
    property bool profileStatusIsError: false

    function normalizedHex(value) {
        let text = String(value || "").trim().toUpperCase()
        if (text.length === 6 && text.indexOf("#") !== 0) text = "#" + text
        return /^#[0-9A-F]{6}$/.test(text) ? text : ""
    }

    function applyCustomAccent() {
        const value = normalizedHex(customAccentDraft)
        if (value === "") {
            accentMessage = qsTr("Enter six hexadecimal digits, for example #7FD4FF.")
            return false
        }
        customAccentDraft = value
        accentMessage = ""
        page.settingsScreen.setChoice("appAccentColor", value)
        return true
    }

    function profileError(code) {
        switch (String(code || "save-failed")) {
        case "invalid-source": return qsTr("Choose an existing local image file.")
        case "file-too-large": return qsTr("The image is larger than 20 MB. Choose a smaller file.")
        case "unsupported-type": return qsTr("Use a PNG, JPEG, WebP or BMP image.")
        case "invalid-dimensions": return qsTr("Both image dimensions must be between 64 and 4096 pixels.")
        case "invalid-size": return qsTr("Choose a 128, 256 or 512 pixel export size.")
        case "decode-failed": return qsTr("OpenNOW could not decode this image. Try exporting it as PNG or JPEG.")
        case "storage-unavailable":
        case "save-failed":
        case "encode-failed": return qsTr("OpenNOW could not save the image. Check available storage and try again.")
        default: return qsTr("The profile image could not be imported.")
        }
    }

    function importProfileImage(url) {
        const result = ProfileImages.importImage(String(url), profileImageSize)
        if (!result || result.ok !== true) {
            profileStatusIsError = true
            profileStatus = profileError(result && result.error)
            return
        }
        const persistence = ShellStore.setCustomProfileImage(page.settingsScreen.profileUser(), String(result.url))
        if (persistence === false || persistence === "") {
            profileStatusIsError = true
            profileStatus = profileError("save-failed")
            return
        }
        profileStatusIsError = false
        profileStatus = qsTr("Saved %1 × %2 px · center-cropped from %3 × %4 px.")
            .arg(result.width).arg(result.height).arg(result.sourceWidth).arg(result.sourceHeight)
    }

    function removeProfileImage() {
        const persistence = ShellStore.setCustomProfileImage(page.settingsScreen.profileUser(), "")
        profileStatusIsError = persistence === false || persistence === ""
        profileStatus = profileStatusIsError ? profileError("save-failed")
            : qsTr("Custom image removed. The profile initial is shown again.")
    }

    FileDialog {
        id: profileDialog
        objectName: "profileImageDialog"
        title: qsTr("Choose a profile image")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.webp *.bmp)")]
        onAccepted: {
            page.importProfileImage(selectedFile.toString())
            chooseProfileButton.forceActiveFocus()
        }
        onRejected: chooseProfileButton.forceActiveFocus()
    }
    FileDialog {
        id: backgroundDialog
        objectName: "customBackgroundDialog"
        title: qsTr("Choose a background image")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.webp *.bmp)")]
        onAccepted: {
            page.settingsScreen.setSetting("desktopBackgroundImage", selectedFile.toString())
            page.settingsScreen.setSetting("desktopBackground", "custom")
            chooseBackgroundButton.forceActiveFocus()
        }
        onRejected: chooseBackgroundButton.forceActiveFocus()
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        objectName: "desktopProfileImageSettings"
        DesktopSettingsSection { text: qsTr("PROFILE IMAGE") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "person"; title: qsTr("Custom profile image")
            description: qsTr("PNG, JPEG, WebP or BMP · 64–4096 px per side · 20 MB maximum. The original file is not modified.")
            Row {
                spacing: DesktopTokens.px(10)
                ProfileAvatar {
                    width: DesktopTokens.px(52); height: width
                    anchors.verticalCenter: parent.verticalCenter
                    account: page.settingsScreen.profileUser()
                    displayName: page.settingsScreen.profileName()
                    fallbackStart: Theme.violet; fallbackEnd: Theme.focus
                    cornerRadius: DesktopTokens.px(16)
                    borderColor: Theme.seam; borderWidth: 1
                }
                DesktopSettingsButton {
                    id: chooseProfileButton
                    objectName: "chooseProfileImage"
                    text: qsTr("Choose image…")
                    primary: true
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: profileDialog.open()
                }
                DesktopSettingsButton {
                    objectName: "removeProfileImage"
                    text: qsTr("Remove")
                    visible: page.profileImage !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        page.removeProfileImage()
                        chooseProfileButton.forceActiveFocus()
                    }
                }
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "image"; title: qsTr("Square export size")
            description: qsTr("Center-cropped and stored per OpenNOW profile on this device. This never uploads or changes your NVIDIA avatar.")
            showDivider: page.profileStatus !== ""
            DesktopSettingsSegmented {
                objectName: "profileImageSize"
                options: [{label:"128 × 128",value:128},{label:"256 × 256",value:256},{label:"512 × 512",value:512}]
                optionWidth: 84
                selectedIndex: options.findIndex(item => item.value === page.profileImageSize)
                onSelected: (index,item) => page.settingsScreen.setSetting("profileImageSize", item.value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: page.profileStatusIsError ? "info" : "check"
            visible: page.profileStatus !== ""
            title: page.profileStatusIsError ? qsTr("Profile image not changed") : qsTr("Profile image updated")
            description: page.profileStatus; showDivider: false
        }
    }

    Loader { width: parent.width; sourceComponent: page.interfacePageComponent }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        DesktopSettingsSection { text: qsTr("THEME & TEXT") }
        DesktopSettingsChoice {
            objectName: "renewThemeChoice"
            width: parent.width; glyph: "moon"; title: qsTr("Theme")
            description: qsTr("Applies the pack's appearance, accent and surfaces")
            items: ["aurora","nocturne","kraft","phosphor","hibiscus","chapel","bone","cobalt"].map(id => ({label:page.settingsScreen.themeMeta(id).name,detail:page.settingsScreen.themeMeta(id).blurb,value:id}))
            value: page.settingsScreen.valueSetting("themePack","nocturne")
            onSelected: value => page.settingsScreen.setChoice("themePack",value)
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "moon"; title: qsTr("Appearance")
            DesktopSettingsSegmented {
                options: [{label:qsTr("Auto"),value:"auto"},{label:qsTr("Light"),value:"light"},{label:qsTr("Dark"),value:"dark"}]
                selectedIndex: options.findIndex(item => item.value === page.settingsScreen.valueSetting("appTheme","auto"))
                onSelected: (index,item) => page.settingsScreen.setSetting("appTheme",item.value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "palette"; title: qsTr("Accent"); description: qsTr("Selection, toggles and keyboard focus")
            Row {
                spacing: DesktopTokens.px(10)
                DesktopSettingsButton {
                    objectName: "themePackAccent"
                    text: qsTr("Theme")
                    compact: true
                    primary: !Theme.accentOverridden
                    onClicked: page.settingsScreen.setSetting("themeAccentOverride", false)
                }
                Repeater {
                    model: Theme.accentChoices
                    delegate: AbstractButton {
                        required property string modelData
                        objectName: "themeAccent-" + modelData
                        width: DesktopTokens.px(28); height: DesktopTokens.px(28); Accessible.name: modelData
                        checked: Theme.accentOverridden && Theme.accent === modelData
                        onClicked: page.settingsScreen.setChoice("appAccentColor",modelData)
                        background: Rectangle {
                            radius: DesktopTokens.px(14); color: Theme.accentColor(parent.modelData)
                            border.width: parent.activeFocus || parent.checked ? 3 : 0
                            border.color: Theme.label
                        }
                    }
                }
                DesktopSettingsButton {
                    objectName: "customAccentButton"
                    text: qsTr("Custom…")
                    compact: true
                    primary: Theme.accentOverridden && page.customAccent
                    onClicked: {
                        page.accentEditorOpen = !page.accentEditorOpen
                        page.accentMessage = ""
                        if (page.customAccent) page.customAccentDraft = Theme.accent.toUpperCase()
                    }
                }
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "palette"; title: qsTr("Custom hex accent")
            visible: page.accentEditorOpen || page.customAccent
            description: page.accentMessage !== "" ? page.accentMessage : qsTr("Enter #RRGGBB · a valid color previews live across OpenNOW")
            Row {
                spacing: DesktopTokens.px(10)
                Rectangle {
                    width: DesktopTokens.px(40); height: width; radius: DesktopTokens.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    color: page.normalizedHex(page.customAccentDraft) || Theme.seam
                    border.width: 1; border.color: Theme.seam
                }
                DesktopSettingsField {
                    id: customAccentField
                    objectName: "customAccentField"
                    width: DesktopTokens.px(150)
                    text: page.customAccentDraft
                    placeholderText: "#7FD4FF"
                    maximumLength: 7
                    font.family: Theme.monoFont
                    onTextEdited: {
                        page.customAccentDraft = text
                        page.accentMessage = ""
                        if (page.normalizedHex(text) !== "") page.applyCustomAccent()
                    }
                    onAccepted: page.applyCustomAccent()
                }
                DesktopSettingsButton {
                    objectName: "applyCustomAccent"
                    text: qsTr("Apply")
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: page.applyCustomAccent()
                }
            }
        }
        DesktopSettingsChoice {
            objectName: "appFontFamilyChoice"
            width: parent.width; glyph: "sliders"; title: qsTr("Interface font")
            description: qsTr("Updates headings and body text immediately · monospace data stays readable")
            items: [
                {label:"Nunito",detail:qsTr("OpenNOW default"),value:"Nunito"},
                {label:"Segoe UI",detail:qsTr("Windows system font"),value:"Segoe UI"},
                {label:"Arial",detail:qsTr("Neutral sans serif"),value:"Arial"},
                {label:"Verdana",detail:qsTr("Wide, highly legible text"),value:"Verdana"}
            ]
            value: page.settingsScreen.valueSetting("appFontFamily", "Nunito")
            onSelected: value => page.settingsScreen.setSetting("appFontFamily", value)
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sun"; title: qsTr("Translucent interface")
            description: qsTr("Use translucent shell surfaces when supported"); showDivider: false
            DesktopSettingsToggle { checked: page.settingsScreen.boolSetting("translucentUI",false); onValueChangedByUser: value => page.settingsScreen.setSetting("translucentUI",value) }
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        DesktopSettingsSection { text: qsTr("BACKGROUND") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "image"; title: qsTr("Background"); description: qsTr("Game art, a custom image, gradient or solid color")
            DesktopSettingsSegmented {
                id: backgroundSelector
                objectName: "desktopBackgroundChoice"
                options: [{label:qsTr("Game art"),value:"art"},{label:qsTr("Gradient"),value:"gradient"},{label:qsTr("Solid"),value:"solid"},{label:qsTr("Custom"),value:"custom"}]; optionWidth: 72
                selectedIndex: options.findIndex(item => item.value === page.settingsScreen.valueSetting("desktopBackground","art"))
                onSelected: (index,item) => page.settingsScreen.setSetting("desktopBackground",item.value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "image"; title: qsTr("Custom image")
            visible: page.settingsScreen.valueSetting("desktopBackground", "art") === "custom"
            description: backgroundPreview.status === Image.Error
                ? qsTr("Image unavailable. Choose another file or remove it.")
                : page.backgroundImage !== "" ? qsTr("Keep the image in its original location") : qsTr("Choose a local PNG, JPEG, WebP or BMP image")
            Row {
                spacing: DesktopTokens.px(10)
                Image {
                    id: backgroundPreview
                    objectName: "customBackgroundPreview"
                    width: DesktopTokens.px(60); height: DesktopTokens.px(40)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.backgroundImage !== ""
                    source: page.backgroundImage
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                DesktopSettingsButton {
                    id: chooseBackgroundButton
                    objectName: "chooseCustomBackground"
                    text: qsTr("Choose image…")
                    onClicked: backgroundDialog.open()
                }
                DesktopSettingsButton {
                    objectName: "removeCustomBackground"
                    text: qsTr("Remove")
                    visible: page.backgroundImage !== ""
                    onClicked: {
                        page.settingsScreen.setSetting("desktopBackgroundImage", "")
                        if (page.settingsScreen.valueSetting("desktopBackground", "art") === "custom")
                            page.settingsScreen.setSetting("desktopBackground", "art")
                        backgroundSelector.focusSelectedOption()
                    }
                }
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sun"; title: qsTr("Image opacity")
            visible: page.settingsScreen.valueSetting("desktopBackground", "art") === "custom"
            description: qsTr("0% hides the image · 100% shows the full image"); showDivider: false
            DesktopSettingsSlider {
                objectName: "customBackgroundOpacity"
                enabled: page.settingsScreen.valueSetting("desktopBackground", "art") === "custom" && page.backgroundImage !== ""
                from: 0; to: 100; stepSize: 1
                value: Number(page.settingsScreen.valueSetting("desktopBackgroundOpacity", 30))
                onCommitted: value => page.settingsScreen.setSetting("desktopBackgroundOpacity", value)
            }
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        DesktopSettingsSection { text: qsTr("LAYOUT & MOTION") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "grid"; title: qsTr("Library tiles"); description: qsTr("Choose compact, cozy or large artwork density")
            DesktopSettingsSegmented {
                objectName: "libraryTileDensity"
                options: [qsTr("Compact"),qsTr("Cozy"),qsTr("Large")]; optionWidth: 72
                selectedIndex: Number(page.settingsScreen.valueSetting("posterSizeScale",1.05)) < 1 ? 0 : Number(page.settingsScreen.valueSetting("posterSizeScale",1.05)) > 1.1 ? 2 : 1
                onSelected: index => page.settingsScreen.setSetting("posterSizeScale",[0.9,1.05,1.25][index])
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "grid"; title: qsTr("Game tile labels")
            description: qsTr("Hide titles and information decks for an artwork-only library")
            DesktopSettingsToggle {
                objectName: "showTileLabels"
                checked: page.settingsScreen.boolSetting("showTileLabels", true)
                onValueChangedByUser: value => page.settingsScreen.setSetting("showTileLabels", value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sidebar"; title: qsTr("Collapsed sidebar")
            description: qsTr("Show icons only · Ctrl B toggles")
            DesktopSettingsToggle { checked: page.settingsScreen.boolSetting("desktopRailCollapsed",true); onValueChangedByUser: value => page.settingsScreen.setSetting("desktopRailCollapsed",value) }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "sidebar"; title: qsTr("Sidebar opens on hover"); description: qsTr("Expands over the page without moving it")
            DesktopSettingsToggle { checked: page.settingsScreen.boolSetting("desktopSidebarHover",true); onValueChangedByUser: value => page.settingsScreen.setSetting("desktopSidebarHover",value) }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "wave"; title: qsTr("Reduce motion")
            description: qsTr("Cuts parallax and cover animations · follows your OS by default"); showDivider: false
            DesktopSettingsToggle { checked: page.settingsScreen.boolSetting("reducedMotion",false); onValueChangedByUser: value => page.settingsScreen.setSetting("reducedMotion",value) }
        }
    }
}
