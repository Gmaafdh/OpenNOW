import QtQuick
import QtQuick.Controls
import OpenNOW

// A cinematic, data-driven library banner. The artwork crossfades and drifts
// while the accent objects continuously change shape, not just opacity.
Item {
    id: root

    property var games: []
    property bool active: true
    property int currentIndex: 0
    property int previousIndex: 0
    property real transition: 1
    property real morph: 0

    readonly property int slideCount: games ? games.length : 0
    readonly property var currentGame: slideCount > 0
        ? games[Math.max(0, Math.min(currentIndex, slideCount - 1))] : null

    signal playRequested(var game)
    signal detailsRequested(var game)

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

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: "#0A0E18"
        border.width: 1
        border.color: "#35FFFFFF"
    }

    Item {
        anchors.fill: parent
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
                scale: index === root.currentIndex ? 1.08 - 0.08 * root.transition
                    : 1 + 0.035 * root.transition
                transformOrigin: Item.Center
                transform: Translate {
                    x: index === root.currentIndex ? 26 * (1 - root.transition) : -20 * root.transition
                }

                RoundedArtwork {
                    anchors.fill: parent
                    artwork: DesktopTokens.artworkUrl(slide.modelData, true)
                    cornerRadius: 0
                    scrimStart: 1
                    fallbackColor: "#111C2C"
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#F20A0E18" }
                GradientStop { position: 0.38; color: "#C80A0E18" }
                GradientStop { position: 0.72; color: "#380A0E18" }
                GradientStop { position: 1; color: "#080A0E18" }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 1; color: "#B80A0E18" }
            }
        }

        // These are deliberately large enough to read as morphing objects in
        // motion: a ring becomes a rounded slab while a second pill breathes.
        Rectangle {
            width: 156 + 92 * root.morph
            height: 156 + 42 * (1 - root.morph)
            x: parent.width - width * 0.42
            y: -height * 0.36
            radius: Math.min(width, height) * (0.50 - 0.29 * root.morph)
            rotation: 18 + 112 * root.morph
            color: "#12FFFFFF"
            border.width: 2
            border.color: "#42FFFFFF"
        }
        Rectangle {
            width: 74 + 132 * root.morph
            height: 26 + 74 * (1 - root.morph)
            anchors.right: parent.right
            anchors.rightMargin: 34 + 32 * root.morph
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30 + 24 * (1 - root.morph)
            radius: Math.min(width, height) * (0.5 - 0.25 * root.morph)
            rotation: -18 + 36 * root.morph
            color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.26)
            border.width: 1
            border.color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.62)
        }
    }

    SequentialAnimation {
        running: root.visible && root.active && !AppController.reducedMotion
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "morph"; from: 0; to: 1; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "morph"; from: 1; to: 0; duration: 2600; easing.type: Easing.InOutSine }
    }
    NumberAnimation {
        id: transitionAnimation
        target: root
        property: "transition"
        from: 0
        to: 1
        duration: 820
        easing.type: Easing.InOutCubic
    }
    Timer {
        interval: 6200
        repeat: true
        running: root.visible && root.active && root.slideCount > 1
            && !AppController.reducedMotion && !heroHover.hovered
        onTriggered: root.nextSlide()
    }
    HoverHandler { id: heroHover; cursorShape: Qt.PointingHandCursor }

    Column {
        x: 30
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width * 0.58, 610)
        spacing: 10

        Text {
            text: qsTr("YOUR LIBRARY / IN THE SPOTLIGHT")
            color: DesktopTokens.mint
            font.family: DesktopTokens.monoFont
            font.pixelSize: DesktopTokens.microSize
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }
        Text {
            width: parent.width
            text: root.currentGame ? String(root.currentGame.title || qsTr("Game")) : qsTr("Your game universe")
            color: "#FFFFFF"
            font.family: DesktopTokens.displayFont
            font.pixelSize: DesktopTokens.px(34)
            font.weight: Font.Black
            font.letterSpacing: -1.1
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.currentGame
                ? String(root.currentGame.publisherName || root.currentGame.publisher || qsTr("Ready to stream from your library"))
                : qsTr("Your saved games, ready when you are.")
            color: "#C8FFFFFF"
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.captionSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Row {
            spacing: 10
            visible: root.currentGame !== null

            Button {
                id: playButton
                text: qsTr("Play now")
                height: 40
                implicitWidth: 142
                padding: 0
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                onClicked: if (root.currentGame) root.playRequested(root.currentGame)
                background: Rectangle {
                    radius: playButton.hovered || playButton.activeFocus ? 18 : 12
                    color: playButton.down ? "#D9FFFFFF" : "#F5FFFFFF"
                    Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
                contentItem: Row {
                    spacing: 9
                    anchors.centerIn: parent
                    DesktopGlyph { anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; icon: "desktop-play.svg" }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: playButton.text
                        color: "#0B0F1A"
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.captionSize
                        font.weight: Font.Black
                    }
                }
            }
            Button {
                id: detailsButton
                text: qsTr("Details")
                height: 40
                implicitWidth: 112
                padding: 0
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                onClicked: if (root.currentGame) root.detailsRequested(root.currentGame)
                background: Rectangle {
                    radius: detailsButton.hovered || detailsButton.activeFocus ? 18 : 12
                    color: detailsButton.hovered ? "#35FFFFFF" : "#18FFFFFF"
                    border.width: 1
                    border.color: "#55FFFFFF"
                    Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                contentItem: Text {
                    text: detailsButton.text
                    color: "#FFFFFF"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Row {
        x: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        spacing: 7
        visible: root.slideCount > 1
        Repeater {
            model: root.slideCount
            delegate: Rectangle {
                required property int index
                width: index === root.currentIndex ? 34 : 8
                height: 6
                radius: 3
                color: index === root.currentIndex ? DesktopTokens.mint : "#66FFFFFF"
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 180 } }
                TapHandler { onTapped: root.showSlide(index) }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        visible: root.slideCount > 1
        text: qsTr("AUTO ROTATE  ·  %1 / %2").arg(root.currentIndex + 1).arg(root.slideCount)
        color: "#B8FFFFFF"
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.tinySize
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }

    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion) {
                transitionAnimation.stop()
                root.transition = 1
                root.morph = 0
            }
        }
    }
}
