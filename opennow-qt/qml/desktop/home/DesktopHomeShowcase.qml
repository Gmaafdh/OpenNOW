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
    readonly property var featured: nextGames.length ? nextGames[0] : null

    signal playRequested(var game)
    signal detailsRequested(var game)
    signal libraryRequested()
    signal actionPointed(int index)

    DesktopLibraryHero {
        id: spotlight
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.deckVisible ? parent.width - controlDeck.width - DesktopTokens.px(16) : parent.width
        games: root.games
        active: root.active
        selectedAction: root.selectedAction
        onPlayRequested: game => root.playRequested(game)
        onDetailsRequested: game => root.detailsRequested(game)
        onActionPointed: index => root.actionPointed(index)
    }

    // ---- Control deck ------------------------------------------------------
    Item {
        id: controlDeck
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: DesktopTokens.px(300)
        visible: root.deckVisible

        DesktopSurface {
            anchors.fill: parent
            corner: DesktopTokens.radiusXl
            fill: Theme.lightMode ? Qt.rgba(1, 1, 1, 0.80) : Qt.rgba(1, 1, 1, 0.045)
            fillTop: Theme.lightMode ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(1, 1, 1, 0.075)
            fillBottom: Theme.lightMode ? Qt.rgba(0.96, 0.97, 1, 0.86) : Qt.rgba(0, 0, 0, 0.18)
            stroke: DesktopTokens.hairline
            bloom: true
        }

        // Header: library pulse
        Row {
            id: deckHeader
            x: DesktopTokens.px(18)
            y: DesktopTokens.px(16)
            width: parent.width - DesktopTokens.px(36)
            spacing: DesktopTokens.px(10)

            Item {
                width: DesktopTokens.px(42)
                height: width
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.34)
                }
                Text {
                    anchors.centerIn: parent
                    text: String(root.totalGames)
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: DesktopTokens.px(16)
                    font.weight: Font.Black
                    font.letterSpacing: -0.5
                }
            }

            Column {
                width: parent.width - DesktopTokens.px(52)
                anchors.verticalCenter: parent.verticalCenter
                spacing: DesktopTokens.px(1)
                Text {
                    text: qsTr("Ready to launch")
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.captionSize
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    text: root.favoriteCount > 0
                        ? qsTr("%1 games · %2 pinned").arg(root.totalGames).arg(root.favoriteCount)
                        : qsTr("%1 games in your library").arg(root.totalGames)
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            id: deckRule
            x: DesktopTokens.px(18)
            y: DesktopTokens.px(74)
            width: parent.width - DesktopTokens.px(36)
            height: 1
            color: DesktopTokens.hairlineSoft
        }

        Text {
            x: DesktopTokens.px(18)
            y: deckRule.y + DesktopTokens.px(14)
            text: qsTr("Up next")
            color: DesktopTokens.textFaint
            font.family: DesktopTokens.monoFont
            font.pixelSize: DesktopTokens.tinySize
            font.weight: Font.Bold
            font.letterSpacing: 1.3
            font.capitalization: Font.AllUppercase
        }

        // Stacked cards: each row lifts and reveals a play affordance.
        Column {
            id: nextStack
            x: DesktopTokens.px(10)
            y: deckRule.y + DesktopTokens.px(38)
            width: parent.width - DesktopTokens.px(20)
            spacing: DesktopTokens.px(4)

            Repeater {
                model: root.nextGames
                delegate: Item {
                    id: nextCard
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: DesktopTokens.px(62)
                    Accessible.role: Accessible.Button
                    Accessible.name: String(modelData && modelData.title || qsTr("Game"))
                    Accessible.description: qsTr("Open details")

                    readonly property real lift: cardHover.hovered ? 1 : 0

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: DesktopTokens.px(2)
                        radius: DesktopTokens.radiusMd
                        color: cardHover.hovered
                            ? DesktopTokens.fillRaised
                            : Qt.rgba(1, 1, 1, 0.01)
                        border.width: 1
                        border.color: cardHover.hovered ? DesktopTokens.hairline : "transparent"
                        Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
                        Behavior on border.color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
                    }

                    Item {
                        x: DesktopTokens.px(7)
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(44)
                        height: DesktopTokens.px(44)

                        RoundedArtwork {
                            anchors.fill: parent
                            artwork: DesktopTokens.artworkUrl(modelData, false)
                            cornerRadius: DesktopTokens.radiusSm
                            scrimStart: 1
                            fallbackColor: "#1A2232"
                        }

                        // Play affordance appears on hover — pointer enhancement,
                        // the whole row stays clickable for keyboard and touch.
                        Rectangle {
                            anchors.fill: parent
                            radius: DesktopTokens.radiusSm
                            color: Qt.rgba(0, 0, 0, 0.45)
                            opacity: nextCard.lift
                            Behavior on opacity { NumberAnimation { duration: DesktopTokens.hoverDuration } }
                            DesktopGlyph {
                                anchors.centerIn: parent
                                width: DesktopTokens.px(16)
                                height: width
                                icon: "desktop-play-filled.svg"
                            }
                        }
                    }

                    Column {
                        x: DesktopTokens.px(60)
                        width: parent.width - x - DesktopTokens.px(26)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: DesktopTokens.px(2)
                        Text {
                            width: parent.width
                            text: String(modelData && modelData.title || qsTr("Game"))
                            color: DesktopTokens.textHigh
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: DesktopTokens.px(12.5)
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: String(modelData && (modelData.publisherName || modelData.publisher) || qsTr("Ready to stream"))
                            color: DesktopTokens.textMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: DesktopTokens.tinySize
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: DesktopTokens.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(18)
                        height: width
                        radius: width / 2
                        color: cardHover.hovered
                            ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.18)
                            : "transparent"
                        DesktopGlyph {
                            anchors.centerIn: parent
                            width: DesktopTokens.px(9)
                            height: width
                            rotation: -90
                            icon: "desktop-chevron-down.svg"
                            opacity: cardHover.hovered ? 1 : 0.45
                        }
                        Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
                    }

                    HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (!modelData)
                                return
                            if (index === 0)
                                root.playRequested(modelData)
                            else
                                root.detailsRequested(modelData)
                        }
                    }
                }
            }
        }

        Text {
            x: DesktopTokens.px(18)
            y: deckRule.y + DesktopTokens.px(48)
            width: parent.width - DesktopTokens.px(36)
            visible: root.nextGames.length === 0
            text: qsTr("Your next adventure is waiting. Play something to see it here.")
            wrapMode: Text.WordWrap
            color: DesktopTokens.textMuted
            font.family: DesktopTokens.bodyFont
            font.pixelSize: DesktopTokens.smallSize
        }

        // Footer action
        DesktopButton {
            x: DesktopTokens.px(14)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: DesktopTokens.px(14)
            width: parent.width - DesktopTokens.px(28)
            height: DesktopTokens.px(38)
            variant: "glass"
            cornerRadius: DesktopTokens.radiusMd
            glyph: "desktop-nav-library.svg"
            glyphSize: DesktopTokens.px(14)
            text: qsTr("Open library")
            onClicked: root.libraryRequested()
        }
    }
}
