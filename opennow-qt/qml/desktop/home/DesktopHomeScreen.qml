pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import OpenNOW

FocusScope {
    id: root

    readonly property string pageTitle: qsTr("Home")
    readonly property string pageSubtitle: ShellStore.catalogTotalCount
        ? qsTr("%1 games").arg(ShellStore.catalogTotalCount)
        : qsTr("Your library")
    property int focusZone: 0
    property int focusIndex: 0
    property bool active: true
    property double lastPlayedNowMs: Date.now()

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.visible && Qt.application.state === Qt.ApplicationActive
        triggeredOnStart: true
        onTriggered: root.lastPlayedNowMs = Date.now()
    }

    signal routeRequested(string route)
    signal gameRequested(var game)
    signal playRequested(var game)

    anchors.fill: parent
    focus: active
    clip: true
    Accessible.role: Accessible.Pane
    Accessible.name: pageTitle

    readonly property var games: ShellStore.catalogGames || []
    readonly property var sortedRecent: {
        const list = (root.games || []).slice()
        list.sort((left, right) => String(right.lastPlayed || "").localeCompare(String(left.lastPlayed || "")))
        return list
    }
    readonly property var heroGame: root.sortedRecent.length ? root.sortedRecent[0] : null
    readonly property var showcaseGames: root.takeGames(root.sortedRecent, 0, 6)
    readonly property var jumpGames: root.takeGames(root.sortedRecent, 1, 12)
    readonly property int favoriteCount: {
        let count = 0
        for (let i = 0; i < root.games.length; ++i) {
            if (ShellStore.isFavorite(root.games[i]))
                count += 1
        }
        return count
    }
    readonly property var favoriteGames: {
        const list = []
        for (let i = 0; i < root.games.length; ++i) {
            if (ShellStore.isFavorite(root.games[i]))
                list.push(root.games[i])
        }
        return list.length ? list : root.takeGames(root.games, 0, 12)
    }
    readonly property var newGames: root.takeGames(root.games, Math.max(0, root.games.length - 12), 12)
    readonly property bool friendsAvailable: Boolean(ShellStore.socialCapabilities && ShellStore.socialCapabilities.friendsAvailable)
    readonly property int railGap: 14
    readonly property int railInnerWidth: Math.max(200, contentFlick.width - 48)
    readonly property int homeTileCount: {
        const fit = Math.max(1, Math.floor((root.railInnerWidth + root.railGap) / (132 + root.railGap)))
        return Math.max(1, Math.min(fit, 8))
    }
    readonly property int homeTileWidth: Math.max(112, Math.floor((root.railInnerWidth - root.railGap * (root.homeTileCount - 1)) / root.homeTileCount))
    readonly property int homeTileHeight: Math.round(root.homeTileWidth * 168 / 112) + DesktopTokens.px(46)

    function takeGames(source, start, limit) {
        const list = source || []
        const result = []
        for (let index = start; index < list.length && result.length < limit; ++index)
            result.push(list[index])
        return result
    }

    function heroMeta() {
        const game = root.heroGame
        if (!game)
            return qsTr("Sign in and sync your library to continue a game.")
        const last = DesktopTokens.relativeLastPlayed(game.lastPlayed, root.lastPlayedNowMs)
        const hours = game.hoursPlayed ? qsTr("%1 h played").arg(game.hoursPlayed) : ""
        if (last !== "" && hours !== "")
            return last + " · " + hours
        if (last !== "")
            return last
        if (hours !== "")
            return hours
        return qsTr("Ready to stream from your library")
    }

    function streamChip() {
        const res = String(ShellStore.settings.resolution || "")
        const fps = Number(ShellStore.settings.fps || 0)
        const codec = String(ShellStore.settings.codec || "auto").toUpperCase()
        const parts = []
        if (res.indexOf("x") > 0)
            parts.push(res.split("x")[1] + "p")
        if (fps > 0)
            parts.push(fps + " fps")
        if (codec !== "")
            parts.push(codec)
        return parts.length ? parts.join(" · ") : qsTr("Stream ready")
    }

    function zoneGames(zone) {
        if (zone === 1) return root.jumpGames
        if (zone === 2) return root.favoriteGames
        return root.newGames
    }

    function setSelection(zone, index, revealSelection) {
        root.focusZone = Math.max(0, Math.min(3, zone))
        const count = root.focusZone === 0 ? 2 : root.zoneGames(root.focusZone).length
        root.focusIndex = Math.max(0, Math.min(Math.max(0, count - 1), index))
        // Pointer hover can be retriggered when a hero crossfades beneath the
        // cursor. Only explicit keyboard/controller navigation may scroll.
        if (revealSelection === true)
            root.ensureSelectionVisible()
    }

    function ensureSelectionVisible() {
        const rail = root.focusZone === 1 ? jumpRail : root.focusZone === 2 ? playingRail : newRail
        const zoneTop = root.focusZone === 0 ? homeColumn.y + heroRow.y : homeColumn.y + rail.y
        const zoneBottom = root.focusZone === 0 ? zoneTop + heroRow.height : zoneTop + 30 + root.homeTileHeight
        // Explicit keyboard/controller navigation still reveals its target.
        // Unlike the old upper-zone shortcut, this has no unconditional top jump.
        if (zoneTop < contentFlick.contentY + 12)
            contentFlick.contentY = Math.max(0, zoneTop - 12)
        else if (zoneBottom > contentFlick.contentY + contentFlick.height - 12)
            contentFlick.contentY = Math.min(Math.max(0, contentFlick.contentHeight - contentFlick.height),
                                             zoneBottom - contentFlick.height + 12)
    }

    function moveHorizontal(delta) {
        const count = root.focusZone === 0 ? 2 : root.zoneGames(root.focusZone).length
        if (count <= 0)
            return
        root.setSelection(root.focusZone, Math.max(0, Math.min(count - 1, root.focusIndex + delta)), true)
    }

    function moveVertical(delta) {
        const nextZone = Math.max(0, Math.min(3, root.focusZone + delta))
        if (nextZone === root.focusZone)
            return
        let nextIndex = root.focusIndex
        if (nextZone === 0)
            nextIndex = Math.min(1, Math.round(root.focusIndex / 4))
        else if (root.focusZone === 0)
            nextIndex = Math.min(8, root.focusIndex * 2)
        root.setSelection(nextZone, nextIndex, true)
    }

    function openGame(game) {
        if (!game)
            return
        root.gameRequested(game)
    }

    function startHero() {
        if (!root.heroGame)
            return
        ShellStore.selectedGame = root.heroGame
        if (ShellStore.signedIn)
            ShellStore.launchSelectedGame(false)
        else
            AppController.navigate("sign-in")
    }

    function openFriends() {
        AppController.showOverlay("friends")
    }

    function activateSelection() {
        if (root.focusZone === 0) {
            if (root.focusIndex === 0)
                root.startHero()
            else if (root.focusIndex === 1)
                root.openGame(root.heroGame)
            return
        }
        const selectedGames = root.zoneGames(root.focusZone)
        if (selectedGames.length > root.focusIndex)
            root.openGame(selectedGames[root.focusIndex])
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) {
            root.moveHorizontal(-1)
        } else if (event.key === Qt.Key_Right) {
            root.moveHorizontal(1)
        } else if (event.key === Qt.Key_Up) {
            root.moveVertical(-1)
        } else if (event.key === Qt.Key_Down) {
            root.moveVertical(1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activateSelection()
        } else {
            return
        }
        event.accepted = true
    }

    Flickable {
        id: contentFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, homeColumn.implicitHeight + 28)
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5200
        maximumFlickVelocity: 2200
        Accessible.role: Accessible.Pane

        Column {
            id: homeColumn
            x: 24
            y: 18
            width: contentFlick.width - 48
            spacing: 18

            Item {
                id: heroRow
                width: parent.width
                height: Math.max(DesktopTokens.px(400), Math.min(DesktopTokens.px(440), Math.round(width * 0.38)))

                DesktopHomeShowcase {
                    anchors.fill: parent
                    games: root.showcaseGames
                    recentGames: root.sortedRecent
                    totalGames: root.games.length
                    favoriteCount: root.favoriteCount
                    active: root.active
                    selectedAction: root.focusZone === 0 && AppController.inputMode !== "pointer" ? root.focusIndex : -1
                    onPlayRequested: game => root.playRequested(game)
                    onDetailsRequested: game => root.openGame(game)
                    onLibraryRequested: root.routeRequested("library")
                    onActionPointed: index => root.setSelection(0, index)
                }
            }

            Item {
                id: discoveryRail
                width: parent.width
                height: 124

                Text {
                    text: qsTr("THE COLLECTION / IN MOTION")
                    color: DesktopTokens.mint
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
                Text {
                    anchors.right: parent.right
                    y: 1
                    text: qsTr("OPEN LIBRARY  ›")
                    color: openCollectionHover.hovered ? DesktopTokens.textHigh : DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.tinySize
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    HoverHandler { id: openCollectionHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.routeRequested("library") }
                }
                DesktopLibraryMarquee {
                    x: 0
                    y: 30
                    width: parent.width
                    height: 94
                    games: root.takeGames(root.games, 0, 10)
                    active: root.active
                    onGameRequested: game => root.openGame(game)
                }
            }

            Item {
                id: jumpRail
                width: parent.width
                height: 30 + root.homeTileHeight
                Text { text: qsTr("Jump back in"); color: "#FFFFFF"; font.family: Theme.displayFont; font.pixelSize: 16; font.weight: Font.Black; font.letterSpacing: -0.2 }
                Row {
                    objectName: "desktopHomeIconGuide"
                    anchors.right: seeJumpLabel.left; anchors.rightMargin: 16; y: 1
                    spacing: 5
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12
                        source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-info.svg"
                        sourceSize: Qt.size(32, 32)
                    }
                    Text {
                        text: qsTr("What the icons mean")
                        color: iconGuideHover.hovered ? Qt.lighter(Theme.focus, 1.2) : Theme.focus
                        font.family: Theme.bodyFont; font.pixelSize: 11; font.weight: Font.Bold
                    }
                    HoverHandler { id: iconGuideHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: AppController.showOverlay("desktop-icon-guide") }
                }
                Text {
                    id: seeJumpLabel
                    anchors.right: parent.right; y: 1
                    text: root.games.length > 0 ? qsTr("See all %1  ›").arg(root.games.length) : qsTr("See all  ›")
                    color: seeJump.hovered ? "#B8FFFFFF" : "#80FFFFFF"
                    font.family: Theme.bodyFont; font.pixelSize: 11; font.weight: Font.Bold
                    HoverHandler { id: seeJump; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.routeRequested("library") }
                }
                Row {
                    y: 30; width: parent.width; spacing: root.railGap
                    Repeater {
                        model: root.takeGames(root.jumpGames, 0, root.homeTileCount)
                        DesktopHomePoster {
                            required property var modelData
                            required property int index
                            game: modelData
                            tileWidth: root.homeTileWidth
                            tileHeight: root.homeTileHeight
                            current: root.focusZone === 1 && root.focusIndex === index
                            onPointed: root.setSelection(1, index)
                            onActivated: root.openGame(modelData)
                            onPlayRequested: root.playRequested(modelData)
                        }
                    }
                }
            }

            Item {
                id: playingRail
                width: parent.width
                height: 30 + root.homeTileHeight
                Text { text: qsTr("Favourites"); color: "#FFFFFF"; font.family: Theme.displayFont; font.pixelSize: 16; font.weight: Font.Black; font.letterSpacing: -0.2 }
                Text {
                    anchors.right: parent.right; y: 1
                    text: qsTr("See all  ›")
                    color: seeFriends.hovered ? "#B8FFFFFF" : "#80FFFFFF"
                    font.family: Theme.bodyFont; font.pixelSize: 11; font.weight: Font.Bold
                    HoverHandler { id: seeFriends; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.routeRequested("library") }
                }
                Row {
                    y: 30; width: parent.width; spacing: root.railGap
                    Repeater {
                        model: root.takeGames(root.favoriteGames, 0, root.homeTileCount)
                        DesktopHomePoster {
                            required property var modelData
                            required property int index
                            game: modelData
                            tileWidth: root.homeTileWidth
                            tileHeight: root.homeTileHeight
                            current: root.focusZone === 2 && root.focusIndex === index
                            onPointed: root.setSelection(2, index)
                            onActivated: root.openGame(modelData)
                            onPlayRequested: root.playRequested(modelData)
                        }
                    }
                }
            }

            Item {
                id: newRail
                width: parent.width
                height: 30 + root.homeTileHeight
                Text { text: qsTr("New in your library"); color: "#FFFFFF"; font.family: Theme.displayFont; font.pixelSize: 16; font.weight: Font.Black; font.letterSpacing: -0.2 }
                Text {
                    anchors.right: parent.right; y: 1
                    text: qsTr("See all  ›")
                    color: seeNew.hovered ? "#B8FFFFFF" : "#80FFFFFF"
                    font.family: Theme.bodyFont; font.pixelSize: 11; font.weight: Font.Bold
                    HoverHandler { id: seeNew; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.routeRequested("library") }
                }
                Row {
                    y: 30; width: parent.width; spacing: root.railGap
                    Repeater {
                        model: root.takeGames(root.newGames, 0, root.homeTileCount)
                        DesktopHomePoster {
                            required property var modelData
                            required property int index
                            game: modelData
                            tileWidth: root.homeTileWidth
                            tileHeight: root.homeTileHeight
                            current: root.focusZone === 3 && root.focusIndex === index
                            onPointed: root.setSelection(3, index)
                            onActivated: root.openGame(modelData)
                            onPlayRequested: root.playRequested(modelData)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.focusZone = 0
        root.focusIndex = Math.max(0, Math.min(1, ShellStore.focusIndex("desktop-home")))
        if (root.active)
            Qt.callLater(root.forceActiveFocus)
    }
    onFocusIndexChanged: ShellStore.rememberFocus("desktop-home", focusIndex)
}
