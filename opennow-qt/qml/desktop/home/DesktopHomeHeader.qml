pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomeHeader — the slim PS5-style strip above the hero.
// =============================================================================
//
// The shell window already owns the app title, the library search field and the
// account switcher, so this strip is deliberately narrow: it greets the player,
// shows when the library was last refreshed, offers the Games / Library / Store
// tabs the PS5 home bar has, and surfaces the numbers that matter (games,
// pinned, hours, current stream quality).
//
// Sections:
//   1. greeting       — time-of-day greeting, date, member tier chip
//   2. tabs           — Games / Library / Store, pointer-driven duplicates of
//                       the sidebar routes with a live underline
//   3. stat pills     — games, pinned, hours, stream quality
//   4. quick actions  — refresh library, search (command palette), friends
//   5. sync bar       — progress line while a catalog refresh is in flight
//   6. accessibility  — roles, names and press actions for every control
// =============================================================================
Item {
    id: root
    objectName: "desktopHomeHeader"

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    property int totalGames: 0
    property int favoriteCount: 0
    property real totalHours: 0
    property string streamLabel: ""
    property string memberTier: ""
    property bool signedIn: false
    property bool syncing: false
    property bool active: true
    property string activeTab: "games"
    property bool friendsAvailable: false

    /// "comfortable" | "compact". Short windows use the compact strip so the
    /// hero and rails keep their on-screen space; nothing is dropped, only the
    /// type scale and the strip height shrink.
    property string density: "comfortable"
    /// When the library was last refreshed, for example "3 min ago". Empty
    /// hides the segment, which keeps the strip quiet on a first run.
    property string lastSyncedLabel: ""
    /// Title of the cloud session that is live right now, if any.
    property string nowPlayingTitle: ""

    signal libraryRequested()
    signal storeRequested()
    signal gamesRequested()
    signal searchRequested()
    signal syncRequested()
    signal friendsRequested()
    signal tabPointed(int index)

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    property date now: new Date()
    readonly property int hour: now.getHours()
    readonly property string greeting: hour < 5 ? qsTr("Still up")
        : hour < 12 ? qsTr("Good morning")
        : hour < 18 ? qsTr("Good afternoon")
        : qsTr("Good evening")
    readonly property string dateLabel: Qt.formatDate(now, qsTr("dddd, d MMMM"))
    readonly property string clockLabel: Qt.formatTime(now, "HH:mm")

    Timer {
        interval: 30000
        repeat: true
        running: root.active && root.visible
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Stop the refresh spinner cleanly when the sync finishes.
    onSyncingChanged: if (!syncing) syncGlyph.rotation = 0

    readonly property bool motionOff: AppController.reducedMotion
    readonly property var tabModel: [
        { id: "games", label: qsTr("Games"), icon: "desktop-nav-home.svg" },
        { id: "library", label: qsTr("Library"), icon: "desktop-nav-library.svg" },
        { id: "store", label: qsTr("Store"), icon: "desktop-nav-store.svg" }
    ]

    readonly property bool compact: density === "compact"
    readonly property bool sessionLive: nowPlayingTitle !== ""
    readonly property int greetingSize: DesktopTokens.px(compact ? 19 : 24)

    implicitHeight: DesktopTokens.px(compact ? 62 : 78)
    height: implicitHeight
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Home header")
    Accessible.description: sessionLive
        ? qsTr("%1 games, %2 pinned, %3. Now streaming %4.")
            .arg(totalGames).arg(favoriteCount).arg(streamLabel, nowPlayingTitle)
        : qsTr("%1 games, %2 pinned, %3.").arg(totalGames).arg(favoriteCount).arg(streamLabel)

    Behavior on implicitHeight {
        NumberAnimation { duration: root.motionOff ? 0 : 200; easing.type: Easing.OutCubic }
    }

    function activateTab(index) {
        if (index < 0 || index >= tabModel.length)
            return
        const id = String(tabModel[index].id)
        root.tabPointed(index)
        if (id === "library")
            root.libraryRequested()
        else if (id === "store")
            root.storeRequested()
        else
            root.gamesRequested()
    }

    // =========================================================================
    // 1. Greeting
    // =========================================================================
    Column {
        id: greetingBlock
        x: 0
        y: DesktopTokens.px(2)
        width: Math.min(DesktopTokens.px(root.compact ? 360 : 430), parent.width * 0.38)
        spacing: DesktopTokens.px(1)

        Row {
            width: parent.width
            spacing: DesktopTokens.px(9)

            Text {
                id: greetingText
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - clockChip.width - DesktopTokens.px(24))
                text: root.signedIn ? root.greeting : qsTr("Welcome to OpenNOW")
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.displayFont
                font.pixelSize: root.greetingSize
                font.weight: Font.Black
                font.letterSpacing: -0.6
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Member tier chip.
            Rectangle {
                id: clockChip
                anchors.verticalCenter: parent.verticalCenter
                visible: root.memberTier !== ""
                width: tierRow.implicitWidth + DesktopTokens.px(14)
                height: DesktopTokens.px(20)
                radius: DesktopTokens.px(10)
                color: DesktopTokens.raised
                border.width: 1
                border.color: DesktopTokens.seam

                Row {
                    id: tierRow
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(5)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(5)
                        height: DesktopTokens.px(5)
                        radius: DesktopTokens.px(2.5)
                        color: DesktopTokens.mint
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.memberTier
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                        font.letterSpacing: 0.9
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: DesktopTokens.px(7)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateLabel
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: DesktopTokens.px(9)
                color: DesktopTokens.seam
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.clockLabel
                color: DesktopTokens.textFaint
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.syncing
                width: 1
                height: DesktopTokens.px(9)
                color: DesktopTokens.seam
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.syncing
                text: qsTr("syncing…")
                color: DesktopTokens.ledAmber
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.Bold
                font.letterSpacing: 0.6
            }

            // Last completed refresh. Only shown when nothing is in flight, so
            // the two never compete for the same slot.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.syncing && root.lastSyncedLabel !== ""
                width: 1
                height: DesktopTokens.px(9)
                color: DesktopTokens.seam
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.syncing && root.lastSyncedLabel !== ""
                text: qsTr("synced %1").arg(root.lastSyncedLabel)
                color: DesktopTokens.textFaint
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("Library synced %1").arg(root.lastSyncedLabel)
            }

            // Live cloud session: a pulsing dot plus the title, so the header
            // keeps telling the truth while a stream is running in the shell.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.sessionLive
                width: 1
                height: DesktopTokens.px(9)
                color: DesktopTokens.seam
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.sessionLive
                width: DesktopTokens.px(6)
                height: DesktopTokens.px(6)
                radius: DesktopTokens.px(3)
                color: "#FF4B5B"

                SequentialAnimation on opacity {
                    running: root.sessionLive && root.active && !root.motionOff
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.25; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
                Accessible.role: Accessible.Indicator
                Accessible.name: qsTr("Streaming now")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.sessionLive
                width: Math.min(implicitWidth, DesktopTokens.px(root.compact ? 120 : 190))
                text: root.nowPlayingTitle
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("Now streaming %1").arg(root.nowPlayingTitle)
            }
        }
    }

    // =========================================================================
    // 2. Tabs
    // =========================================================================
    Row {
        id: tabRow
        anchors.left: greetingBlock.right
        anchors.leftMargin: DesktopTokens.px(26)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesktopTokens.px(8)

        Repeater {
            model: root.tabModel
            Rectangle {
                id: tab
                required property var modelData
                required property int index
                readonly property bool isCurrent: root.activeTab === modelData.id
                width: tabLabel.implicitWidth + tabIcon.width + DesktopTokens.px(34)
                height: DesktopTokens.px(36)
                radius: DesktopTokens.px(18)
                color: isCurrent ? (Theme.lightMode ? "#111827" : "#FFFFFF")
                    : tabHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
                border.width: 1
                border.color: isCurrent ? "transparent" : DesktopTokens.seam
                scale: tabTap.pressed ? 0.97 : 1
                Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: DesktopTokens.px(7)

                    DesktopGlyph {
                        id: tabIcon
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(14)
                        height: DesktopTokens.px(14)
                        icon: tab.modelData.icon
                        opacity: tab.isCurrent ? 1 : 0.72
                    }
                    Text {
                        id: tabLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        color: tab.isCurrent ? (Theme.lightMode ? "#FFFFFF" : "#0B0F1A") : DesktopTokens.textHigh
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.smallSize
                        font.weight: Font.ExtraBold
                    }
                }

                HoverHandler {
                    id: tabHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.tabPointed(tab.index)
                }
                TapHandler {
                    id: tabTap
                    onTapped: root.activateTab(tab.index)
                }
                Accessible.role: Accessible.Button
                Accessible.name: tab.modelData.label
                Accessible.onPressAction: root.activateTab(tab.index)
            }
        }
    }

    // =========================================================================
    // 3. Stat pills
    // =========================================================================
    Row {
        id: statRow
        anchors.right: quickActionRow.left
        anchors.rightMargin: DesktopTokens.px(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesktopTokens.px(8)

        Rectangle {
            width: gamesValue.implicitWidth + gamesLabel.implicitWidth + DesktopTokens.px(30)
            height: DesktopTokens.px(36)
            radius: DesktopTokens.px(18)
            color: DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam

            DesktopGlyph {
                id: gamesIcon
                x: DesktopTokens.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(13)
                height: DesktopTokens.px(13)
                icon: "desktop-nav-library.svg"
            }
            Text {
                id: gamesValue
                x: gamesIcon.x + gamesIcon.width + DesktopTokens.px(7)
                anchors.verticalCenter: parent.verticalCenter
                text: String(root.totalGames)
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.Black
            }
            Text {
                id: gamesLabel
                x: gamesValue.x + gamesValue.width + DesktopTokens.px(4)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("games")
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.DemiBold
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("%1 games in your library").arg(root.totalGames)
        }

        Rectangle {
            visible: root.favoriteCount > 0
            width: pinnedValue.implicitWidth + pinnedLabel.implicitWidth + DesktopTokens.px(30)
            height: DesktopTokens.px(36)
            radius: DesktopTokens.px(18)
            color: DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam

            DesktopGlyph {
                id: pinnedIcon
                x: DesktopTokens.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(13)
                height: DesktopTokens.px(13)
                icon: "desktop-star.svg"
            }
            Text {
                id: pinnedValue
                x: pinnedIcon.x + pinnedIcon.width + DesktopTokens.px(7)
                anchors.verticalCenter: parent.verticalCenter
                text: String(root.favoriteCount)
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.Black
            }
            Text {
                id: pinnedLabel
                x: pinnedValue.x + pinnedValue.width + DesktopTokens.px(4)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("pinned")
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.DemiBold
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("%1 pinned games").arg(root.favoriteCount)
        }

        Rectangle {
            visible: root.totalHours >= 1
            width: hoursValue.implicitWidth + hoursLabel.implicitWidth + DesktopTokens.px(30)
            height: DesktopTokens.px(36)
            radius: DesktopTokens.px(18)
            color: DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam

            DesktopGlyph {
                id: hoursIcon
                x: DesktopTokens.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(13)
                height: DesktopTokens.px(13)
                icon: "desktop-clock.svg"
            }
            Text {
                id: hoursValue
                x: hoursIcon.x + hoursIcon.width + DesktopTokens.px(7)
                anchors.verticalCenter: parent.verticalCenter
                text: String(Math.round(root.totalHours))
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.Black
            }
            Text {
                id: hoursLabel
                x: hoursValue.x + hoursValue.width + DesktopTokens.px(4)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("hours")
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.DemiBold
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("%1 hours played").arg(Math.round(root.totalHours))
        }

        Rectangle {
            visible: root.streamLabel !== ""
            width: streamIcon.width + streamValue.implicitWidth + DesktopTokens.px(26)
            height: DesktopTokens.px(36)
            radius: DesktopTokens.px(18)
            color: Theme.lightMode ? "#1456E6A5" : "#1F56E6A5"
            border.width: 1
            border.color: "#3356E6A5"

            DesktopGlyph {
                id: streamIcon
                x: DesktopTokens.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(13)
                height: DesktopTokens.px(13)
                icon: "desktop-play-stroke.svg"
            }
            Text {
                id: streamValue
                x: streamIcon.x + streamIcon.width + DesktopTokens.px(7)
                anchors.verticalCenter: parent.verticalCenter
                text: root.streamLabel
                color: DesktopTokens.flightMint
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.Bold
                font.letterSpacing: 0.6
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("Stream quality %1").arg(root.streamLabel)
        }
    }

    // =========================================================================
    // 4. Quick actions
    // =========================================================================
    Row {
        id: quickActionRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesktopTokens.px(8)

        Rectangle {
            id: syncAction
            width: DesktopTokens.px(36)
            height: DesktopTokens.px(36)
            radius: DesktopTokens.px(18)
            color: syncHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam
            scale: syncTap.pressed ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            DesktopGlyph {
                id: syncGlyph
                anchors.centerIn: parent
                width: DesktopTokens.px(15)
                height: DesktopTokens.px(15)
                icon: "desktop-collapse.svg"
            }

            NumberAnimation {
                id: spinAnimation
                target: syncGlyph
                property: "rotation"
                from: 0
                to: 360
                duration: 1400
                loops: Animation.Infinite
                running: root.syncing && !root.motionOff
            }

            HoverHandler { id: syncHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: syncTap
                onTapped: root.syncRequested()
            }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Refresh library")
            Accessible.onPressAction: root.syncRequested()

            // Spinner ring while a refresh is in flight.
            Rectangle {
                visible: root.syncing
                anchors.fill: parent
                anchors.margins: -DesktopTokens.px(2)
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: DesktopTokens.ledAmber
                opacity: 0.7

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.syncing && !root.motionOff
                    NumberAnimation { from: 0.25; to: 0.8; duration: 700 }
                    NumberAnimation { from: 0.8; to: 0.25; duration: 700 }
                }
            }
        }

        Rectangle {
            id: searchAction
            width: DesktopTokens.px(36)
            height: DesktopTokens.px(36)
            radius: DesktopTokens.px(18)
            color: searchHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam
            scale: searchTap.pressed ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(15)
                height: DesktopTokens.px(15)
                icon: "desktop-search.svg"
            }
            HoverHandler { id: searchHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: searchTap
                onTapped: root.searchRequested()
            }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Search games")
            Accessible.onPressAction: root.searchRequested()
        }

        Rectangle {
            id: friendsAction
            visible: root.friendsAvailable
            width: DesktopTokens.px(36)
            height: DesktopTokens.px(36)
            radius: DesktopTokens.px(18)
            color: friendsHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam
            scale: friendsTap.pressed ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            DesktopGlyph {
                anchors.centerIn: parent
                width: DesktopTokens.px(15)
                height: DesktopTokens.px(15)
                icon: "desktop-nav-friends.svg"
            }
            HoverHandler { id: friendsHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: friendsTap
                onTapped: root.friendsRequested()
            }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Friends")
            Accessible.onPressAction: root.friendsRequested()
        }
    }

    // =========================================================================
    // 5. Sync bar
    // =========================================================================
    Rectangle {
        id: syncBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: DesktopTokens.px(2)
        radius: DesktopTokens.px(1)
        color: DesktopTokens.seamSoft
        visible: root.syncing
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Rectangle {
            id: syncBarFill
            width: parent.width * 0.35
            height: parent.height
            radius: parent.radius
            color: DesktopTokens.mint

            SequentialAnimation on x {
                loops: Animation.Infinite
                running: root.syncing && !root.motionOff
                NumberAnimation { from: -syncBarFill.width; to: syncBar.width; duration: 1200; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 120 }
            }
        }
    }
}
