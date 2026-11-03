import QtQuick
import QtQuick.Controls
import OpenNOW

// A cinematic, data-driven library showcase banner. Combines edge-lit obsidian
// glass, choreographed typography transitions, live timeline progress, and
// non-cropping parallax key art.
Item {
    id: root

    property var games: []
    property bool active: true
    property int selectedAction: -1
    property int currentIndex: 0
    property int previousIndex: 0
    property real transition: 1
    property real slideProgress: 0

    readonly property int slideCount: games ? games.length : 0
    readonly property var currentGame: slideCount > 0
        ? games[Math.max(0, Math.min(currentIndex, slideCount - 1))] : null
    readonly property var nextGame: slideCount > 1
        ? games[( currentIndex + 1 ) % slideCount] : null
    readonly property bool autoCycleActive: root.visible && root.active && root.slideCount > 1
        && !AppController.reducedMotion && !heroHover.hovered
    readonly property bool compactHeight: height < DesktopTokens.px(280)
    readonly property bool singleLineTitle: height <= DesktopTokens.px(280)

    signal playRequested(var game)
    signal detailsRequested(var game)
    signal actionPointed(int index)

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
        if (AppController.reducedMotion) {
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

    onGamesChanged: {
        transitionAnimation.stop()
        previousIndex = 0
        currentIndex = 0
        transition = 1
        slideProgress = 0
    }

    clip: true

    // -------------------------------------------------------------------------
    // 1. AMBIENT DROP SHADOW & BASE CHASSIS
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: DesktopTokens.px(24)
        color: "#060911"
    }

    // -------------------------------------------------------------------------
    // 2. PARALLAX ARTWORK STAGE & CINEMATIC LIGHTING SCRIMS
    // -------------------------------------------------------------------------
    Item {
        id: stage
        anchors.fill: parent
        clip: true

        Repeater {
            model: root.games
            delegate: Item {
                id: slide
                required property var modelData
                required property int index
                anchors.fill: parent
                visible: opacity > 0.001
                opacity: index === root.currentIndex ? root.transition
                    : index === root.previousIndex ? (1 - root.transition) : 0

                // Horizontal parallax drift without vertical scale-cropping
                transform: Translate {
                    x: index === root.currentIndex
                        ? DesktopTokens.px(18) * (1 - root.transition)
                        : -DesktopTokens.px(14) * root.transition
                }

                RoundedArtwork {
                    anchors.fill: parent
                    artwork: DesktopTokens.artworkUrl(slide.modelData, true)
                    fallbackArtwork: DesktopTokens.artworkUrl(slide.modelData, false)
                    cinematicFit: true
                    alignArtworkRight: true
                    cornerRadius: DesktopTokens.px(24)
                    scrimStart: 1
                    fallbackColor: "#0D1524"
                }
            }
        }

        // Primary horizontal editorial reading scrim (deep obsidian on left, crystal clear on right)
        Rectangle {
            anchors.fill: parent
            radius: DesktopTokens.px(24)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "#F8060911" }
                GradientStop { position: 0.34; color: "#E2070B14" }
                GradientStop { position: 0.58; color: "#88080D18" }
                GradientStop { position: 0.78; color: "#1F080D18" }
                GradientStop { position: 1.00; color: "transparent" }
            }
        }

        // Bottom dock & vignette scrim
        Rectangle {
            anchors.fill: parent
            radius: DesktopTokens.px(24)
            gradient: Gradient {
                GradientStop { position: 0.00; color: "#38060911" }
                GradientStop { position: 0.22; color: "transparent" }
                GradientStop { position: 0.58; color: "transparent" }
                GradientStop { position: 1.00; color: "#DE060911" }
            }
        }

        // Subtle studio mint ambient backlight in lower-left corner
        Rectangle {
            width: parent.width * 0.48
            height: parent.height * 0.9
            x: -width * 0.25
            y: parent.height * 0.25
            radius: width * 0.5
            opacity: 0.11
            gradient: Gradient {
                GradientStop { position: 0.0; color: DesktopTokens.mint }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // -------------------------------------------------------------------------
    // 3. TIMELINE & TRANSITION CHOREOGRAPHY
    // -------------------------------------------------------------------------
    NumberAnimation {
        id: transitionAnimation
        target: root
        property: "transition"
        from: 0
        to: 1
        duration: Theme.duration(560)
        easing.type: Easing.OutQuart
    }

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

    // -------------------------------------------------------------------------
    // 4. REDESIGNED TACTILE HERO ACTION BUTTONS
    // -------------------------------------------------------------------------
    component HeroAction: Button {
        id: action
        property bool primary: false
        property bool navigationFocus: false
        property int actionIndex: -1
        property string glyph: ""

        height: DesktopTokens.px(root.compactHeight ? 38 : 46)
        padding: 0
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        onHoveredChanged: if (hovered && actionIndex >= 0) root.actionPointed(actionIndex)
        opacity: enabled ? 1 : 0.45
        scale: AppController.reducedMotion ? 1 : down ? 0.965 : hovered ? 1.02 : 1
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation { duration: Theme.duration(110); easing.type: Easing.OutCubic }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Item {
            // Ambient under-glow / elevation shadow
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: DesktopTokens.px(5)
                anchors.leftMargin: DesktopTokens.px(2)
                anchors.rightMargin: DesktopTokens.px(2)
                radius: DesktopTokens.px(14)
                color: action.primary
                    ? (action.hovered ? "#584BD49D" : "#344BD49D")
                    : "#55000000"
                Behavior on color { ColorAnimation { duration: Theme.duration(140) } }
            }

            // Keyboard / Gamepad focus ring
            Rectangle {
                anchors.fill: parent
                anchors.margins: -DesktopTokens.px(3)
                visible: action.activeFocus || action.navigationFocus
                radius: DesktopTokens.px(17)
                color: "transparent"
                border.width: 2
                border.color: DesktopTokens.focus
            }

            // Main button surface
            Rectangle {
                anchors.fill: parent
                radius: DesktopTokens.px(14)
                border.width: 1
                border.color: action.activeFocus || action.navigationFocus ? "#FFFFFF"
                    : action.primary ? (action.hovered ? "#E6FFFFFF" : "#A8FFFFFF")
                    : (action.hovered ? "#78FFFFFF" : "#38FFFFFF")

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: action.primary
                            ? (action.down ? "#5CD6A3" : action.hovered ? "#AEF9D8" : "#8FF5C8")
                            : (action.down ? "#1E293B" : action.hovered ? "#384B66" : "#263348")
                    }
                    GradientStop {
                        position: 1.0
                        color: action.primary
                            ? (action.down ? "#34B07F" : action.hovered ? "#5BE0A8" : "#44CE96")
                            : (action.down ? "#0F1521" : action.hovered ? "#1D283A" : "#E8111826")
                    }
                }
                Behavior on border.color { ColorAnimation { duration: Theme.duration(120) } }

                // Top specular rim highlight
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
                            color: action.primary ? "#45FFFFFF" : "#1EFFFFFF"
                        }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }

        contentItem: Item {
            Row {
                anchors.centerIn: parent
                spacing: DesktopTokens.px(10)

                // Recessed icon badge for visual structure
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(26)
                    height: DesktopTokens.px(26)
                    radius: DesktopTokens.px(8)
                    visible: action.glyph !== ""
                    color: action.primary ? "#22051812" : "#22FFFFFF"
                    border.width: 1
                    border.color: action.primary ? "#1F051812" : "#24FFFFFF"

                    DesktopGlyph {
                        anchors.centerIn: parent
                        width: DesktopTokens.px(14)
                        height: width
                        icon: action.glyph
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: action.text
                    color: action.primary ? "#051914" : "#F8FAFC"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    font.weight: Font.Black
                    font.letterSpacing: 0.2
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // 5. TOP-RIGHT HUD TELEMETRY & QUICK STEPPER
    // -------------------------------------------------------------------------
    Rectangle {
        id: telemetryHud
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

            // Live status indicator dot
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(6)
                height: DesktopTokens.px(6)
                radius: width * 0.5
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

            // Previous slide micro-button
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Previous featured game")
                Accessible.onPressAction: root.previousSlide()
                width: DesktopTokens.px(20)
                height: DesktopTokens.px(20)
                radius: DesktopTokens.px(10)
                color: prevHover.hovered ? "#2EFFFFFF" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: "#FFFFFF"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.px(15)
                    font.weight: Font.Bold
                }
                HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.previousSlide() }
            }

            // Next slide micro-button
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Next featured game")
                Accessible.onPressAction: root.nextSlide()
                width: DesktopTokens.px(20)
                height: DesktopTokens.px(20)
                radius: DesktopTokens.px(10)
                color: nextHover.hovered ? "#2EFFFFFF" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: "#FFFFFF"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.px(15)
                    font.weight: Font.Bold
                }
                HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.nextSlide() }
            }
        }
    }

    // -------------------------------------------------------------------------
    // 6. EDITORIAL SPOTLIGHT CONTENT (LEFT STAGE)
    // -------------------------------------------------------------------------
    Column {
        id: editorialColumn
        objectName: "desktopHeroEditorial"
        x: DesktopTokens.px(32)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.slideCount > 1
            ? -DesktopTokens.px(root.compactHeight ? 22 : 10) : 0
        width: Math.min(parent.width * 0.58, DesktopTokens.px(620))
        spacing: DesktopTokens.px(root.compactHeight ? 6 : 12)

        // Subtle choreographed entrance tied to slide transition
        opacity: AppController.reducedMotion ? 1 : (0.35 + 0.65 * root.transition)
        transform: Translate {
            y: AppController.reducedMotion ? 0 : DesktopTokens.px(8) * (1 - root.transition)
        }

        // Eyebrow Badge & Publisher Metadata Row
        Row {
            spacing: DesktopTokens.px(10)

            // Frosted spotlight pill
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: DesktopTokens.px(24)
                width: spotlightLabel.implicitWidth + DesktopTokens.px(24)
                radius: DesktopTokens.px(12)
                color: "#1F4BD49D"
                border.width: 1
                border.color: "#554BD49D"

                Row {
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(6)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(6)
                        height: DesktopTokens.px(6)
                        radius: width * 0.5
                        color: DesktopTokens.mint
                    }

                    Text {
                        id: spotlightLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("YOUR LIBRARY / IN THE SPOTLIGHT")
                        color: DesktopTokens.mint
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                        font.letterSpacing: 1.3
                    }
                }
            }

            // Optional Genre / Category tag when available
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                readonly property string tagText: root.currentGame
                    ? String(root.currentGame.genre || root.currentGame.storeName || root.currentGame.category || "")
                    : ""
                visible: tagText.length > 0
                height: DesktopTokens.px(24)
                width: genreLabel.implicitWidth + DesktopTokens.px(18)
                radius: DesktopTokens.px(12)
                color: "#1FFFFFFF"
                border.width: 1
                border.color: "#2EFFFFFF"

                Text {
                    id: genreLabel
                    anchors.centerIn: parent
                    text: parent.tagText.toUpperCase()
                    color: "#D8FFFFFF"
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0
                }
            }
        }

        // Title & Publisher Stack
        Column {
            width: parent.width
            spacing: DesktopTokens.px(6)

            Item {
                width: parent.width
                height: heroTitle.implicitHeight

                // Subtle drop-shadow copy for guaranteed contrast over bright key art
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
                    objectName: "desktopHeroTitle"
                    width: parent.width
                    text: root.currentGame
                        ? String(root.currentGame.title || qsTr("Game"))
                        : qsTr("Your game universe")
                    color: "#FFFFFF"
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: DesktopTokens.px(root.compactHeight ? 32 : 36)
                    font.weight: Font.Black
                    font.letterSpacing: -1.1
                    lineHeight: 0.96
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.singleLineTitle ? 1 : 2
                    elide: Text.ElideRight
                }
            }

            Row {
                width: parent.width
                spacing: DesktopTokens.px(8)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(14)
                    height: DesktopTokens.px(2)
                    radius: 1
                    color: DesktopTokens.mint
                    opacity: 0.85
                }

                Text {
                    width: parent.width - DesktopTokens.px(24)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentGame
                        ? String(root.currentGame.publisherName || root.currentGame.publisher || qsTr("Ready to stream from your library"))
                        : qsTr("Your saved games, ready when you are.")
                    color: "#D0E2F2"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }

        // Action Bar
        Row {
            spacing: DesktopTokens.px(12)
            visible: root.currentGame !== null
            topPadding: DesktopTokens.px(2)

            HeroAction {
                objectName: "desktopHeroPlay"
                text: qsTr("Play now")
                primary: true
                actionIndex: 0
                navigationFocus: root.selectedAction === 0
                glyph: "desktop-play-filled.svg"
                implicitWidth: DesktopTokens.px(164)
                onClicked: if (root.currentGame) root.playRequested(root.currentGame)
            }

            HeroAction {
                objectName: "desktopHeroDetails"
                text: qsTr("Details")
                actionIndex: 1
                navigationFocus: root.selectedAction === 1
                glyph: "desktop-info.svg"
                implicitWidth: DesktopTokens.px(138)
                onClicked: if (root.currentGame) root.detailsRequested(root.currentGame)
            }
        }
    }

    // -------------------------------------------------------------------------
    // 7. BOTTOM INTERACTIVE STORY DOCK & UP-NEXT PREVIEW
    // -------------------------------------------------------------------------
    Item {
        objectName: "desktopHeroStoryDock"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: DesktopTokens.px(32)
        anchors.rightMargin: DesktopTokens.px(22)
        anchors.bottomMargin: DesktopTokens.px(16)
        height: DesktopTokens.px(24)
        visible: root.slideCount > 1

        // Left: Interactive Timeline Progress Segments
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: DesktopTokens.px(8)

            Repeater {
                model: root.slideCount
                delegate: Item {
                    id: segment
                    required property int index
                    Accessible.role: Accessible.Button
                    Accessible.name: slideGame ? String(slideGame.title || "") : ""
                    Accessible.onPressAction: root.showSlide(segment.index)
                    readonly property bool isCurrent: index === root.currentIndex
                    readonly property var slideGame: root.games[index]

                    width: isCurrent ? DesktopTokens.px(48) : (segHover.hovered ? DesktopTokens.px(22) : DesktopTokens.px(12))
                    height: DesktopTokens.px(18)

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.duration(240)
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Track pill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: segment.isCurrent || segHover.hovered ? DesktopTokens.px(6) : DesktopTokens.px(5)
                        radius: height * 0.5
                        color: segment.isCurrent ? "#38FFFFFF" : (segHover.hovered ? "#75FFFFFF" : "#38FFFFFF")
                        clip: true

                        Behavior on height { NumberAnimation { duration: Theme.duration(140) } }
                        Behavior on color { ColorAnimation { duration: Theme.duration(140) } }

                        // Live animated fill bar for active slide
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            visible: segment.isCurrent
                            width: AppController.reducedMotion
                                ? parent.width
                                : Math.max(parent.height, parent.width * root.slideProgress)
                            color: DesktopTokens.mint
                        }
                    }

                    // Hover preview tooltip showing the target slide's game title
                    Rectangle {
                        anchors.bottom: parent.top
                        anchors.bottomMargin: DesktopTokens.px(6)
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: segHover.hovered && segment.slideGame !== undefined
                        height: DesktopTokens.px(22)
                        width: Math.min(tipText.implicitWidth + DesktopTokens.px(16), DesktopTokens.px(180))
                        radius: DesktopTokens.px(7)
                        color: "#EE080D17"
                        border.width: 1
                        border.color: "#40FFFFFF"
                        z: 10

                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            width: parent.width - DesktopTokens.px(14)
                            text: segment.slideGame ? String(segment.slideGame.title || "") : ""
                            color: "#FFFFFF"
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: DesktopTokens.tinySize
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    HoverHandler {
                        id: segHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.showSlide(segment.index)
                    }
                }
            }
        }

        // Right: Interactive "Up Next" Teaser Pill
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Accessible.role: Accessible.Button
            Accessible.name: root.nextGame ? String(root.nextGame.title || "") : ""
            Accessible.onPressAction: root.nextSlide()
            visible: root.nextGame !== null
            height: DesktopTokens.px(24)
            width: Math.min(nextRow.implicitWidth + DesktopTokens.px(20), parent.width * 0.44)
            radius: DesktopTokens.px(12)
            color: upNextHover.hovered ? "#26FFFFFF" : "#12FFFFFF"
            border.width: 1
            border.color: upNextHover.hovered ? "#48FFFFFF" : "#22FFFFFF"
            Behavior on color { ColorAnimation { duration: Theme.duration(140) } }
            Behavior on border.color { ColorAnimation { duration: Theme.duration(140) } }

            Row {
                id: nextRow
                anchors.centerIn: parent
                spacing: DesktopTokens.px(6)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("UP NEXT")
                    color: DesktopTokens.mint
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.tinySize
                    font.weight: Font.Bold
                    font.letterSpacing: 0.9
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    color: "#70FFFFFF"
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.tinySize
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, DesktopTokens.px(170))
                    text: root.nextGame ? String(root.nextGame.title || "") : ""
                    color: "#E2FFFFFF"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.tinySize
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            HoverHandler { id: upNextHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.nextSlide() }
        }
    }

    // -------------------------------------------------------------------------
    // 8. OUTER SPECULAR GLASS RIM FRAME
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: DesktopTokens.px(24)
        color: "transparent"
        border.width: 1
        border.color: "#38FFFFFF"
    }

    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion) {
                transitionAnimation.stop()
                root.transition = 1
                root.slideProgress = 0
            }
        }
    }
}