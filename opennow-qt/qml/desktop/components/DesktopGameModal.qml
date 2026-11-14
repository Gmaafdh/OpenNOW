import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import OpenNOW

FocusScope {
    id: root
    property var game: ShellStore.selectedGame
    signal closeRequested()
    signal playRequested()
    signal variantSelected(int index)
    objectName: "desktopGameModal"
    property bool opened: false
    visible: reveal.present
    enabled: opened
    focus: opened
    onOpenedChanged: if (opened) Qt.callLater(() => { if (root.opened) primaryAction.forceActiveFocus() })
    MotionProgress { id: reveal; objectName: "gameDetailsMotion"; shown: root.opened }

    readonly property int gutter: DesktopTokens.px(32)
    // The detail view is a full-screen landscape presentation: key art fills the
    // window and one left-hand column carries the title, the primary action and
    // everything a player still needs before launch.
    readonly property int dialogWidth: width
    readonly property int maximumDialogHeight: Math.max(0, height - gutter * 2)
    readonly property int dialogHeight: maximumDialogHeight
    // The artwork is the background, whole and undimmed; the text docks where
    // landscape key art always has room - the lower left - over a scrim that is
    // anchored to exactly that corner instead of veiling the whole screen.
    readonly property int columnInset: DesktopTokens.px(56)
    readonly property int contentWidth: Math.max(DesktopTokens.px(320),
        Math.min(DesktopTokens.px(780), Math.max(0, width - columnInset * 2)))
    readonly property int heroHeight: Math.max(headerInfo.implicitHeight + heroSlack,
        Math.round(maximumDialogHeight * 0.36))
    // Corner-anchored scrims: dark at the bottom and at the left edge where
    // the column docks, clear over the subject the artwork leads with.
    readonly property color scrimTop: Theme.lightMode ? "#8CF3F6FA" : "#8C040910"
    readonly property color scrimBottom: Theme.lightMode ? "#ECF3F6FA" : "#EB040910"
    readonly property color scrimLeft: Theme.lightMode ? "#D4F3F6FA" : "#D2040910"
    // Gameplay settings can be reviewed here instead of only after launching.
    property bool gameplaySettingsShown: false
    // A short window keeps the primary action above the fold: the title block,
    // the eyebrow and the CTA shrink together instead of pushing the action into
    // the scroll extent, where the layout contract can no longer reach it.
    readonly property bool compactDetails: maximumDialogHeight < DesktopTokens.px(620)
    readonly property int heroTitleSize: compactDetails ? DesktopTokens.px(34) : DesktopTokens.px(52)
    readonly property int heroSpacing: compactDetails ? DesktopTokens.px(8) : DesktopTokens.px(10)
    readonly property int heroBottomMargin: compactDetails ? DesktopTokens.px(20) : DesktopTokens.px(30)
    readonly property int heroSlack: compactDetails ? DesktopTokens.px(40) : DesktopTokens.px(56)
    readonly property int primaryActionHeight: compactDetails ? DesktopTokens.px(52) : DesktopTokens.px(58)
    readonly property var streamSettings: ShellStore.settings || ({})
    readonly property var selectedVariant: {
        const game = root.game
        if (!game)
            return null
        const variants = game.variants || []
        if (!variants.length)
            return null
        const index = Number(game.selectedVariantIndex || 0)
        return index >= 0 && index < variants.length ? variants[index] : null
    }
    readonly property bool gameAvailable: {
        const game = root.game
        if (!game)
            return false
        return ShellStore.selectedLaunchDecision.status === "ready"
    }
    readonly property var features: DesktopTokens.gameFeatures(root.game)
    property bool dlssExpanded: false
    DesktopGameDlss { id: dlssInfo; game: root.game }
    readonly property bool lockedByMembership: ShellStore.gameLockedByMembership(root.game)
    readonly property string lastPlayedText: {
        const game = root.game
        if (!game)
            return qsTr("—")
        if (game.lastPlayedLabel)
            return String(game.lastPlayedLabel)
        const raw = String(game.lastPlayed || (root.selectedVariant && root.selectedVariant.lastPlayedDate) || "")
        if (!raw)
            return qsTr("Not played yet")
        return DesktopTokens.relativeLastPlayed(raw, Date.now()) || qsTr("—")
    }
    readonly property string storesText: {
        const game = root.game
        if (!game)
            return qsTr("—")
        const fromStores = game.availableStores || []
        const stores = fromStores.length
            ? fromStores
            : (game.variants || []).map(variant => variant && variant.store).filter(Boolean)
        return stores.length ? stores.join(" · ") : qsTr("—")
    }
    readonly property bool isOwned: root.selectedVariant
        && ["MANUAL", "PLATFORM_SYNC"].indexOf(root.selectedVariant.libraryStatus) >= 0
    readonly property string ownershipText: {
        const game = root.game
        const variant = root.selectedVariant
        const store = variant && variant.store
            ? String(variant.store)
            : ((game && game.availableStores && game.availableStores[0]) || "")
        if (store && root.isOwned)
            return qsTr("OWNED ON %1").arg(store.toUpperCase())
        if (store)
            return store.toUpperCase()
        return root.isOwned ? qsTr("IN LIBRARY") : qsTr("NOT OWNED")
    }
    readonly property string requirementStoreKey: {
        const variant = root.selectedVariant
        const raw = variant && variant.store ? String(variant.store)
            : String((root.game && root.game.availableStores && root.game.availableStores[0]) || "")
        return raw.toUpperCase() === "NONE" || raw.toUpperCase() === "UNKNOWN" ? "" : raw
    }
    readonly property string requirementStore: root.requirementStoreKey === ""
        ? "" : DesktopTokens.storeLabel(root.requirementStoreKey)
    readonly property string requirementText: {
        if (!root.game || root.requirementStore === "")
            return ""
        return root.isOwned
            ? qsTr("Linked to your %1 account. Ready to play.").arg(root.requirementStore)
            : qsTr("%1 account required to play this game.").arg(root.requirementStore)
    }
    readonly property string membershipText: {
        const sub = ShellStore.subscription
        if (sub && sub.membershipTier)
            return String(sub.membershipTier).toUpperCase()
        const user = ShellStore.authSession && ShellStore.authSession.user
        if (user && user.membershipTier)
            return String(user.membershipTier).toUpperCase()
        return ""
    }
    readonly property string resolutionText: {
        const raw = String(root.streamSettings.resolution || "")
        if (raw.indexOf("x") > 0) {
            const height = Number(raw.split("x")[1])
            if (height >= 2160)
                return "4K"
            if (height > 0)
                return height + "p"
        }
        return raw || qsTr("Auto")
    }
    readonly property string fpsText: {
        const fps = Number(root.streamSettings.fps || 0)
        return fps > 0 ? qsTr("%1 fps").arg(fps) : qsTr("Auto")
    }
    readonly property string codecText: {
        const codec = String(root.streamSettings.codec || "")
        if (!codec || codec.toLowerCase() === "auto")
            return qsTr("Auto")
        return codec.toUpperCase()
    }
    readonly property string regionText: {
        const region = String(root.streamSettings.region || "")
        return region ? region.toUpperCase() : qsTr("AUTOMATIC REGION")
    }
    readonly property string friendsNote: {
        const caps = ShellStore.socialCapabilities || ({})
        if (!caps.friendsAvailable && caps.reason)
            return String(caps.reason)
        return qsTr("Friends activity is not available from GeForce NOW")
    }
    readonly property var badgeLabels: {
        const game = root.game
        const labels = []
        const seen = {}
        function add(label) {
            const text = String(label || "").trim()
            const key = text.toUpperCase()
            if (!text || seen[key])
                return
            seen[key] = true
            labels.push(text)
        }
        if (!game)
            return labels
        if (root.gameAvailable)
            add(qsTr("READY TO PLAY"))
        else if (game.playabilityState)
            add(String(game.playabilityState).replace(/_/g, " "))
        const playType = String(game.playType || "").replace(/_/g, " ")
        if (playType && playType.toUpperCase() !== "READY TO PLAY")
            add(playType)
        const controls = game.supportedControls || []
        for (let i = 0; i < controls.length; ++i) {
            const control = String(controls[i] || "").toUpperCase()
            if (control === "GAMEPAD")
                add(qsTr("CONTROLLER"))
            else if (control === "KEYBOARD_MOUSE" || control === "KEYBOARD AND MOUSE")
                add(qsTr("KEYBOARD"))
            else if (control)
                add(control.replace(/_/g, " "))
        }
        if (root.features.indexOf("rtx") >= 0)
            add("RTX")
        if (root.features.indexOf("hdr") >= 0)
            add(qsTr("HDR"))
        if (root.features.indexOf("reflex") >= 0)
            add(qsTr("REFLEX"))
        if (root.features.indexOf("dlss") >= 0)
            add("DLSS")
        if (game.membershipTierLabel)
            add(String(game.membershipTierLabel))
        return labels
    }
    readonly property var factItems: {
        const game = root.game || ({})
        const items = [{l: qsTr("LAST PLAYED"), v: root.lastPlayedText}]
        if (game.hoursPlayed)
            items.push({l: qsTr("HOURS PLAYED"), v: qsTr("%1 h").arg(game.hoursPlayed)})
        if (game.sessionCount)
            items.push({l: qsTr("SESSIONS"), v: String(game.sessionCount)})
        items.push({l: qsTr("STORES"), v: root.storesText})
        items.push({l: qsTr("AVAILABLE"), v: root.gameAvailable ? qsTr("Yes") : qsTr("No")})
        return items
    }
    readonly property var streamRows: [
        {l: qsTr("Resolution"), v: root.resolutionText},
        {l: qsTr("Frame rate"), v: root.fpsText},
        {l: qsTr("Codec"), v: root.codecText}
    ]

    function revealFocusedControl() {
        if (!root.opened || !root.Window.window)
            return
        const item = root.Window.window.activeFocusItem
        let ancestor = item
        while (ancestor && ancestor !== detailsColumn)
            ancestor = ancestor.parent
        if (!ancestor)
            return
        const top = item.mapToItem(detailsFlick.contentItem, 0, 0).y
        const margin = DesktopTokens.px(8)
        const maximumY = Math.max(0, detailsFlick.contentHeight - detailsFlick.height)
        if (top < detailsFlick.contentY + margin)
            detailsFlick.contentY = Math.max(0, top - margin)
        else if (top + item.height > detailsFlick.contentY + detailsFlick.height - margin)
            detailsFlick.contentY = Math.min(maximumY, top + item.height + margin - detailsFlick.height)
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealFocusedControl) }
    }

    function tune() { AppController.navigate("settings-streaming") }
    readonly property var summaryCards: [
        {glyph:"monitor", title:resolutionText + " · " + fpsText, detail:codecText + " · " + String(streamSettings.colorQuality || "8bit_420").replace("_", " ")},
        {glyph:"globe", title:regionLabel(), detail:qsTr("Region selected at launch")},
        {glyph:"clock", title:membershipText || qsTr("Membership"), detail:ShellStore.remainingPlaytimeHours !== null
            ? qsTr("%1 h remaining").arg(ShellStore.remainingPlaytimeHours.toFixed(1)) : qsTr("Entitlements checked at launch")}
    ]
    function regionLabel() {
        const value = String(streamSettings.region || "")
        const regions = ShellStore.regions || []
        for (const region of regions)
            if (region.url === value || region.name === value) return String(region.name)
        return value ? qsTr("Selected region") : qsTr("Automatic region")
    }
    Rectangle {
        anchors.fill: parent; color: Theme.shell; opacity: reveal.progress
        MouseArea {
            anchors.fill: parent; acceptedButtons: Qt.AllButtons
            hoverEnabled: true; preventStealing: true
            onClicked: root.closeRequested()
            onWheel: wheel => wheel.accepted = true
        }
    }
    // The key art is the whole background: a centred cover crop at full
    // saturation, edge to edge, with only corner-anchored scrims on top.
    Item {
        id: backdrop
        anchors.fill: parent
        opacity: reveal.progress
        RoundedArtwork {
            anchors.fill: parent
            artwork: DesktopTokens.backdropArtworkUrl(root.game, Math.ceil(width * Screen.devicePixelRatio))
            // Should the wider request ever fail, the catalog-width hero is
            // exactly what today's build shows, so the backdrop never empties.
            fallbackArtwork: DesktopTokens.artworkUrl(root.game, true)
            cornerRadius: 0
            cinematicFit: false
            scrimStart: 1
            fallbackColor: Theme.shell
            scale: 1 + 0.035 * (1 - reveal.zoom)
            transformOrigin: Item.Center
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.42; color: "transparent" }
                GradientStop { position: 1; color: root.scrimBottom }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.scrimLeft }
                GradientStop { position: 0.62; color: "transparent" }
            }
        }
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.2
            gradient: Gradient {
                GradientStop { position: 0; color: root.scrimTop }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Rectangle {
        id: dialog
        objectName: "gameDetailsDialog"
        opacity: reveal.progress
        anchors.centerIn: parent
        width: root.dialogWidth; height: root.dialogHeight
        radius: 0; color: "transparent"; border.width: 0
        Flickable {
            id: detailsFlick
            objectName: "gameDetailsScroll"
            anchors.fill: parent
            contentWidth: width
            contentHeight: detailsColumn.y + detailsColumn.implicitHeight
            // Blank artwork still dismisses; the column sits above this area.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.closeRequested()
            }
            clip: true; boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            onHeightChanged: Qt.callLater(root.revealFocusedControl)
            onContentHeightChanged: Qt.callLater(root.revealFocusedControl)
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: DesktopTokens.px(10)
                padding: DesktopTokens.px(3)
                background: Item {}
                contentItem: Rectangle {
                    radius: width / 2
                    color: Theme.lightMode ? "#59101827" : "#59EEF2F8"
                }
            }
            Column {
                id: detailsColumn
                // Docked to the bottom of the view: the title lands mid-left
                // over the anchored scrim, and short content never floats.
                y: Math.max(0, detailsFlick.height - implicitHeight)
                width: parent.width
                Item {
                    objectName: "gameDetailsHero"
                    width: parent.width
                    // The backdrop carries the artwork, so the hero is only the
                    // title block. The proportional term binds on every window
                    // the details open on, which keeps the height independent of
                    // the DLSS row: games with and without chips open identically.
                    height: root.heroHeight
                    Column {
                        id: headerInfo
                        x: root.columnInset; anchors.bottom: parent.bottom; anchors.bottomMargin: root.heroBottomMargin
                        width: root.contentWidth; spacing: root.heroSpacing
                        Text {
                            width: parent.width
                            visible: !root.compactDetails && text !== ""
                            text: [root.game && (root.game.publisherName || root.game.publisher) || "",
                                root.membershipText].filter(Boolean).join(" · ").toUpperCase()
                            color: Theme.textFaint
                            elide: Text.ElideRight
                            font.family: Theme.monoFont
                            font.pixelSize: DesktopTokens.smallSize
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Text {
                            width: parent.width; text: root.game ? String(root.game.title || qsTr("Game")) : qsTr("Game")
                            color: Theme.label; font.family: Theme.displayFont
                            font.pixelSize: root.heroTitleSize; font.weight: Font.Black
                            // A short window keeps one elided line, so the title
                            // block can never push the primary action past the
                            // dialog cap no matter how long the name is.
                            wrapMode: Text.WordWrap
                            maximumLineCount: root.compactDetails ? 1 : 2
                            elide: Text.ElideRight
                        }
                        Flow {
                            width: parent.width; spacing: DesktopTokens.px(10)
                            Rectangle {
                                width: Math.min(parent.width, ownedText.implicitWidth + DesktopTokens.px(20))
                                height: DesktopTokens.px(26); radius: DesktopTokens.px(13); color: DesktopTokens.raisedStrong
                                Text { id: ownedText; anchors.centerIn: parent; width: parent.width - DesktopTokens.px(20); elide: Text.ElideRight; text: root.ownershipText; color: Theme.label; font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.captionSize; font.weight: Font.Bold }
                            }
                            Text {
                                width: Math.min(implicitWidth, parent.width)
                                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                // The eyebrow above already names the publisher.
                                text: [root.lastPlayedText, root.game && root.game.hoursPlayed ? qsTr("%1 h").arg(root.game.hoursPlayed) : ""].filter(Boolean).join(" · ")
                                color: Theme.textMuted; font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.captionSize
                            }
                        }
                        DesktopGameDlssChips {
                            width: parent.width
                            info: dlssInfo
                            expanded: root.dlssExpanded
                            onToggleRequested: root.dlssExpanded = !root.dlssExpanded
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: bodyContent.implicitHeight + DesktopTokens.px(24)
                    Column {
                        id: bodyContent
                        objectName: "gameDetailsBody"
                        x: root.columnInset
                        width: root.contentWidth
                        spacing: DesktopTokens.px(20)
                        DesktopGameDlssPanel {
                            width: parent.width
                            info: dlssInfo
                            visible: root.dlssExpanded && (dlssInfo.listed || dlssInfo.notListed)
                        }
                        Column {
                            objectName: "gameDetailsReadiness"
                            width: parent.width
                            spacing: DesktopTokens.px(8)
                            Row {
                                id: membershipNotice
                                objectName: "gameDetailsMembershipNotice"
                                width: parent.width
                                visible: root.lockedByMembership
                                spacing: DesktopTokens.px(8)
                                Image {
                                    y: DesktopTokens.px(2)
                                    width: DesktopTokens.px(14)
                                    height: width
                                    source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-lock.svg"
                                    sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                                }
                                Text {
                                    width: parent.width - DesktopTokens.px(22)
                                    text: qsTr("%1 needs a paid GeForce NOW membership. Your Free plan can't start it.")
                                        .arg(String(root.game && root.game.title || qsTr("This game")))
                                    wrapMode: Text.WordWrap
                                    color: Theme.lightMode ? Theme.label : DesktopTokens.amber
                                    font.family: Theme.bodyFont
                                    font.pixelSize: DesktopTokens.captionSize
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                id: readinessNoticeLabel
                                objectName: "catalogReadinessNotice"
                                width: parent.width
                                text: I18n.source(ShellStore.cloudMutationMessage || ShellStore.selectedLaunchDecision.message || ShellStore.readinessNotice(root.game), I18n.revision)
                                readonly property bool shown: text !== "" && !(root.lockedByMembership && !ShellStore.cloudMutationMessage
                                    && ShellStore.selectedLaunchDecision.status === "subscription_required")
                                visible: shown
                                wrapMode: Text.WordWrap
                                color: ShellStore.cloudMutationState === "unconfirmed" ? (Theme.lightMode ? Qt.darker(DesktopTokens.danger, 2) : DesktopTokens.danger) : Theme.textMuted
                                font.family: Theme.bodyFont
                                font.pixelSize: DesktopTokens.captionSize
                            }
                            visible: storeVariants.count > 1 || readinessNoticeLabel.shown || root.lockedByMembership
                            Text {
                                text: qsTr("PLATFORM")
                                visible: storeVariants.count > 1
                                color: Theme.textMuted
                                font.family: Theme.bodyFont
                                font.pixelSize: DesktopTokens.smallSize
                                font.weight: Font.Bold
                            }
                            Flow {
                                visible: storeVariants.count > 1
                                width: parent.width
                                spacing: DesktopTokens.px(8)
                                Repeater {
                                    id: storeVariants
                                    model: root.game ? root.game.variants || [] : []
                                    DesktopButton {
                                        id: platformButton
                                        required property var modelData
                                        required property int index
                                        objectName: "desktopStoreVariant" + index
                                        text: String(modelData.store || qsTr("Unknown"))
                                        height: DesktopTokens.px(36)
                                        leftPadding: DesktopTokens.px(14)
                                        rightPadding: DesktopTokens.px(14)
                                        font.pixelSize: DesktopTokens.captionSize
                                        implicitWidth: platformContents.implicitWidth + leftPadding + rightPadding
                                        checkable: true
                                        autoExclusive: true
                                        checked: root.game ? index === Number(root.game.selectedVariantIndex || 0) : false
                                        primary: checked
                                        readonly property string ownership: ConsoleStores.ownership(modelData)
                                        Accessible.description: ConsoleStores.ownershipLabel(modelData)
                                        onClicked: root.variantSelected(index)
                                        Keys.onReturnPressed: root.variantSelected(index)
                                        Keys.onEnterPressed: root.variantSelected(index)
                                        contentItem: Row {
                                            id: platformContents
                                            spacing: DesktopTokens.px(8)
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: DesktopTokens.px(26)
                                                height: width
                                                radius: DesktopTokens.px(5)
                                                visible: platformLogo.source.toString() !== ""
                                                color: platformButton.checked || Theme.lightMode ? "#202634" : "transparent"
                                                Image {
                                                    id: platformLogo
                                                    objectName: "desktopStoreLogo" + platformButton.index
                                                    anchors.centerIn: parent
                                                    width: DesktopTokens.px(20)
                                                    height: width
                                                    source: DesktopTokens.storeIconUrl(platformButton.modelData.store)
                                                    sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                                                    fillMode: Image.PreserveAspectFit
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: platformButton.text
                                                font: platformButton.font
                                                color: platformButton.checked ? "#0A0D14" : Theme.label
                                            }
                                            Rectangle {
                                                objectName: "desktopStoreOwnership" + platformButton.index
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: platformButton.ownership !== "unknown"
                                                width: ownershipTag.implicitWidth + DesktopTokens.px(platformButton.ownership === "owned" ? 22 : 14)
                                                height: DesktopTokens.px(18)
                                                radius: height / 2
                                                color: platformButton.ownership === "owned" ? Qt.rgba(0.114, 0.725, 0.329, 0.16) : "transparent"
                                                border.width: 1
                                                border.color: platformButton.ownership === "owned" ? Qt.rgba(0.114, 0.725, 0.329, 0.45)
                                                    : platformButton.checked ? "#330A0D14" : Theme.seam
                                                Rectangle {
                                                    visible: platformButton.ownership === "owned"
                                                    x: DesktopTokens.px(7)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: DesktopTokens.px(5)
                                                    height: width
                                                    radius: width / 2
                                                    color: DesktopTokens.green
                                                }
                                                Text {
                                                    id: ownershipTag
                                                    x: platformButton.ownership === "owned" ? DesktopTokens.px(15) : DesktopTokens.px(7)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: platformButton.ownership === "owned" ? qsTr("OWNED") : qsTr("NOT OWNED")
                                                    color: platformButton.ownership === "owned"
                                                        ? (platformButton.checked || Theme.lightMode ? "#126B4E" : DesktopTokens.green)
                                                        : platformButton.checked ? "#990A0D14" : Theme.textMuted
                                                    font.family: Theme.monoFont
                                                    font.pixelSize: DesktopTokens.tinySize
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 0.6
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            id: actionRow
                            objectName: "gameDetailsPrimaryActions"
                            width: parent.width
                            spacing: DesktopTokens.px(10)
                            DesktopButton {
                                id: primaryAction
                                objectName: "desktopGamePlay"
                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                Layout.preferredHeight: root.primaryActionHeight
                                font.pixelSize: DesktopTokens.headingSize
                                glyphSize: DesktopTokens.px(18)
                                leftPadding: DesktopTokens.px(20); rightPadding: DesktopTokens.px(20)
                                primary: true; glyph: "desktop-play.svg"; text: ShellStore.selectedGameActionLabel(); shortcutText: qsTr("ENTER"); shortcutSequence: "Enter"
                                enabled: root.game !== null && !ShellStore.cloudMutationBusy && ShellStore.launchInspectRequestId === ""
                                onClicked: root.playRequested()
                                // Hero action: the accent-to-violet sweep the library
                                // cards use for their PLAY pill, with the fixed dark
                                // ink that sweep is tuned for.
                                background: Rectangle {
                                    radius: height / 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop {
                                            position: 0
                                            color: primaryAction.down ? DesktopTokens.actionStartDown
                                                : primaryAction.hovered || primaryAction.activeFocus
                                                ? DesktopTokens.actionStartHover : DesktopTokens.actionStart
                                        }
                                        GradientStop {
                                            position: 1
                                            color: primaryAction.down ? DesktopTokens.actionEndDown
                                                : primaryAction.hovered || primaryAction.activeFocus
                                                ? DesktopTokens.actionEndHover : DesktopTokens.actionEnd
                                        }
                                    }
                                    border.width: 1
                                    border.color: "#2E0A0D14"
                                    scale: primaryAction.down && !AppController.reducedMotion ? 0.985 : 1
                                    Behavior on scale {
                                        NumberAnimation { duration: DesktopTokens.quickDuration; easing.type: Easing.OutCubic }
                                    }
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        height: parent.height * 0.45
                                        radius: parent.radius
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: "#3DFFFFFF" }
                                            GradientStop { position: 1; color: "transparent" }
                                        }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        radius: parent.radius + 3
                                        color: "transparent"
                                        border.width: 2
                                        border.color: DesktopTokens.focus
                                        visible: primaryAction.activeFocus
                                    }
                                }
                            }
                            DesktopButton {
                                Layout.preferredWidth: root.primaryActionHeight; Layout.preferredHeight: root.primaryActionHeight
                                themedGlyph: "star"; leftPadding: 0; rightPadding: 0
                                Accessible.name: root.game && ShellStore.isCloudFavorite(root.game) ? qsTr("Remove from GeForce NOW favorites") : qsTr("Add to GeForce NOW favorites")
                                ToolTip.visible: hovered; ToolTip.text: Accessible.name
                                enabled: ShellStore.signedIn && !ShellStore.cloudMutationBusy
                                onClicked: if (root.game) ShellStore.toggleCloudFavorite(root.game)
                            }
                            DesktopButton {
                                Layout.preferredWidth: root.primaryActionHeight; Layout.preferredHeight: root.primaryActionHeight
                                themedGlyph: "folder"; leftPadding: 0; rightPadding: 0
                                Accessible.name: qsTr("Collections")
                                ToolTip.visible: hovered; ToolTip.text: Accessible.name
                                onClicked: collectionMenu.popup()
                                Menu {
                                    id: collectionMenu
                                    MenuItem { text: qsTr("Pin to Home"); checkable: true; checked: root.game && ShellStore.isFavorite(root.game); onTriggered: if (root.game) ShellStore.toggleFavorite(root.game) }
                                }
                            }
                            DesktopButton {
                                Layout.preferredWidth: root.primaryActionHeight; Layout.preferredHeight: root.primaryActionHeight
                                themedGlyph: "more"; leftPadding: 0; rightPadding: 0
                                Accessible.name: qsTr("More game actions")
                                onClicked: moreMenu.popup()
                                Menu {
                                    id: moreMenu
                                    MenuItem { text: qsTr("Stream settings"); onTriggered: root.tune() }
                                    MenuItem { text: qsTr("Close details"); onTriggered: root.closeRequested() }
                                }
                            }
                        }
                        // What still stands between the player and a launch,
                        // named by the store the license comes from.
                        Row {
                            objectName: "gameDetailsStoreRequirement"
                            width: parent.width
                            visible: root.requirementText !== ""
                            spacing: DesktopTokens.px(10)
                            Rectangle {
                                y: DesktopTokens.px(1)
                                width: DesktopTokens.px(28)
                                height: DesktopTokens.px(28)
                                radius: DesktopTokens.px(8)
                                visible: requirementIcon.source.toString() !== ""
                                color: Theme.lightMode ? "#14080D14" : "#24FFFFFF"
                                Image {
                                    id: requirementIcon
                                    anchors.centerIn: parent
                                    width: DesktopTokens.px(19)
                                    height: DesktopTokens.px(19)
                                    source: DesktopTokens.storeIconUrl(root.requirementStoreKey)
                                    sourceSize: Qt.size(Math.max(1, Math.round(width * Screen.devicePixelRatio)),
                                                        Math.max(1, Math.round(height * Screen.devicePixelRatio)))
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                            Text {
                                width: parent.width - DesktopTokens.px(38)
                                text: root.requirementText
                                wrapMode: Text.WordWrap
                                color: root.isOwned ? Theme.textMuted : Theme.label
                                font.family: Theme.bodyFont
                                font.pixelSize: DesktopTokens.captionSize
                                font.weight: root.isOwned ? Font.Normal : Font.Bold
                            }
                        }
                        DesktopButton {
                            id: gameplaySettingsToggle
                            objectName: "gameDetailsGameplaySettings"
                            width: Math.min(parent.width, implicitWidth)
                            height: DesktopTokens.px(36)
                            checkable: true
                            checked: root.gameplaySettingsShown
                            onToggled: root.gameplaySettingsShown = checked
                            leftPadding: DesktopTokens.px(10); rightPadding: DesktopTokens.px(16)
                            implicitWidth: toggleRow.implicitWidth + leftPadding + rightPadding
                            font.pixelSize: DesktopTokens.captionSize
                            text: qsTr("Show gameplay settings before launch")
                            Accessible.name: text
                            background: Rectangle {
                                radius: height / 2
                                color: gameplaySettingsToggle.hovered || gameplaySettingsToggle.activeFocus
                                    ? DesktopTokens.raisedStrong : "transparent"
                                border.width: 1
                                border.color: gameplaySettingsToggle.activeFocus
                                    ? DesktopTokens.focus : DesktopTokens.seamSoft
                                Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                                Behavior on border.color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                            }
                            contentItem: Item {
                                implicitWidth: toggleRow.implicitWidth
                                implicitHeight: toggleRow.implicitHeight
                                Row {
                                    id: toggleRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: DesktopTokens.px(9)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: DesktopTokens.px(19)
                                        height: DesktopTokens.px(19)
                                        radius: DesktopTokens.px(6)
                                        color: gameplaySettingsToggle.checked ? Theme.focus : "transparent"
                                        border.width: gameplaySettingsToggle.checked ? 0 : 2
                                        border.color: gameplaySettingsToggle.checked ? Theme.focus : Theme.textFaint
                                        Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                                        DesktopSettingsIcon {
                                            anchors.centerIn: parent
                                            width: DesktopTokens.px(12)
                                            height: DesktopTokens.px(12)
                                            glyph: "check"
                                            ink: Theme.focusText
                                            visible: gameplaySettingsToggle.checked
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: gameplaySettingsToggle.text
                                        color: DesktopTokens.textHigh
                                        font: gameplaySettingsToggle.font
                                    }
                                }
                            }
                        }
                        // The stream requests this game would launch with, shown
                        // before launch instead of only inside the settings page.
                        Rectangle {
                            objectName: "gameDetailsGameplaySettingsPanel"
                            width: parent.width
                            height: settingsRows.implicitHeight + DesktopTokens.px(24)
                            radius: DesktopTokens.px(16)
                            visible: root.gameplaySettingsShown
                            color: DesktopTokens.raised
                            border.width: 1
                            border.color: DesktopTokens.seamSoft
                            Column {
                                id: settingsRows
                                x: DesktopTokens.px(16)
                                y: DesktopTokens.px(12)
                                width: parent.width - DesktopTokens.px(32)
                                spacing: DesktopTokens.px(8)
                                Repeater {
                                    model: root.streamRows
                                    Row {
                                        required property var modelData
                                        width: parent.width
                                        Text {
                                            width: parent.width * 0.5
                                            text: modelData.l
                                            color: Theme.textMuted
                                            font.family: Theme.bodyFont
                                            font.pixelSize: DesktopTokens.captionSize
                                        }
                                        Text {
                                            width: parent.width * 0.5
                                            text: modelData.v
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignRight
                                            color: Theme.label
                                            font.family: Theme.monoFont
                                            font.pixelSize: DesktopTokens.captionSize
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: qsTr("Requests only. The rig decides the final stream.")
                                    wrapMode: Text.WordWrap
                                    color: Theme.textFaint
                                    font.family: Theme.bodyFont
                                    font.pixelSize: DesktopTokens.smallSize
                                }
                            }
                        }
                        CloudLibraryActions {
                            width: parent.width
                            game: root.game
                            showFavorites: false
                            showStatus: false
                        }
                        GridLayout {
                            id: summaryGrid
                            objectName: "gameDetailsSummary"
                            width: parent.width
                            columns: width < DesktopTokens.px(620) ? 2 : 4
                            uniformCellWidths: columns === 2
                            columnSpacing: DesktopTokens.px(10); rowSpacing: DesktopTokens.px(10)
                            Repeater {
                                model: root.summaryCards
                                delegate: Rectangle {
                                    required property var modelData
                                    objectName: "gameDetailsSummaryCard"
                                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredHeight: DesktopTokens.px(68)
                                    Layout.preferredWidth: DesktopTokens.px(180)
                                    radius: DesktopTokens.px(16); color: DesktopTokens.raised
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: DesktopTokens.px(12); spacing: DesktopTokens.px(12)
                                        Rectangle {
                                            Layout.preferredWidth: DesktopTokens.px(36); Layout.preferredHeight: DesktopTokens.px(36)
                                            radius: DesktopTokens.px(11); color: DesktopTokens.raised
                                            // Paper's accent icons sit on their own tile. Never use
                                            // the fixed dark-ink settings SVGs on a dark surface.
                                            DesktopSettingsIcon {
                                                anchors.centerIn: parent; width: DesktopTokens.px(18); height: DesktopTokens.px(18)
                                                glyph: modelData.glyph
                                                ink: Theme.lightMode ? Theme.label : Theme.focus
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: DesktopTokens.px(2)
                                            Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: modelData.title; elide: Text.ElideRight; color: Theme.label; font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.captionSize; font.weight: Font.Bold }
                                            Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: modelData.detail; elide: Text.ElideRight; color: Theme.textMuted; font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.smallSize }
                                        }
                                    }
                                }
                            }
                            DesktopButton {
                                objectName: "gameDetailsTune"
                                Layout.fillWidth: summaryGrid.columns === 2
                                Layout.preferredWidth: Math.max(implicitWidth, DesktopTokens.px(68)); Layout.preferredHeight: DesktopTokens.px(68)
                                font.pixelSize: DesktopTokens.captionSize
                                text: qsTr("Tune"); themedGlyph: "sliders"; leftPadding: DesktopTokens.px(6); rightPadding: DesktopTokens.px(6)
                                onClicked: root.tune()
                            }
                        }
                    }
                }
            }
        }
        DesktopButton {
            objectName: "gameDetailsBack"
            // A short window has no headroom for a top bar above the title.
            visible: !root.compactDetails
            anchors.left: parent.left; anchors.leftMargin: DesktopTokens.px(24)
            anchors.top: parent.top; anchors.topMargin: DesktopTokens.px(24)
            height: DesktopTokens.px(40)
            font.pixelSize: DesktopTokens.captionSize
            leftPadding: DesktopTokens.px(36); rightPadding: DesktopTokens.px(18)
            cornerRadius: height / 2
            text: qsTr("Library")
            onClicked: root.closeRequested()
            Image {
                x: DesktopTokens.px(15)
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(12); height: DesktopTokens.px(12)
                rotation: -90
                source: Theme.lightMode ? "qrc:/qt/qml/OpenNOW/res/icons/desktop-chevron-up-on-light.svg"
                                          : "qrc:/qt/qml/OpenNOW/res/icons/desktop-chevron-up.svg"
                sourceSize: Qt.size(Math.max(1, Math.round(width * Screen.devicePixelRatio)),
                                    Math.max(1, Math.round(height * Screen.devicePixelRatio)))
                fillMode: Image.PreserveAspectFit
            }
        }
        DesktopButton {
            objectName: "gameDetailsClose"
            anchors.right: parent.right; anchors.rightMargin: DesktopTokens.px(24)
            anchors.top: parent.top; anchors.topMargin: DesktopTokens.px(24)
            width: DesktopTokens.px(40); height: DesktopTokens.px(40); themedGlyph: "close"; leftPadding: 0; rightPadding: 0
            cornerRadius: width / 2
            Accessible.name: qsTr("Close details")
            onClicked: root.closeRequested()
        }
    }
    Keys.onEscapePressed: root.closeRequested()
    Keys.onReturnPressed: if (primaryAction.enabled) root.playRequested()
}
