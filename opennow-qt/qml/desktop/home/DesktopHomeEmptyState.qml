pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomeEmptyState — what Home shows when there is nothing to feature.
// =============================================================================
//
// Home has three "no games" situations and each needs a different message:
//   * signed out  — explain that the library comes from the GeForce NOW account
//   * syncing     — the catalog is in flight, so show progress and patience
//   * empty/error — signed in but nothing synced, so point at Library and Store
//
// Rather than three near-duplicate screens, one component switches copy and
// actions from `uiState`, and always shows the same three-step onboarding path so
// the layout never jumps between states.
//
// Sections:
//   1. plate + ambient glow
//   2. illustration (stacked tile glyphs, animated while syncing)
//   3. headline + body copy for the active state
//   4. step list (Sync → Pin → Play)
//   5. actions (primary + secondary, state aware)
//   6. rotating tip line
//   7. accessibility
// =============================================================================
Item {
    id: root
    objectName: "desktopHomeEmptyState"

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    property bool signedIn: false
    property bool syncing: false
    property bool failed: false
    property bool active: true
    property string errorMessage: ""

    /// Auto-retry budget for the error state. OpenNOW retries on its own a few
    /// times before asking the player to decide, which covers the common case of
    /// a store hiccup without hammering the catalog endpoint forever.
    property int retryCooldown: 15
    property int retryLimit: 3

    signal libraryRequested()
    signal storeRequested()
    signal signInRequested()
    signal retryRequested()

    // -------------------------------------------------------------------------
    // Derived state
    // -------------------------------------------------------------------------
    // Named uiState because QQuickItem already owns `state` for QML states.
    readonly property string uiState: !signedIn ? "signed-out"
        : syncing ? "syncing" : failed ? "error" : "empty"
    readonly property bool motionOff: AppController.reducedMotion
    readonly property string headline: {
        if (uiState === "signed-out")
            return qsTr("Welcome to OpenNOW")
        if (uiState === "syncing")
            return qsTr("Syncing your library…")
        if (uiState === "error")
            return qsTr("We could not load your games")
        if (allHidden)
            return qsTr("Everything is hidden")
        return qsTr("Your library is ready")
    }
    readonly property string body: {
        if (uiState === "signed-out")
            return qsTr("Sign in with your GeForce NOW account and Home fills up with the games you own, the sessions you left open and the titles you pinned for quick play.")
        if (uiState === "syncing")
            return qsTr("OpenNOW is reading your connected stores. This usually takes a few seconds; the dock and rails appear as soon as the first games arrive.")
        if (uiState === "error")
            return errorMessage !== "" ? errorMessage
                : qsTr("The catalog request did not finish. Check your connection and try again, or open the library to see what was already synced.")
        if (allHidden)
            return qsTr("You hid all %1 games in your library, so Home has nothing to feature. Open the library and unhide a title to bring it back here.").arg(hiddenCount)
        return qsTr("No games are synced yet. Open the library to sync your connected stores, or browse the store to discover what is available on your account.")
    }
    readonly property var steps: [
        { label: qsTr("Sync"), detail: qsTr("Connect a store and pull your games") },
        { label: qsTr("Pin"), detail: qsTr("Star the titles you play most") },
        { label: qsTr("Play"), detail: qsTr("Launch straight from the dock") }
    ]
    readonly property var tips: [
        qsTr("Tip: press Enter on a dock icon to open the game, Space to launch it."),
        qsTr("Tip: pinned games get their own rail so they are always one tap away."),
        qsTr("Tip: the background art follows the focused icon, just like a console."),
        qsTr("Tip: right-click a card to pin or unpin it without opening details.")
    ]
    property int tipIndex: 0

    // -- Retry state ---------------------------------------------------------
    /// Seconds left before the next automatic retry, 0 when not counting.
    property int retrySeconds: 0
    /// How many times this state has already retried on its own.
    property int retryAttempts: 0
    /// Flash shown after the diagnostics are copied to the clipboard.
    property bool copiedFlash: false

    readonly property bool retryArmed: uiState === "error" && retryAttempts < retryLimit
    /// Games the player hid themselves. A library that only looks empty because
    /// everything is hidden gets a different, actionable message.
    readonly property int hiddenCount: {
        const list = ShellStore.catalogGames || []
        return list.filter(game => ShellStore.isHidden(game)).length
    }
    readonly property bool allHidden: hiddenCount > 0 && ShellStore.catalogTotalCount === hiddenCount
    /// Coarse network guess from the failure text, used to pick the right hint.
    readonly property bool looksOffline: /offline|network|dns|timed ?out|timeout|unreachable|connection|resolve/i.test(String(errorMessage))
    /// An uppercase error code or HTTP status inside the failure text, if any.
    readonly property string errorCode: {
        const match = String(errorMessage).match(/\b(?:[A-Z][A-Z0-9_]{3,}|\d{3})\b/)
        return match ? String(match[0]) : ""
    }
    readonly property string diagnosticsText: {
        const lines = [
            qsTr("OpenNOW home empty state"),
            qsTr("state: %1").arg(uiState),
            qsTr("signed in: %1").arg(signedIn ? "yes" : "no"),
            qsTr("catalog games: %1").arg(ShellStore.catalogTotalCount),
            qsTr("hidden games: %1").arg(hiddenCount)
        ]
        if (errorCode !== "")
            lines.push(qsTr("error code: %1").arg(errorCode))
        if (errorMessage !== "")
            lines.push(qsTr("error: %1").arg(errorMessage))
        return lines.join("\n")
    }
    /// The four live facts rendered by the status grid.
    readonly property var statusCells: {
        const total = Number(ShellStore.catalogTotalCount || 0)
        const store = Number(ShellStore.storeTotalCount || 0)
        return [
            {
                label: qsTr("ACCOUNT"),
                value: signedIn ? qsTr("Signed in") : qsTr("Signed out"),
                tone: signedIn ? "ok" : "warn"
            },
            {
                label: qsTr("LIBRARY"),
                value: syncing ? qsTr("Syncing") : qsTr("%1 games").arg(total),
                tone: syncing ? "warn" : (total === 0 && signedIn ? "bad" : "ok")
            },
            {
                label: qsTr("HIDDEN"),
                value: qsTr("%1 games").arg(hiddenCount),
                tone: allHidden ? "bad" : "ok"
            },
            {
                label: qsTr("STORE"),
                value: store > 0 ? qsTr("%1 to stream").arg(store) : qsTr("Not loaded"),
                tone: store > 0 ? "ok" : "warn"
            }
        ]
    }

    /// The diagnostics card only earns its space when there is something to say.
    readonly property bool showDiagnostics: uiState === "error"
        || (uiState === "empty" && allHidden)

    onUiStateChanged: {
        if (uiState === "error") {
            retryAttempts += 1
            retrySeconds = retryCooldown
        } else {
            retrySeconds = 0
        }
    }

    Timer {
        id: retryTimer
        interval: 1000
        repeat: true
        running: root.retryArmed && root.retrySeconds > 0 && root.active && root.visible
        onTriggered: {
            root.retrySeconds -= 1
            if (root.retrySeconds <= 0)
                root.requestRetry()
        }
    }

    Timer {
        id: copiedTimer
        interval: 1800
        repeat: false
        onTriggered: root.copiedFlash = false
    }

    /// Single entry point for retries so the manual button and the countdown
    /// behave identically and never double-fire.
    function requestRetry() {
        retryTimer.stop()
        retrySeconds = 0
        root.retryRequested()
    }

    function copyDiagnostics() {
        if (!AppController.writeClipboardText(diagnosticsText))
            return
        copiedFlash = true
        copiedTimer.restart()
    }

    Timer {
        interval: 7000
        repeat: true
        running: root.active && root.visible && !root.motionOff
        onTriggered: root.tipIndex = (root.tipIndex + 1) % root.tips.length
    }

    /// Fixed top inset. Anchoring the chain to a constant instead of centring
    /// the plate is what lets the plate measure its content without creating a
    /// binding cycle through its own y.
    readonly property real contentTop: DesktopTokens.px(24)
    /// Bottom of the last element in the copy chain.
    readonly property real contentBottom: tipLine.y + tipLine.height

    implicitHeight: contentTop + plate.height + DesktopTokens.px(24)
    Behavior on implicitHeight {
        NumberAnimation { duration: root.motionOff ? 0 : 220; easing.type: Easing.OutCubic }
    }
    height: implicitHeight
    Accessible.role: Accessible.Pane
    Accessible.name: headline
    Accessible.description: body

    /// One placeholder tile in the illustration. `ghostOffset` is animated by
    /// the syncing bob so the tiles can be frozen under reduced motion.
    component GhostTile: Rectangle {
        id: ghost
        property real ghostOffset: 0
        width: DesktopTokens.px(46)
        height: DesktopTokens.px(46)
        radius: DesktopTokens.px(13)
        color: Theme.lightMode ? "#14040610" : "#1FFFFFFF"
        border.width: 1
        border.color: Theme.lightMode ? "#1F040610" : "#33FFFFFF"
        transform: Translate { y: ghost.ghostOffset }

        DesktopGlyph {
            anchors.centerIn: parent
            width: DesktopTokens.px(20)
            height: DesktopTokens.px(20)
            icon: "desktop-nav-library.svg"
            opacity: 0.55
        }
    }

    // =========================================================================
    // 1. Plate + ambient glow
    // =========================================================================
    Rectangle {
        id: plate
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.contentTop
        width: Math.min(DesktopTokens.px(620), parent.width - DesktopTokens.px(32))
        height: root.contentBottom - root.contentTop + DesktopTokens.px(24)
        Behavior on height {
            NumberAnimation { duration: root.motionOff ? 0 : 220; easing.type: Easing.OutCubic }
        }
        radius: DesktopTokens.px(26)
        color: Theme.lightMode ? "#E6F2F5FA" : "#E60B1320"
        border.width: 1
        border.color: Theme.lightMode ? "#1F040610" : "#24FFFFFF"

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: parent.height * 0.45
            radius: DesktopTokens.px(25)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.lightMode ? "#33FFFFFF" : "#12FFFFFF" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // Ambient accent bloom behind the plate.
    Rectangle {
        anchors.centerIn: plate
        width: plate.width + DesktopTokens.px(60)
        height: plate.height + DesktopTokens.px(60)
        radius: width / 2
        color: Theme.focus
        opacity: Theme.lightMode ? 0.06 : 0.12
        z: -1
    }

    // =========================================================================
    // 2. Illustration
    // =========================================================================
    Item {
        id: illustration
        anchors.horizontalCenter: plate.horizontalCenter
        y: plate.y + DesktopTokens.px(26)
        width: DesktopTokens.px(150)
        height: DesktopTokens.px(58)

        GhostTile {
            x: 0
            y: DesktopTokens.px(6)
            ghostOffset: root.uiState === "syncing" && !root.motionOff ? bobA.value : 0
        }
        GhostTile {
            x: DesktopTokens.px(52)
            y: 0
            ghostOffset: root.uiState === "syncing" && !root.motionOff ? bobB.value : 0
        }
        GhostTile {
            x: DesktopTokens.px(104)
            y: DesktopTokens.px(6)
            ghostOffset: root.uiState === "syncing" && !root.motionOff ? bobC.value : 0
        }

        // Staggered bobbing while syncing.
        SequentialAnimation {
            loops: Animation.Infinite
            running: root.uiState === "syncing" && !root.motionOff && root.visible
            NumberAnimation { target: bobA; property: "value"; from: 0; to: -6; duration: 420; easing.type: Easing.OutSine }
            NumberAnimation { target: bobA; property: "value"; from: -6; to: 0; duration: 420; easing.type: Easing.InSine }
        }
        SequentialAnimation {
            loops: Animation.Infinite
            running: root.uiState === "syncing" && !root.motionOff && root.visible
            NumberAnimation { target: bobB; property: "value"; from: 0; to: -8; duration: 460; easing.type: Easing.OutSine }
            NumberAnimation { target: bobB; property: "value"; from: -8; to: 0; duration: 460; easing.type: Easing.InSine }
        }
        SequentialAnimation {
            loops: Animation.Infinite
            running: root.uiState === "syncing" && !root.motionOff && root.visible
            NumberAnimation { target: bobC; property: "value"; from: 0; to: -6; duration: 500; easing.type: Easing.OutSine }
            NumberAnimation { target: bobC; property: "value"; from: -6; to: 0; duration: 500; easing.type: Easing.InSine }
        }
    }

    // Animation value holders (kept off the visual tree so they can be frozen).
    QtObject { id: bobA; property real value: 0 }
    QtObject { id: bobB; property real value: 0 }
    QtObject { id: bobC; property real value: 0 }

    // =========================================================================
    // 3. Headline + body
    // =========================================================================
    Column {
        id: copyColumn
        anchors.horizontalCenter: plate.horizontalCenter
        y: illustration.y + illustration.height + DesktopTokens.px(18)
        width: plate.width - DesktopTokens.px(72)
        spacing: DesktopTokens.px(8)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: DesktopTokens.px(7)
            visible: root.uiState === "syncing" || root.uiState === "error"

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(7)
                height: DesktopTokens.px(7)
                radius: DesktopTokens.px(3.5)
                color: root.uiState === "error" ? DesktopTokens.danger : DesktopTokens.ledAmber

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: !root.motionOff
                    NumberAnimation { from: 1; to: 0.35; duration: 800 }
                    NumberAnimation { from: 0.35; to: 1; duration: 800 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.uiState === "error" ? qsTr("NEEDS ATTENTION") : qsTr("IN PROGRESS")
                color: root.uiState === "error" ? DesktopTokens.danger : DesktopTokens.ledAmber
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.headline
            color: DesktopTokens.textHigh
            font.family: DesktopTokens.displayFont
            font.pixelSize: DesktopTokens.px(23)
            font.weight: Font.Black
            font.letterSpacing: -0.5
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.body
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
            font.weight: Font.DemiBold
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    // =========================================================================
    // 4. Step list
    // =========================================================================
    Row {
        id: stepRow
        anchors.horizontalCenter: plate.horizontalCenter
        y: copyColumn.y + copyColumn.height + DesktopTokens.px(16)
        spacing: DesktopTokens.px(10)

        Repeater {
            model: root.steps
            Rectangle {
                id: step
                required property var modelData
                required property int index
                width: DesktopTokens.px(158)
                height: DesktopTokens.px(58)
                radius: DesktopTokens.px(14)
                color: Theme.lightMode ? "#14040610" : "#14FFFFFF"
                border.width: 1
                border.color: Theme.lightMode ? "#14040610" : "#1FFFFFFF"

                Row {
                    anchors.fill: parent
                    anchors.margins: DesktopTokens.px(10)
                    spacing: DesktopTokens.px(8)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(22)
                        height: DesktopTokens.px(22)
                        radius: DesktopTokens.px(11)
                        color: Theme.lightMode ? "#1F040610" : "#24FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: String(step.index + 1)
                            color: DesktopTokens.textHigh
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: DesktopTokens.tinySize
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - DesktopTokens.px(30)
                        spacing: 0

                        Text {
                            width: parent.width
                            text: step.modelData.label
                            color: DesktopTokens.textHigh
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: DesktopTokens.smallSize
                            font.weight: Font.ExtraBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: step.modelData.detail
                            color: DesktopTokens.textMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: DesktopTokens.tinySize
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("Step %1: %2. %3").arg(step.index + 1)
                    .arg(step.modelData.label).arg(step.modelData.detail)
            }
        }
    }

    // =========================================================================
    // 4b. Status grid
    // =========================================================================
    //
    // The four facts support always asks for, read straight off the store: is
    // an account attached, how many games came back, how many are hidden, and
    // how big the streamable catalog is. Showing them in every state turns this
    // page from a dead end into a diagnosis.
    Row {
        id: statusGrid
        anchors.horizontalCenter: plate.horizontalCenter
        y: stepRow.y + stepRow.height + DesktopTokens.px(16)
        spacing: DesktopTokens.px(10)

        Repeater {
            model: root.statusCells

            Rectangle {
                id: cell
                required property var modelData
                required property int index
                width: DesktopTokens.px(132)
                height: DesktopTokens.px(52)
                radius: DesktopTokens.px(13)
                color: Theme.lightMode ? "#10040610" : "#12FFFFFF"
                border.width: 1
                border.color: cell.modelData.tone === "bad" ? "#44FF6A6A"
                    : cell.modelData.tone === "warn" ? "#44F5B942"
                    : Theme.lightMode ? "#14040610" : "#1AFFFFFF"
                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("%1: %2").arg(cell.modelData.label).arg(cell.modelData.value)

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: DesktopTokens.px(12)
                    spacing: DesktopTokens.px(1)

                    Text {
                        text: cell.modelData.label
                        color: DesktopTokens.textFaint
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.tinySize
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                    Text {
                        text: cell.modelData.value
                        color: cell.modelData.tone === "bad" ? DesktopTokens.danger
                            : cell.modelData.tone === "warn" ? DesktopTokens.ledAmber
                            : DesktopTokens.textHigh
                        font.family: DesktopTokens.displayFont
                        font.pixelSize: DesktopTokens.px(15)
                        font.weight: Font.Black
                        elide: Text.ElideRight
                        width: DesktopTokens.px(110)
                        maximumLineCount: 1
                    }
                }
            }
        }
    }

    // =========================================================================
    // 5. Actions
    // =========================================================================
    Row {
        id: actionRow
        anchors.horizontalCenter: plate.horizontalCenter
        y: statusGrid.y + statusGrid.height + DesktopTokens.px(18)
        spacing: DesktopTokens.px(10)

        DesktopButton {
            objectName: "desktopHomeEmptyPrimary"
            visible: root.uiState === "signed-out"
            primary: true
            cornerRadius: 12
            height: DesktopTokens.px(38)
            glyph: "desktop-play-filled.svg"
            text: qsTr("Sign in")
            onClicked: root.signInRequested()
        }

        DesktopButton {
            objectName: "desktopHomeEmptyRetry"
            visible: root.uiState === "error"
            primary: true
            cornerRadius: 12
            height: DesktopTokens.px(38)
            glyph: "desktop-collapse.svg"
            text: root.retrySeconds > 0
                ? qsTr("Retry in %1s").arg(root.retrySeconds)
                : root.retryAttempts >= root.retryLimit ? qsTr("Try again")
                                                       : qsTr("Try again now")
            onClicked: root.requestRetry()
            Accessible.description: root.retryArmed
                ? qsTr("Retries automatically in %1 seconds").arg(root.retrySeconds)
                : qsTr("Retry loading the library")
        }

        DesktopButton {
            objectName: "desktopHomeEmptyUnhide"
            visible: root.uiState === "empty" && root.allHidden
            cornerRadius: 12
            height: DesktopTokens.px(38)
            glyph: "desktop-nav-library.svg"
            text: qsTr("Manage hidden games")
            onClicked: root.libraryRequested()
        }

        DesktopButton {
            objectName: "desktopHomeEmptyLibrary"
            visible: root.uiState !== "signed-out" && root.uiState !== "error"
            primary: true
            cornerRadius: 12
            height: DesktopTokens.px(38)
            glyph: "desktop-nav-library.svg"
            text: root.uiState === "syncing" ? qsTr("Open library") : qsTr("Sync in library")
            enabled: root.uiState !== "syncing"
            onClicked: root.libraryRequested()
        }

        DesktopButton {
            objectName: "desktopHomeEmptyStore"
            cornerRadius: 12
            height: DesktopTokens.px(38)
            glyph: "desktop-nav-store.svg"
            text: qsTr("Browse store")
            onClicked: root.storeRequested()
        }
    }

    // =========================================================================
    // 5b. Diagnostics
    // =========================================================================
    //
    // Support asks for three things every time: what state the page thinks it is
    // in, how many games the catalog returned, and the raw error text. Showing
    // them here — with a copy button — means a player can hand over all three
    // without opening a log file.
    Rectangle {
        id: diagnostics
        anchors.horizontalCenter: plate.horizontalCenter
        y: actionRow.y + actionRow.height + DesktopTokens.px(16)
        width: plate.width - DesktopTokens.px(48)
        height: DesktopTokens.px(52)
        // The plate measures from the tip line, so a hidden card must not
        // contribute any height.
        radius: DesktopTokens.px(14)
        visible: root.showDiagnostics
        opacity: visible ? 1 : 0
        color: Theme.lightMode ? "#14FF6A6A" : "#14FF6A6A"
        border.width: 1
        border.color: root.uiState === "error" ? "#44FF6A6A" : "#3356E6A5"
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 180 } }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: DesktopTokens.px(14)
            anchors.right: copyButton.left
            anchors.rightMargin: DesktopTokens.px(10)
            spacing: DesktopTokens.px(8)

            DesktopGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(16)
                height: DesktopTokens.px(16)
                icon: root.uiState === "error"
                    ? (root.looksOffline ? "settings-network.svg" : "desktop-info.svg")
                    : "desktop-nav-library.svg"
                opacity: 0.8
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - DesktopTokens.px(30)
                spacing: 0

                Text {
                    width: parent.width
                    text: root.uiState === "error"
                        ? (root.errorCode !== "" ? qsTr("Failure %1").arg(root.errorCode) : qsTr("Sync failed"))
                        : qsTr("%1 hidden games").arg(root.hiddenCount)
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    width: parent.width
                    text: root.uiState === "error"
                        ? (root.looksOffline
                            ? qsTr("Looks like a connection problem. OpenNOW retries on its own %1 more time(s).").arg(Math.max(0, root.retryLimit - root.retryAttempts))
                            : qsTr("The store did not return a usable catalog. OpenNOW retries on its own %1 more time(s).").arg(Math.max(0, root.retryLimit - root.retryAttempts)))
                        : qsTr("Unhide a game in the library to feature it here again.")
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.tinySize
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        Rectangle {
            id: copyButton
            objectName: "desktopHomeEmptyCopy"
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: DesktopTokens.px(12)
            width: copyLabel.implicitWidth + DesktopTokens.px(18)
            height: DesktopTokens.px(26)
            radius: DesktopTokens.px(13)
            color: copyHover.hovered || root.copiedFlash ? DesktopTokens.raisedStrong : DesktopTokens.raised
            border.width: 1
            border.color: root.copiedFlash ? "#6656E6A5" : DesktopTokens.seam
            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                id: copyLabel
                anchors.centerIn: parent
                text: root.copiedFlash ? qsTr("Copied") : qsTr("Copy details")
                color: root.copiedFlash ? DesktopTokens.mint : DesktopTokens.textHigh
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
                font.letterSpacing: 0.6
            }

            HoverHandler { id: copyHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.copyDiagnostics() }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Copy diagnostics to the clipboard")
            Accessible.onPressAction: root.copyDiagnostics()
        }
    }

    // =========================================================================
    // 6. Rotating tip
    // =========================================================================
    Text {
        id: tipLine
        anchors.horizontalCenter: plate.horizontalCenter
        y: (root.showDiagnostics ? diagnostics.y + diagnostics.height
                                 : actionRow.y + actionRow.height) + DesktopTokens.px(18)
        width: plate.width - DesktopTokens.px(64)
        horizontalAlignment: Text.AlignHCenter
        text: root.tips[root.tipIndex]
        color: DesktopTokens.textFaint
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.tinySize
        font.letterSpacing: 0.4
        elide: Text.ElideRight
        maximumLineCount: 1
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
}
