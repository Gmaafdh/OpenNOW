pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import OpenNOW

// =============================================================================
// DesktopHomeShowcase — the PS5-style hero stage on Home.
// =============================================================================
//
// The backdrop paints the featured game's art across the whole page; this
// component is the editorial layer on top of it. It owns the slide index and
// the auto-cycle, so the dock, the backdrop and the hero always agree on which
// game is featured.
//
// Sections:
//   1. stage plate      — soft glass that keeps text readable over bright art
//   2. eyebrow row      — spotlight pill, genre tag, favourite/lock badges
//   3. title block      — oversized title with a choreographed slide-in
//   4. byline           — publisher, genre, membership tier
//   5. meta chips       — last played, hours, stream quality, video features
//   6. synopsis         — two-line description
//   7. actions          — Play / Details / Library / Pin with focus rings
//   8. timeline         — slide segments with live auto-cycle progress
//   9. HUD              — AUTO/HOLD indicator, slide counter, prev/next
//  10. up next          — the following game as a compact resume card
//  11. library stats    — totals for the signed-in player
//  12. signed-out veil  — explains the empty stage and offers sign-in
// =============================================================================
Item {
    id: root
    objectName: "desktopHomeShowcase"

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    property var games: []
    property var recentGames: []
    property int totalGames: 0
    property int favoriteCount: 0
    property real totalHours: 0
    property bool active: true
    property bool signedIn: true
    property int selectedAction: -1
    property string streamLabel: ""
    property string metaLine: ""
    property double lastPlayedNowMs: Date.now()

    /// Slide state. `transition` runs 0→1 on every slide change and drives the
    /// choreographed entrance of the title block.
    property int currentIndex: 0
    property int previousIndex: 0
    property real transition: 1
    property real slideProgress: 0

    signal playRequested(var game)
    signal detailsRequested(var game)
    signal libraryRequested()
    signal signInRequested()
    signal favoriteToggled(var game)
    signal actionPointed(int index)
    signal slidePointed(int index)

    // -------------------------------------------------------------------------
    // Derived state
    // -------------------------------------------------------------------------
    readonly property int slideCount: games ? games.length : 0
    readonly property bool motionOff: AppController.reducedMotion
    readonly property bool compact: height < DesktopTokens.px(360)
    readonly property bool narrow: width < DesktopTokens.px(820)
    readonly property var currentGame: slideCount > 0
        ? games[Math.max(0, Math.min(currentIndex, slideCount - 1))] : null
    readonly property var nextGame: slideCount > 1
        ? games[(currentIndex + 1) % slideCount] : null
    readonly property bool autoCycleActive: visible && active && slideCount > 1
        && !motionOff && !heroHover.hovered && !root.compact

    readonly property string currentTitle: currentGame
        ? String(currentGame.title || qsTr("Game")) : qsTr("Your library")
    readonly property string currentPublisher: {
        if (!currentGame)
            return qsTr("Ready to stream")
        const publisher = currentGame.publisherName || currentGame.publisher
        return publisher ? String(publisher) : qsTr("Ready to stream")
    }
    readonly property string currentDeveloper: currentGame && currentGame.developerName
        ? String(currentGame.developerName) : ""
    readonly property string currentGenre: {
        if (!currentGame || !currentGame.genres || !currentGame.genres.length)
            return ""
        return DesktopTokens.genreLabel(String(currentGame.genres[0]))
    }
    readonly property string currentDescription: currentGame
        ? String(currentGame.description || "") : ""
    readonly property string currentTier: currentGame && currentGame.membershipTierLabel
        ? String(currentGame.membershipTierLabel) : ""
    readonly property var currentFeatures: DesktopTokens.gameFeatures(currentGame)
    readonly property bool currentFavorite: currentGame ? ShellStore.isFavorite(currentGame) : false
    readonly property bool currentLocked: currentGame ? ShellStore.gameLockedByMembership(currentGame) : false
    readonly property real currentHours: {
        if (!currentGame)
            return 0
        const hours = Number(currentGame.hoursPlayed || 0)
        return isFinite(hours) && hours > 0 ? hours : 0
    }
    readonly property string eyebrow: slideCount > 1
        ? qsTr("YOUR LIBRARY / IN THE SPOTLIGHT")
        : qsTr("YOUR LIBRARY / READY TO PLAY")
    /// The screen formats "last played · hours" as one string; splitting it
    /// here keeps each fact in its own chip without duplicating the formatter.
    readonly property var metaParts: metaLine === "" ? [] : metaLine.split(" · ")
    readonly property var actionModel: [
        { id: "play", label: qsTr("Play"), icon: "desktop-play-filled.svg", primary: true },
        { id: "details", label: qsTr("Details"), icon: "desktop-info.svg", primary: false },
        { id: "library", label: qsTr("Library"), icon: "desktop-nav-library.svg", primary: false },
        { id: "pin", label: currentFavorite ? qsTr("Unpin") : qsTr("Pin"),
          icon: "desktop-star.svg", primary: false }
    ]

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Featured game")
    Accessible.description: currentGame
        ? [currentTitle, currentPublisher, metaLine].filter(part => part !== "").join(". ")
        : qsTr("No featured game")

    // -------------------------------------------------------------------------
    // Slide control
    // -------------------------------------------------------------------------
    function showSlide(index) {
        if (slideCount < 1)
            return
        const next = Math.max(0, Math.min(index, slideCount - 1))
        slideProgress = 0
        if (next === currentIndex && transition >= 1)
            return
        transitionAnimation.stop()
        previousIndex = currentIndex
        currentIndex = next
        if (motionOff) {
            transition = 1
        } else {
            transition = 0
            transitionAnimation.start()
        }
    }

    function nextSlide() {
        if (slideCount > 1)
            showSlide((currentIndex + 1) % slideCount)
    }

    function previousSlide() {
        if (slideCount > 1)
            showSlide((currentIndex - 1 + slideCount) % slideCount)
    }

    function activateAction(index) {
        const action = actionModel[index]
        if (!action)
            return
        const id = String(action.id)
        if (id === "play")
            root.playRequested(root.currentGame)
        else if (id === "details")
            root.detailsRequested(root.currentGame)
        else if (id === "library")
            root.libraryRequested()
        else if (id === "pin")
            root.favoriteToggled(root.currentGame)
    }

    onGamesChanged: {
        transitionAnimation.stop()
        previousIndex = 0
        currentIndex = 0
        transition = 1
        slideProgress = 0
    }

    clip: true

    NumberAnimation {
        id: transitionAnimation
        target: root
        property: "transition"
        from: 0
        to: 1
        duration: Theme.duration(480)
        easing.type: Easing.OutQuart
    }

    // Auto-cycle ticker. The interval matches the segment fill so the progress
    // bar and the slide change are always in sync.
    Timer {
        id: progressTicker
        interval: 50
        repeat: true
        running: root.autoCycleActive
        onTriggered: {
            const step = interval / 6200
            if (root.slideProgress + step >= 1) {
                root.slideProgress = 0
                root.nextSlide()
            } else {
                root.slideProgress += step
            }
        }
    }

    HoverHandler {
        id: heroHover
        cursorShape: Qt.ArrowCursor
    }

    // =========================================================================
    // Inline components
    // =========================================================================
    component HeroAction: Button {
        id: actionButton
        property bool primary: false
        property int actionIndex: -1
        property int selectedAction: -1
        property string actionIcon: ""
        readonly property bool navigationFocus: actionIndex >= 0 && actionIndex === selectedAction

        signal actionPointed(int index)
        signal actionActivated(int index)

        height: DesktopTokens.px(root.compact ? 40 : 46)
        padding: 0
        leftPadding: DesktopTokens.px(18)
        rightPadding: DesktopTokens.px(20)
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        font.family: DesktopTokens.bodyFont
        font.pixelSize: DesktopTokens.captionSize
        font.weight: Font.Black
        onHoveredChanged: if (hovered && actionIndex >= 0) actionButton.actionPointed(actionIndex)
        onClicked: actionButton.actionActivated(actionIndex)
        opacity: enabled ? 1 : 0.45
        scale: root.motionOff ? 1 : actionButton.down ? 0.965 : actionButton.hovered ? 1.02 : 1
        transformOrigin: Item.Center
        Behavior on scale {
            NumberAnimation { duration: Theme.duration(110); easing.type: Easing.OutCubic }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        Accessible.role: Accessible.Button
        Accessible.name: actionButton.text

        background: Item {
            // Elevation shadow.
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: DesktopTokens.px(5)
                anchors.leftMargin: DesktopTokens.px(2)
                anchors.rightMargin: DesktopTokens.px(2)
                radius: DesktopTokens.px(14)
                color: actionButton.primary
                    ? (actionButton.hovered ? "#584BD49D" : "#344BD49D")
                    : "#55000000"
                Behavior on color { ColorAnimation { duration: Theme.duration(140) } }
            }

            // Keyboard / controller focus ring.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -DesktopTokens.px(3)
                visible: actionButton.activeFocus || actionButton.navigationFocus
                radius: DesktopTokens.px(17)
                color: "transparent"
                border.width: 2
                border.color: DesktopTokens.focus
            }

            // Button surface.
            Rectangle {
                anchors.fill: parent
                radius: DesktopTokens.px(14)
                border.width: 1
                border.color: actionButton.activeFocus || actionButton.navigationFocus ? "#FFFFFF"
                    : actionButton.primary ? (actionButton.hovered ? "#E6FFFFFF" : "#A8FFFFFF")
                    : (actionButton.hovered ? "#78FFFFFF" : "#38FFFFFF")
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: actionButton.primary
                            ? (actionButton.down ? "#5CD6A3" : actionButton.hovered ? "#AEF9D8" : "#8FF5C8")
                            : (actionButton.down ? "#1E293B" : actionButton.hovered ? "#384B66" : "#263348")
                    }
                    GradientStop {
                        position: 1.0
                        color: actionButton.primary
                            ? (actionButton.down ? "#34B07F" : actionButton.hovered ? "#5BE0A8" : "#44CE96")
                            : (actionButton.down ? "#0F1521" : actionButton.hovered ? "#1D283A" : "#E8111826")
                    }
                }
                Behavior on border.color { ColorAnimation { duration: Theme.duration(120) } }

                // Top specular rim.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: parent.height * 0.45
                    radius: DesktopTokens.px(13)
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: actionButton.primary ? "#45FFFFFF" : "#1EFFFFFF"
                        }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }

        contentItem: Item {
            implicitWidth: actionRow.implicitWidth
            implicitHeight: actionRow.implicitHeight

            Row {
                id: actionRow
                anchors.centerIn: parent
                spacing: DesktopTokens.px(9)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: actionButton.actionIcon !== ""
                    width: DesktopTokens.px(26)
                    height: DesktopTokens.px(26)
                    radius: DesktopTokens.px(8)
                    color: actionButton.primary ? "#22051812" : "#22FFFFFF"
                    border.width: 1
                    border.color: actionButton.primary ? "#1F051812" : "#24FFFFFF"

                    DesktopGlyph {
                        anchors.centerIn: parent
                        width: DesktopTokens.px(14)
                        height: DesktopTokens.px(14)
                        icon: actionButton.actionIcon
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: actionButton.text
                    color: actionButton.primary ? "#051914" : "#F8FAFC"
                    font: actionButton.font
                }
            }
        }
    }

    component MetaChip: Rectangle {
        id: chip
        property string chipText: ""
        property string chipIcon: ""
        property string chipImageUrl: ""
        property bool chipAccent: false

        width: chipRow.implicitWidth + DesktopTokens.px(18)
        height: DesktopTokens.px(26)
        radius: DesktopTokens.px(13)
        color: chipAccent ? "#264BD49D" : "#B80A0E18"
        border.width: 1
        border.color: chipAccent ? "#554BD49D" : "#2EFFFFFF"

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: DesktopTokens.px(6)

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.chipImageUrl !== ""
                width: DesktopTokens.px(13)
                height: DesktopTokens.px(13)
                source: chip.chipImageUrl
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
            }
            DesktopGlyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.chipIcon !== "" && chip.chipImageUrl === ""
                width: DesktopTokens.px(12)
                height: DesktopTokens.px(12)
                icon: chip.chipIcon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.chipText
                color: chip.chipAccent ? DesktopTokens.flightMint : Theme.mediaForeground
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.Bold
            }
        }

        Accessible.role: Accessible.StaticText
        Accessible.name: chip.chipText
    }

    component StageChevron: Rectangle {
        id: chevron
        property bool chevronRight: true
        signal chevronClicked()

        width: DesktopTokens.px(38)
        height: DesktopTokens.px(38)
        radius: DesktopTokens.px(19)
        color: chevronHover.hovered ? "#2EFFFFFF" : "#1A0A0E18"
        border.width: 1
        border.color: chevronTap.pressed ? "#FFFFFF" : "#3DFFFFFF"
        scale: chevronTap.pressed ? 0.94 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: chevron.chevronRight ? "›" : "‹"
            color: Theme.mediaForeground
            font.family: DesktopTokens.displayFont
            font.pixelSize: DesktopTokens.px(22)
            font.weight: Font.Black
        }

        HoverHandler { id: chevronHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: chevronTap
            onTapped: chevron.chevronClicked()
        }
        Accessible.role: Accessible.Button
        Accessible.name: chevron.chevronRight ? qsTr("Next featured game")
                                              : qsTr("Previous featured game")
        Accessible.onPressAction: chevron.chevronClicked()
    }

    component StatBlock: Rectangle {
        id: stat
        property string statValue: ""
        property string statLabel: ""

        width: DesktopTokens.px(104)
        height: DesktopTokens.px(52)
        radius: DesktopTokens.px(14)
        color: "#A80A0E18"
        border.width: 1
        border.color: "#2EFFFFFF"

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: stat.statValue
                color: Theme.mediaForeground
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.px(17)
                font.weight: Font.Black
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: stat.statLabel
                color: Theme.mediaMuted
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }

        Accessible.role: Accessible.StaticText
        Accessible.name: stat.statValue + " " + stat.statLabel
    }

    // =========================================================================
    // 1. Stage plate
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        radius: DesktopTokens.px(22)
        color: "#2E060911"
        border.width: 1
        border.color: "#1FFFFFFF"
        opacity: Theme.lightMode ? 0.55 : 0.85

        // Inner top highlight so the plate reads as glass.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: parent.height * 0.4
            radius: DesktopTokens.px(21)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#14FFFFFF" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // =========================================================================
    // 2-7. Editorial column
    // =========================================================================
    Column {
        id: editorial
        objectName: "desktopShowcaseEditorial"
        x: DesktopTokens.px(root.compact ? 22 : 32)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -DesktopTokens.px(root.compact ? 6 : 12)
        width: Math.min(parent.width * (root.narrow ? 0.72 : 0.56), DesktopTokens.px(620))
        spacing: DesktopTokens.px(root.compact ? 7 : 12)

        // Choreographed entrance tied to the slide transition.
        opacity: root.motionOff ? 1 : (0.35 + 0.65 * root.transition)
        transform: Translate {
            y: root.motionOff ? 0 : DesktopTokens.px(10) * (1 - root.transition)
        }

        // -- 2. Eyebrow row ---------------------------------------------------
        Row {
            width: parent.width
            spacing: DesktopTokens.px(9)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: DesktopTokens.px(24)
                width: spotlightRow.implicitWidth + DesktopTokens.px(20)
                radius: DesktopTokens.px(12)
                color: "#1F4BD49D"
                border.width: 1
                border.color: "#554BD49D"

                Row {
                    id: spotlightRow
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(6)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(6)
                        height: DesktopTokens.px(6)
                        radius: DesktopTokens.px(3)
                        color: DesktopTokens.mint

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.autoCycleActive
                            NumberAnimation { from: 1; to: 0.4; duration: 900 }
                            NumberAnimation { from: 0.4; to: 1; duration: 900 }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.eyebrow
                        color: DesktopTokens.mint
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.currentGenre !== ""
                height: DesktopTokens.px(24)
                width: genreTag.implicitWidth + DesktopTokens.px(18)
                radius: DesktopTokens.px(12)
                color: "#1FFFFFFF"
                border.width: 1
                border.color: "#2EFFFFFF"

                Text {
                    id: genreTag
                    anchors.centerIn: parent
                    text: root.currentGenre.toUpperCase()
                    color: "#D8FFFFFF"
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.currentFavorite
                height: DesktopTokens.px(24)
                width: favoriteTag.implicitWidth + DesktopTokens.px(24)
                radius: DesktopTokens.px(12)
                color: "#26F5A623"
                border.width: 1
                border.color: "#59F5A623"

                Row {
                    id: favoriteTag
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(5)
                    DesktopGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(11)
                        height: DesktopTokens.px(11)
                        icon: "desktop-star.svg"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("PINNED")
                        color: "#FFE0A8"
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.currentLocked
                height: DesktopTokens.px(24)
                width: lockTag.implicitWidth + DesktopTokens.px(24)
                radius: DesktopTokens.px(12)
                color: "#26FF8A80"
                border.width: 1
                border.color: "#59FF8A80"

                Row {
                    id: lockTag
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(5)
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(11)
                        height: DesktopTokens.px(11)
                        source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-lock.svg"
                        sourceSize: Qt.size(32, 32)
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("PAID MEMBERSHIP")
                        color: "#FFC9C4"
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                    }
                }
            }
        }

        // -- 3. Title ---------------------------------------------------------
        Item {
            width: parent.width
            height: heroTitle.implicitHeight

            // Drop-shadow copy guarantees contrast over bright key art.
            Text {
                width: parent.width
                y: DesktopTokens.px(2)
                text: heroTitle.text
                color: "#99000000"
                font: heroTitle.font
                wrapMode: heroTitle.wrapMode
                maximumLineCount: heroTitle.maximumLineCount
                elide: heroTitle.elide
                lineHeight: heroTitle.lineHeight
            }

            Text {
                id: heroTitle
                objectName: "desktopShowcaseTitle"
                width: parent.width
                text: root.currentTitle
                color: "#FFFFFF"
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.px(root.compact ? 30 : root.narrow ? 34 : 44)
                font.weight: Font.Black
                font.letterSpacing: -1.2
                lineHeight: 0.96
                wrapMode: Text.WordWrap
                maximumLineCount: root.compact ? 1 : 2
                elide: Text.ElideRight
            }
        }

        // -- 4. Byline --------------------------------------------------------
        Row {
            width: parent.width
            spacing: DesktopTokens.px(8)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(16)
                height: DesktopTokens.px(2)
                radius: 1
                color: DesktopTokens.mint
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - DesktopTokens.px(30))
                text: root.currentDeveloper !== ""
                    ? root.currentPublisher + "  ·  " + root.currentDeveloper
                    : root.currentPublisher
                color: "#E4FFFFFF"
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // -- 5. Meta chips ----------------------------------------------------
        Flow {
            width: parent.width
            spacing: DesktopTokens.px(6)
            visible: root.metaLine !== "" || root.currentFeatures.length > 0
                || root.currentTier !== ""

            Repeater {
                model: root.metaParts
                MetaChip {
                    required property string modelData
                    chipText: modelData
                    chipIcon: "desktop-clock.svg"
                }
            }

            MetaChip {
                visible: root.currentHours > 0
                chipText: qsTr("%1 h played").arg(Math.round(root.currentHours))
                chipIcon: "desktop-clock.svg"
            }

            MetaChip {
                visible: root.streamLabel !== ""
                chipText: root.streamLabel
                chipIcon: "desktop-play-stroke.svg"
                chipAccent: true
            }

            MetaChip {
                visible: root.currentTier !== ""
                chipText: root.currentTier.toUpperCase()
            }

            Repeater {
                model: root.currentFeatures
                MetaChip {
                    required property int index
                    chipText: DesktopTokens.featureLabel(root.currentFeatures[index])
                    chipImageUrl: DesktopTokens.featureIconUrl(root.currentFeatures[index])
                }
            }
        }

        // -- 6. Synopsis ------------------------------------------------------
        Text {
            visible: root.currentDescription !== "" && !root.compact
            width: parent.width
            text: root.currentDescription
            color: "#C8D2E2"
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
            font.weight: Font.DemiBold
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // -- 7. Actions -------------------------------------------------------
        Flow {
            width: parent.width
            spacing: DesktopTokens.px(10)

            Repeater {
                model: root.actionModel
                HeroAction {
                    id: heroActionButton
                    required property var modelData
                    required property int index
                    objectName: index === 0 ? "desktopHeroPlay"
                        : index === 1 ? "desktopHeroDetails"
                        : index === 2 ? "desktopHeroLibrary" : "desktopHeroPin"
                    text: modelData.label
                    primary: modelData.primary === true
                    actionIcon: modelData.icon
                    actionIndex: index
                    selectedAction: root.selectedAction
                    enabled: root.currentGame !== null || index === 2
                    onActionPointed: index => root.actionPointed(index)
                    onActionActivated: index => root.activateAction(index)
                }
            }
        }
    }

    // =========================================================================
    // 8. Timeline segments
    // =========================================================================
    Row {
        id: timeline
        x: editorial.x
        anchors.bottom: parent.bottom
        anchors.bottomMargin: DesktopTokens.px(root.compact ? 14 : 20)
        spacing: DesktopTokens.px(6)
        visible: root.slideCount > 1

        Repeater {
            model: Math.min(root.slideCount, 8)
            Rectangle {
                id: segment
                required property int index
                readonly property bool isCurrent: index === root.currentIndex
                width: DesktopTokens.px(segmentHover.hovered ? 34 : 28)
                height: DesktopTokens.px(4)
                radius: DesktopTokens.px(2)
                color: "#33FFFFFF"
                Behavior on width {
                    NumberAnimation { duration: root.motionOff ? 0 : 160; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    width: parent.width * (segment.isCurrent
                        ? Math.max(0.12, root.slideProgress)
                        : (segment.index < root.currentIndex ? 1 : 0))
                    height: parent.height
                    radius: DesktopTokens.px(2)
                    color: segment.isCurrent ? DesktopTokens.mint : "#FFFFFF"
                }

                HoverHandler {
                    id: segmentHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.slidePointed(segment.index)
                }
                TapHandler { onTapped: root.showSlide(segment.index) }
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Featured game %1 of %2").arg(segment.index + 1).arg(root.slideCount)
                Accessible.onPressAction: root.showSlide(segment.index)
            }
        }
    }

    // =========================================================================
    // 9. HUD (auto-cycle status + stepper)
    // =========================================================================
    Rectangle {
        id: hud
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: DesktopTokens.px(18)
        anchors.rightMargin: DesktopTokens.px(22)
        visible: root.slideCount > 1
        height: DesktopTokens.px(32)
        width: hudRow.implicitWidth + DesktopTokens.px(16)
        radius: DesktopTokens.px(16)
        color: "#A8080D17"
        border.width: 1
        border.color: "#2EFFFFFF"

        Row {
            id: hudRow
            anchors.centerIn: parent
            spacing: DesktopTokens.px(8)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(6)
                height: DesktopTokens.px(6)
                radius: DesktopTokens.px(3)
                color: heroHover.hovered ? "#FBBF24" : DesktopTokens.mint
                Behavior on color { ColorAnimation { duration: Theme.duration(160) } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (heroHover.hovered ? qsTr("HOLD") : qsTr("AUTO"))
                    + "  ·  "
                    + String(root.currentIndex + 1).padStart(2, "0")
                    + " / "
                    + String(root.slideCount).padStart(2, "0")
                color: "#D8FFFFFF"
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.Bold
                font.letterSpacing: 0.9
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: DesktopTokens.px(14)
                color: "#28FFFFFF"
            }

            StageChevron {
                anchors.verticalCenter: parent.verticalCenter
                chevronRight: false
                width: DesktopTokens.px(22)
                height: DesktopTokens.px(22)
                radius: DesktopTokens.px(11)
                onChevronClicked: root.previousSlide()
            }

            StageChevron {
                anchors.verticalCenter: parent.verticalCenter
                chevronRight: true
                width: DesktopTokens.px(22)
                height: DesktopTokens.px(22)
                radius: DesktopTokens.px(11)
                onChevronClicked: root.nextSlide()
            }
        }
    }

    // =========================================================================
    // 10. Up next card
    // =========================================================================
    Rectangle {
        id: nextCard
        objectName: "desktopShowcaseUpNext"
        anchors.right: parent.right
        anchors.rightMargin: DesktopTokens.px(22)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: DesktopTokens.px(18)
        width: DesktopTokens.px(root.narrow ? 210 : 252)
        height: DesktopTokens.px(72)
        radius: DesktopTokens.px(16)
        color: nextHover.hovered ? "#CC101A2C" : "#B80A0E18"
        border.width: 1
        border.color: nextHover.hovered ? "#59FFFFFF" : "#2EFFFFFF"
        visible: root.nextGame !== null && !root.compact
        scale: nextTap.pressed ? 0.98 : 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        RoundedArtwork {
            id: nextArt
            x: DesktopTokens.px(8)
            y: DesktopTokens.px(8)
            width: DesktopTokens.px(56)
            height: parent.height - DesktopTokens.px(16)
            artwork: DesktopTokens.artworkUrl(root.nextGame, false)
            fallbackArtwork: DesktopTokens.artworkUrl(root.nextGame, true)
            cornerRadius: DesktopTokens.px(11)
            scrimStart: 1
            fallbackColor: "#1A2232"
        }

        Column {
            x: nextArt.x + nextArt.width + DesktopTokens.px(10)
            y: DesktopTokens.px(12)
            width: parent.width - x - DesktopTokens.px(12)
            spacing: DesktopTokens.px(1)

            Text {
                text: qsTr("UP NEXT")
                color: DesktopTokens.mint
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
            Text {
                width: parent.width
                text: root.nextGame ? String(root.nextGame.title || qsTr("Game")) : ""
                color: Theme.mediaForeground
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                text: root.nextGame && (root.nextGame.publisherName || root.nextGame.publisher)
                    ? String(root.nextGame.publisherName || root.nextGame.publisher)
                    : qsTr("Ready to stream")
                color: Theme.mediaMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.tinySize
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: nextTap
            onTapped: root.detailsRequested(root.nextGame)
        }
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Up next: %1").arg(root.nextGame ? String(root.nextGame.title || "") : "")
        Accessible.onPressAction: root.detailsRequested(root.nextGame)
    }

    // =========================================================================
    // 11. Library stats
    // =========================================================================
    Column {
        id: statsColumn
        anchors.right: parent.right
        anchors.rightMargin: DesktopTokens.px(22)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesktopTokens.px(8)
        visible: !root.narrow && root.signedIn && root.totalGames > 0

        StatBlock {
            statValue: String(root.totalGames)
            statLabel: qsTr("GAMES")
        }
        StatBlock {
            statValue: String(root.favoriteCount)
            statLabel: qsTr("PINNED")
        }
        StatBlock {
            visible: root.totalHours >= 1
            statValue: String(Math.round(root.totalHours)) + "h"
            statLabel: qsTr("PLAYED")
        }
    }

    // =========================================================================
    // 12. Signed-out veil
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        radius: DesktopTokens.px(22)
        color: "#D90A0E18"
        visible: !root.signedIn

        Column {
            anchors.centerIn: parent
            width: parent.width - DesktopTokens.px(80)
            spacing: DesktopTokens.px(10)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Your spotlight is waiting")
                color: "#FFFFFF"
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.px(24)
                font.weight: Font.Black
                font.letterSpacing: -0.5
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Sign in with your GeForce NOW account to fill this stage with the games you own, the sessions you left open and the titles you pinned.")
                color: "#C8D2E2"
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            }
            DesktopButton {
                anchors.horizontalCenter: parent.horizontalCenter
                primary: true
                cornerRadius: 12
                glyph: "desktop-play-filled.svg"
                text: qsTr("Sign in")
                onClicked: root.signInRequested()
            }
        }
    }
}
