import QtQuick
import QtQuick.Controls
import OpenNOW

// A seamless landscape-art marquee. Two copies of one sequence make the loop
// continuous; hover pauses it so the art and the click target stay readable.
Item {
    id: root

    property var games: []
    property bool active: true
    readonly property int cardWidth: 196
    readonly property int cardGap: 12
    readonly property var sourceGames: (games || []).slice(0, 10)
    readonly property var loopGames: sourceGames.concat(sourceGames)
    readonly property int sequenceWidth: sourceGames.length * (cardWidth + cardGap)

    signal gameRequested(var game)

    function restart() {
        scrollAnimation.stop()
        track.x = 0
        if (sourceGames.length > 1 && active && visible && !AppController.reducedMotion) {
            scrollAnimation.from = 0
            scrollAnimation.to = -sequenceWidth
            scrollAnimation.duration = Math.max(14000, sequenceWidth * 22)
            scrollAnimation.start()
        }
    }

    onSourceGamesChanged: Qt.callLater(restart)
    onActiveChanged: restart()
    onVisibleChanged: restart()
    Component.onCompleted: Qt.callLater(restart)

    clip: true

    Row {
        id: track
        y: 0
        width: Math.max(1, loopGames.length * (root.cardWidth + root.cardGap))
        height: root.height
        spacing: root.cardGap

        Repeater {
            model: root.loopGames
            delegate: Item {
                id: card
                required property var modelData
                required property int index
                width: root.cardWidth
                height: root.height
                Accessible.role: Accessible.Button
                Accessible.name: String(card.modelData && card.modelData.title || qsTr("Game"))

                RoundedArtwork {
                    anchors.fill: parent
                    artwork: DesktopTokens.artworkUrl(card.modelData, true)
                    fallbackArtwork: DesktopTokens.artworkUrl(card.modelData, false)
                    cornerRadius: 14
                    scrimStart: 0.42
                    fallbackColor: "#152033"
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: cardHover.hovered ? 2 : 1
                    border.color: cardHover.hovered ? DesktopTokens.focus : "#38FFFFFF"
                    Behavior on border.color { ColorAnimation { duration: 160 } }
                }
                Rectangle {
                    x: 10
                    y: 10
                    width: 28
                    height: 20
                    radius: 6
                    color: "#A80A0E18"
                    Text {
                        anchors.centerIn: parent
                        text: String((index % Math.max(1, root.sourceGames.length)) + 1).padStart(2, "0")
                        color: "#E8FFFFFF"
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
                Text {
                    x: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: parent.width - 24
                    text: String(card.modelData && card.modelData.title || qsTr("Game"))
                    color: "#FFFFFF"
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: 13
                    font.weight: Font.Black
                    elide: Text.ElideRight
                }
                HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (card.modelData) root.gameRequested(card.modelData) }
            }
        }
    }

    NumberAnimation {
        id: scrollAnimation
        target: track
        property: "x"
        easing.type: Easing.Linear
        loops: Animation.Infinite
    }

    // Edge fades make the rail feel like a continuous viewport rather than a
    // row that abruptly starts and ends at the window edge.
    Rectangle {
        anchors.left: parent.left
        width: 52
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: DesktopTokens.shell }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        anchors.right: parent.right
        width: 52
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: DesktopTokens.shell }
        }
    }
    HoverHandler {
        id: railHover
        onHoveredChanged: {
            if (hovered) {
                if (scrollAnimation.running)
                    scrollAnimation.pause()
            } else if (scrollAnimation.running) {
                scrollAnimation.resume()
            }
        }
    }

    Connections {
        target: AppController
        function onReducedMotionChanged() {
            if (AppController.reducedMotion) {
                scrollAnimation.stop()
                track.x = 0
            } else {
                root.restart()
            }
        }
    }
}
