import QtQuick
import QtQuick.Controls
import OpenNOW

// A cinematic, data-driven library banner. Artwork crossfades and drifts
// without decorative objects competing with the game image.
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
                    cornerRadius: 24
                    scrimStart: 1
                    fallbackColor: "#111C2C"
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#E60A0E18" }
                GradientStop { position: 0.32; color: "#A00A0E18" }
                GradientStop { position: 0.68; color: "#180A0E18" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 1; color: "#B80A0E18" }
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
        height: DesktopTokens.px(44)
        padding: 0
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        onHoveredChanged: if (hovered && actionIndex >= 0) root.actionPointed(actionIndex)
        opacity: enabled ? 1 : 0.45
        scale: AppController.reducedMotion ? 1 : down ? 0.965 : hovered ? 1.015 : 1
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Item {
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: DesktopTokens.px(4)
                radius: DesktopTokens.px(13)
                color: action.primary ? "#64000000" : "#40000000"
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                visible: action.activeFocus || action.navigationFocus
                radius: DesktopTokens.px(16)
                color: "transparent"
                border.width: 2
                border.color: DesktopTokens.focus
            }
            Rectangle {
                anchors.fill: parent
                radius: DesktopTokens.px(13)
                border.width: 1
                border.color: action.activeFocus || action.navigationFocus ? "#FFFFFF"
                    : action.primary ? "#99FFFFFF" : action.hovered ? "#80FFFFFF" : "#48FFFFFF"
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: action.primary ? (action.down ? "#63DDA9" : action.hovered ? "#A4F8D3" : "#8AF3C4")
                            : (action.down ? "#24FFFFFF" : action.hovered ? "#32FFFFFF" : "#20FFFFFF")
                    }
                    GradientStop {
                        position: 1
                        color: action.primary ? (action.down ? "#38B886" : action.hovered ? "#5FE3AA" : "#4BD49D")
                            : (action.down ? "#141B2B" : action.hovered ? "#243247" : "#D9141D2B")
                    }
                }
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }
        }
        contentItem: Item {
            Row {
                anchors.centerIn: parent
                spacing: DesktopTokens.px(9)
                DesktopGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(15)
                    height: width
                    visible: action.glyph !== ""
                    icon: action.glyph
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: action.text
                    color: action.primary ? "#071B16" : "#FFFFFF"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    font.weight: Font.Black
                }
            }
        }
    }

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

            HeroAction {
                objectName: "desktopHeroPlay"
                text: qsTr("Play now")
                primary: true
                actionIndex: 0
                navigationFocus: root.selectedAction === 0
                glyph: "desktop-play-filled.svg"
                implicitWidth: DesktopTokens.px(148)
                onClicked: if (root.currentGame) root.playRequested(root.currentGame)
            }
            HeroAction {
                objectName: "desktopHeroDetails"
                text: qsTr("Details")
                actionIndex: 1
                navigationFocus: root.selectedAction === 1
                glyph: "desktop-info.svg"
                implicitWidth: DesktopTokens.px(124)
                onClicked: if (root.currentGame) root.detailsRequested(root.currentGame)
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
                Behavior on width { NumberAnimation { duration: AppController.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: AppController.reducedMotion ? 0 : 160 } }
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
            }
        }
    }
}
