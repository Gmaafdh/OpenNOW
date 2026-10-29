import QtQuick
import QtQuick.Controls
import OpenNOW

// Cinematic spotlight. Artwork bleeds to the card edge, a left-to-right scrim
// carries the copy, and the actions are the only raised surfaces on the screen.
Item {
    id: root

    property var games: []
    property bool active: true
    property int selectedAction: -1
    property int currentIndex: 0
    property int previousIndex: 0
    property real transition: 1

    readonly property int slideCount: games ? games.length : 0
    readonly property var currentGame: slideCount > 0
        ? games[Math.max(0, Math.min(currentIndex, slideCount - 1))] : null
    readonly property string qualityChip: {
        const res = String(ShellStore.settings.resolution || "")
        const fps = Number(ShellStore.settings.fps || 0)
        const codec = String(ShellStore.settings.codec || "auto").toUpperCase()
        const parts = []
        if (res.indexOf("x") > 0)
            parts.push(res.split("x")[1] + "p")
        if (fps > 0)
            parts.push(fps + " fps")
        if (codec !== "" && codec !== "AUTO")
            parts.push(codec)
        return parts.join("  ·  ")
    }

    signal playRequested(var game)
    signal detailsRequested(var game)
    signal actionPointed(int index)

    function showSlide(index) {
        if (slideCount < 1)
            return
        const next = Math.max(0, Math.min(index, slideCount - 1))
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

    onGamesChanged: {
        transitionAnimation.stop()
        previousIndex = 0
        currentIndex = 0
        transition = 1
    }

    clip: true

    // Accent bloom leaking around the card edge.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -DesktopTokens.px(2)
        radius: DesktopTokens.radiusXl + DesktopTokens.px(2)
        color: "transparent"
        border.width: DesktopTokens.px(6)
        border.color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.07)
        visible: heroHover.hovered
        Behavior on opacity { NumberAnimation { duration: DesktopTokens.hoverDuration } }
    }

    Rectangle {
        anchors.fill: parent
        radius: DesktopTokens.radiusXl
        color: "#0A0E18"
        border.width: 1
        border.color: DesktopTokens.hairlineStrong
    }

    Item {
        anchors.fill: parent
        anchors.margins: 1
        clip: true

        Repeater {
            model: root.games
            delegate: Item {
                id: slide
                required property var modelData
                required property int index
                anchors.fill: parent
                visible: opacity > 0
                opacity: index === root.currentIndex ? root.transition
                    : index === root.previousIndex ? 1 - root.transition : 0
                // Keep the slide at its natural size. Scaling the whole slide
                // used to crop the top and bottom of every piece of key art.
                transform: Translate {
                    x: index === root.currentIndex ? 10 * (1 - root.transition) : -8 * root.transition
                }

                RoundedArtwork {
                    anchors.fill: parent
                    artwork: DesktopTokens.artworkUrl(slide.modelData, true)
                    fallbackArtwork: DesktopTokens.artworkUrl(slide.modelData, false)
                    cinematicFit: true
                    alignArtworkRight: true
                    cornerRadius: DesktopTokens.radiusXl - 1
                    scrimStart: 1
                    fallbackColor: "#111C2C"
                }
            }
        }

        // Left scrim: the copy always sits on at least 60% darkness.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#F20A0E18" }
                GradientStop { position: 0.26; color: "#D90A0E18" }
                GradientStop { position: 0.52; color: "#7A0A0E18" }
                GradientStop { position: 0.78; color: "#140A0E18" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        // Bottom scrim: seats the dots and the quality chip.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.48; color: "transparent" }
                GradientStop { position: 0.82; color: "#730A0E18" }
                GradientStop { position: 1; color: "#D90A0E18" }
            }
        }
        // Top scrim: keeps chips legible over bright key art.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#590A0E18" }
                GradientStop { position: 0.24; color: "transparent" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    NumberAnimation {
        id: transitionAnimation
        target: root
        property: "transition"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.OutCubic
    }
    Timer {
        interval: 6200
        repeat: true
        running: root.visible && root.active && root.slideCount > 1
            && !AppController.reducedMotion && !heroHover.hovered
        onTriggered: root.nextSlide()
    }
    HoverHandler { id: heroHover; cursorShape: Qt.PointingHandCursor }

    component HeroAction: Button {
        id: action
        property bool primary: false
        property bool navigationFocus: false
        property int actionIndex: -1
        property string glyph: ""
        property bool compactAction: false
        height: DesktopTokens.px(compactAction ? 40 : 46)
        padding: 0
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        onHoveredChanged: if (hovered && actionIndex >= 0) root.actionPointed(actionIndex)
        opacity: enabled ? 1 : 0.45
        scale: AppController.reducedMotion ? 1 : down ? 0.965 : hovered ? 1.015 : 1
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        implicitWidth: Math.max(DesktopTokens.px(compactAction ? 108 : 132),
                                actionRow.implicitWidth + DesktopTokens.px(compactAction ? 30 : 38))

        background: Item {
            // Accent bloom under the primary action.
            Rectangle {
                visible: action.primary
                anchors.fill: parent
                anchors.margins: -DesktopTokens.px(4)
                radius: DesktopTokens.radiusPill + DesktopTokens.px(4)
                color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b,
                               action.hovered ? 0.20 : 0.12)
                Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -DesktopTokens.px(3)
                visible: action.activeFocus || action.navigationFocus
                radius: DesktopTokens.radiusPill + DesktopTokens.px(3)
                color: "transparent"
                border.width: 2
                border.color: DesktopTokens.focus
            }
            Rectangle {
                anchors.fill: parent
                radius: DesktopTokens.radiusPill
                color: action.primary
                    ? Qt.tint(DesktopTokens.focus, Qt.rgba(1, 1, 1, action.down ? 0 : 0.10 + 0.08 * (action.hovered ? 1 : 0)))
                    : Qt.rgba(1, 1, 1, action.hovered ? 0.20 : 0.13)
                border.width: action.primary ? 0 : 1
                border.color: action.primary ? "transparent"
                    : (action.hovered || action.navigationFocus ? "#80FFFFFF" : "#45FFFFFF")
                Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
                Behavior on border.color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
                Rectangle {
                    visible: !action.primary
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - DesktopTokens.px(40))
                    height: 1
                    radius: 1
                    color: "#33FFFFFF"
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
                DesktopGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(compactAction ? 13 : 15)
                    height: width
                    visible: action.glyph !== ""
                    icon: action.glyph
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: action.text
                    color: action.primary ? DesktopTokens.inkOnAccent : "#FFFFFF"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.px(compactAction ? 12.5 : 14)
                    font.weight: Font.Black
                    font.letterSpacing: 0.1
                }
            }
        }
    }

    // ---- Copy block --------------------------------------------------------
    Column {
        x: DesktopTokens.px(30)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width * 0.56, DesktopTokens.px(600))
        spacing: DesktopTokens.px(12)

        Row {
            spacing: DesktopTokens.px(8)

            Rectangle {
                height: DesktopTokens.px(26)
                width: continueRow.implicitWidth + DesktopTokens.px(22)
                radius: DesktopTokens.radiusPill
                color: Qt.rgba(0, 0, 0, 0.34)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)

                Row {
                    id: continueRow
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(7)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(6)
                        height: width
                        radius: width / 2
                        color: DesktopTokens.mint
                        SequentialAnimation on opacity {
                            running: root.visible && !AppController.reducedMotion
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1500; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: 1500; easing.type: Easing.InOutQuad }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Continue playing")
                        color: "#FFFFFF"
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                        font.letterSpacing: 1.1
                        font.capitalization: Font.AllUppercase
                    }
                }
            }

            DesktopChip {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.currentGame !== null && root.currentGame.store !== undefined
                text: root.currentGame ? DesktopTokens.storeLabel(root.currentGame.store) : ""
                glyph: root.currentGame ? DesktopTokens.storeIconUrl(root.currentGame.store) : ""
                onMedia: true
                tone: DesktopTokens.mint
            }
        }

        Text {
            width: parent.width
            text: root.currentGame ? String(root.currentGame.title || qsTr("Game")) : qsTr("Your game universe")
            color: "#FFFFFF"
            font.family: DesktopTokens.displayFont
            font.pixelSize: DesktopTokens.px(44)
            font.weight: Font.Black
            font.letterSpacing: -1.4
            lineHeight: 0.98
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            style: Text.Raised
            styleColor: "#66000000"
        }

        Row {
            spacing: DesktopTokens.px(10)
            visible: root.currentGame !== null

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentGame ? String(root.currentGame.publisherName || root.currentGame.publisher || qsTr("Ready to stream from your library")) : ""
                color: "#D9FFFFFF"
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(3)
                height: width
                radius: width / 2
                color: "#66FFFFFF"
                visible: metaText.text !== ""
            }
            Text {
                id: metaText
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentGame
                    ? DesktopTokens.relativeLastPlayed(root.currentGame.lastPlayed, Date.now())
                    : ""
                color: "#99FFFFFF"
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Medium
            }
        }

        Row {
            spacing: DesktopTokens.px(10)
            visible: root.currentGame !== null

            HeroAction {
                objectName: "desktopHeroPlay"
                text: qsTr("Play now")
                primary: true
                actionIndex: 0
                navigationFocus: root.selectedAction === 0
                glyph: "desktop-play-filled.svg"
                implicitWidth: DesktopTokens.px(160)
                onClicked: if (root.currentGame) root.playRequested(root.currentGame)
            }
            HeroAction {
                objectName: "desktopHeroDetails"
                text: qsTr("Details")
                actionIndex: 1
                navigationFocus: root.selectedAction === 1
                glyph: "desktop-info.svg"
                implicitWidth: DesktopTokens.px(132)
                onClicked: if (root.currentGame) root.detailsRequested(root.currentGame)
            }

            // Feature flags ride beside the actions — icon plus tooltip, never
            // colour alone.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: DesktopTokens.px(6)
                spacing: DesktopTokens.px(6)
                visible: root.currentGame !== null && DesktopTokens.gameFeatures(root.currentGame).length > 0
                Repeater {
                    model: root.currentGame ? DesktopTokens.gameFeatures(root.currentGame) : []
                    delegate: Rectangle {
                        id: featurePill
                        required property string modelData
                        width: DesktopTokens.px(28)
                        height: DesktopTokens.px(28)
                        radius: DesktopTokens.radiusPill
                        color: Qt.rgba(1, 1, 1, featureHover.hovered ? 0.20 : 0.11)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        Accessible.role: Accessible.StaticText
                        Accessible.name: DesktopTokens.featureLabel(featurePill.modelData)
                        Image {
                            anchors.centerIn: parent
                            width: DesktopTokens.px(15)
                            height: width
                            source: DesktopTokens.featureIconUrl(featurePill.modelData)
                            sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
                            fillMode: Image.PreserveAspectFit
                        }
                        HoverHandler { id: featureHover }
                        ToolTip.visible: featureHover.hovered
                        ToolTip.text: DesktopTokens.featureTip(featurePill.modelData)
                        ToolTip.delay: 300
                    }
                }
            }
        }
    }

    // ---- Live quality chip -------------------------------------------------
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: DesktopTokens.px(16)
        height: DesktopTokens.px(26)
        width: qualityRow.implicitWidth + DesktopTokens.px(22)
        radius: DesktopTokens.radiusPill
        visible: root.qualityChip !== ""
        color: Qt.rgba(0, 0, 0, 0.40)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        Row {
            id: qualityRow
            anchors.centerIn: parent
            spacing: DesktopTokens.px(7)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(6)
                height: width
                radius: width / 2
                color: DesktopTokens.mint
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.qualityChip
                color: "#E6FFFFFF"
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.microSize
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
            }
        }
    }

    // ---- Slide indicators --------------------------------------------------
    Row {
        x: DesktopTokens.px(30)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: DesktopTokens.px(20)
        spacing: DesktopTokens.px(6)
        visible: root.slideCount > 1
        Repeater {
            model: root.slideCount
            delegate: Rectangle {
                id: pip
                required property int index
                width: index === root.currentIndex ? DesktopTokens.px(30) : DesktopTokens.px(7)
                height: DesktopTokens.px(4)
                radius: height / 2
                color: index === root.currentIndex ? DesktopTokens.focus : Qt.rgba(1, 1, 1, 0.38)
                Behavior on width { NumberAnimation { duration: AppController.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: AppController.reducedMotion ? 0 : 160 } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.showSlide(index) }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: DesktopTokens.px(24)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: DesktopTokens.px(15)
        visible: root.slideCount > 1
        text: qsTr("%1 / %2").arg(root.currentIndex + 1).arg(root.slideCount)
        color: Qt.rgba(1, 1, 1, 0.62)
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.tinySize
        font.weight: Font.DemiBold
        font.letterSpacing: 1.0
    }

    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion) {
                transitionAnimation.stop()
                root.transition = 1
            }
        }
    }
}
