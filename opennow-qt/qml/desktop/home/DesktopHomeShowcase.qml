import QtQuick
import OpenNOW

// Home is a dashboard, not a smaller copy of the library. The spotlight and
// the control deck give the two most common actions different visual weights.
Item {
    id: root
    objectName: "desktopHomeShowcase"

    property var games: []
    property var recentGames: []
    property int totalGames: 0
    property int favoriteCount: 0
    property bool active: true
    property int selectedAction: -1

    readonly property var nextGames: (recentGames || []).slice(1, 4)
    readonly property bool deckVisible: width >= 980

    signal playRequested(var game)
    signal detailsRequested(var game)
    signal libraryRequested()
    signal actionPointed(int index)

    DesktopLibraryHero {
        id: spotlight
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.deckVisible ? parent.width - controlDeck.width - 16 : parent.width
        games: root.games
        active: root.active
        selectedAction: root.selectedAction
        onPlayRequested: game => root.playRequested(game)
        onDetailsRequested: game => root.detailsRequested(game)
        onActionPointed: index => root.actionPointed(index)
    }

    Rectangle {
        id: controlDeck
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 296
        visible: root.deckVisible
        radius: 24
        color: Theme.lightMode ? "#F2F5FA" : "#E60B1320"
        border.width: 1
        border.color: DesktopTokens.seam

        Text {
            x: 20
            y: 18
            text: qsTr("LIBRARY CONTROL")
            color: DesktopTokens.mint
            font.family: DesktopTokens.monoFont
            font.pixelSize: DesktopTokens.microSize
            font.weight: Font.Bold
            font.letterSpacing: 1.4
        }
        Text {
            x: 20
            y: 42
            text: root.totalGames
            color: DesktopTokens.textHigh
            font.family: DesktopTokens.displayFont
            font.pixelSize: 32
            font.weight: Font.Black
            font.letterSpacing: -1
        }
        Text {
            x: 78
            y: 57
            width: parent.width - 98
            text: qsTr("games ready to explore")
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
            elide: Text.ElideRight
        }

        Rectangle {
            x: 20
            y: 91
            width: parent.width - 40
            height: 1
            color: DesktopTokens.seam
        }
        Text {
            x: 20
            y: 105
            text: qsTr("UP NEXT")
            color: DesktopTokens.textFaint
            font.family: DesktopTokens.monoFont
            font.pixelSize: DesktopTokens.tinySize
            font.weight: Font.Bold
            font.letterSpacing: 1.2
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 105
            text: qsTr("%1 pinned").arg(root.favoriteCount)
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.monoFont
            font.pixelSize: DesktopTokens.tinySize
        }

        Column {
            x: 14
            y: 130
            width: parent.width - 28
            spacing: 6
            Repeater {
                model: root.nextGames
                delegate: Rectangle {
                    id: nextCard
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 52
                    radius: 12
                    color: nextHover.hovered ? DesktopTokens.raisedStrong : "transparent"
                    border.width: 1
                    border.color: nextHover.hovered ? DesktopTokens.seam : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: String(modelData && modelData.title || qsTr("Game"))

                    RoundedArtwork {
                        x: 5
                        y: 5
                        width: 42
                        height: 42
                        artwork: DesktopTokens.artworkUrl(modelData, false)
                        cornerRadius: 9
                        scrimStart: 1
                        fallbackColor: "#1A2232"
                    }
                    Text {
                        x: 58
                        y: 9
                        width: parent.width - 88
                        text: String(modelData && modelData.title || qsTr("Game"))
                        color: DesktopTokens.textHigh
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.smallSize
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        x: 58
                        y: 29
                        width: parent.width - 88
                        text: String(modelData && (modelData.publisherName || modelData.publisher) || qsTr("Ready to stream"))
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.tinySize
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: nextHover.hovered ? DesktopTokens.focus : DesktopTokens.textFaint
                        font.family: DesktopTokens.displayFont
                        font.pixelSize: 22
                    }
                    HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (modelData) root.detailsRequested(modelData) }
                }
            }
        }

        Text {
            x: 20
            y: 244
            visible: root.nextGames.length === 0
            text: qsTr("Your next adventure is waiting.")
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
        }
        DesktopButton {
            x: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: parent.width - 32
            height: 36
            primary: false
            cornerRadius: 12
            glyph: "desktop-nav-library.svg"
            glyphSize: 14
            text: qsTr("Open library")
            onClicked: root.libraryRequested()
        }
    }
}
