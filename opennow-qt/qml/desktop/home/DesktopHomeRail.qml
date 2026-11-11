pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomeRail — one PS5-style activity shelf.
// =============================================================================
//
// A rail is a titled horizontal shelf of activity cards: "Continue Playing",
// "Favourites", "New in Your Library", "More like …". Each rail owns its own
// horizontal scrolling, so the page never moves when the pointer crosses a
// card; only explicit keyboard/controller navigation scrolls, and then only
// far enough to reveal the focused card.
//
// Sections:
//   1. header      — icon, title, subtitle, count chip, icon-guide link,
//                    "See all" action
//   2. card shelf  — Flickable + Row of DesktopHomePoster cards
//   3. edges       — fades and chevrons, shown only when scrollable
//   4. empty state — dashed placeholder with a call to action
//   5. skeleton    — shimmering placeholders while the catalog syncs
//   6. hints       — keyboard affordance and accessibility metadata
// =============================================================================
Item {
    id: root
    objectName: "desktopHomeRail"

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    property string railTitle: ""
    property string railSubtitle: ""
    property string railIcon: ""
    property var games: []
    property int currentIndex: -1
    property bool active: true
    property bool loading: false
    property int tileWidth: DesktopTokens.px(132)
    property int tileHeight: DesktopTokens.px(214)
    /// "none" | "new" (badge the first cards) | "rank" (number every card).
    property string badgeMode: "none"
    property int newBadgeCount: 3
    property string emptyText: ""
    property string emptyActionLabel: ""
    property bool showIconGuide: false
    property bool showSeeAll: true
    property string seeAllRoute: "library"

    /// Local sort. "default" keeps the order the screen supplied; the other
    /// modes re-order inside the rail so a shelf can be scanned differently
    /// without touching the page model.
    property string sortMode: "default"
    readonly property var sortModes: ["default", "recent", "hours", "title"]

    /// Collapse hides the shelf but keeps its header, so a long home page can be
    /// shortened without losing the rail's place in the layout.
    property bool collapsed: false

    /// Accent used for the count chip and the focused card hint.
    property color railAccent: DesktopTokens.mint

    /// Title of the game the hero is featuring. The matching card gets the
    /// poster's `featured` echo, so a shelf shows which of its games is on the
    /// stage above without the screen tracking indices per rail.
    property string spotlightTitle: ""

    /// Entrance style handed to every card: "slide" lifts them in, "fade"
    /// crossfades, "none" skips it (used when a rail re-sorts while visible).
    property string revealMode: "slide"

    /// Show the thin scroll position track under the shelf.
    property bool showScrollTrack: true

    /// Animate programmatic shelf scrolling. Off under reduced motion and while
    /// the player is dragging, so the shelf never fights an active gesture.
    property bool animatedScroll: true

    signal sortRequested(string mode)
    signal collapseToggled(bool collapsed)

    signal pointed(int index)
    signal activated(var game)
    signal playRequested(var game)
    signal favoriteToggled(var game)
    signal seeAllRequested()
    signal iconGuideRequested()
    signal emptyActionRequested()

    // -------------------------------------------------------------------------
    // Derived state
    // -------------------------------------------------------------------------
    readonly property int gameCount: (games || []).length
    /// The model the shelf renders: sorted locally when sortMode asks for it.
    readonly property var sortedGames: {
        const list = (games || []).slice()
        if (sortMode === "recent")
            list.sort((left, right) => String(right.lastPlayed || "").localeCompare(String(left.lastPlayed || "")))
        else if (sortMode === "hours")
            list.sort((left, right) => Number(right.hoursPlayed || 0) - Number(left.hoursPlayed || 0))
        else if (sortMode === "title")
            list.sort((left, right) => String(left.title || "").localeCompare(String(right.title || "")))
        return list
    }
    readonly property string sortLabel: sortMode === "recent" ? qsTr("Recent")
        : sortMode === "hours" ? qsTr("Hours")
        : sortMode === "title" ? qsTr("A–Z") : qsTr("Default")
    readonly property int railGap: DesktopTokens.px(14)
    readonly property int headerHeight: DesktopTokens.px(34)
    readonly property int cardPitch: tileWidth + railGap
    readonly property bool motionOff: AppController.reducedMotion
    readonly property bool isEmpty: gameCount === 0 && !loading
    readonly property bool canScrollLeft: shelfFlick.contentX > 4
    readonly property bool canScrollRight: shelfFlick.contentX + shelfFlick.width < shelfFlick.contentWidth - 4
    /// 0..1 position of the shelf, and the fraction of it that is on screen.
    /// Both stay sane when the shelf is shorter than the viewport.
    readonly property real scrollSpan: Math.max(0, shelfFlick.contentWidth - shelfFlick.width)
    readonly property real scrollProgress: scrollSpan <= 0 ? 0 : Math.min(1, Math.max(0, shelfFlick.contentX / scrollSpan))
    readonly property real scrollThumb: scrollSpan <= 0 ? 1
        : Math.min(1, Math.max(0.12, shelfFlick.width / Math.max(1, shelfFlick.contentWidth)))
    /// Index of the spotlighted game inside the sorted model, -1 when absent.
    readonly property int spotlightIndex: {
        if (spotlightTitle === "")
            return -1
        const list = sortedGames
        for (let i = 0; i < list.length; ++i) {
            if (String(list[i].title || "") === spotlightTitle)
                return i
        }
        return -1
    }

    implicitHeight: headerHeight + (collapsed ? 0 : tileHeight + DesktopTokens.px(10))
    height: implicitHeight
    visible: gameCount > 0 || loading || emptyText !== ""
    Accessible.role: Accessible.List
    Accessible.name: railTitle
    Accessible.description: qsTr("%1 games, sorted by %2").arg(gameCount).arg(sortLabel)

    Behavior on height {
        NumberAnimation { duration: root.motionOff ? 0 : 240; easing.type: Easing.OutCubic }
    }

    function cycleSort() {
        const index = sortModes.indexOf(sortMode)
        const next = String(sortModes[(index + 1) % sortModes.length])
        sortMode = next
        root.sortRequested(next)
    }

    function toggleCollapsed() {
        collapsed = !collapsed
        root.collapseToggled(collapsed)
    }

    function badgeFor(index) {
        if (badgeMode === "rank")
            return String(index + 1).padStart(2, "0")
        if (badgeMode === "new" && index < newBadgeCount)
            return qsTr("NEW")
        return ""
    }

    // -------------------------------------------------------------------------
    // Scroll management — explicit navigation only
    // -------------------------------------------------------------------------
    readonly property bool scrollAnimates: animatedScroll && !motionOff && !shelfFlick.moving

    /// Single place that writes contentX, mirroring the dock. Every caller can
    /// pass a rough target; the clamp and the animation choice happen here.
    function setScroll(value) {
        const target = Math.max(0, Math.min(scrollSpan, value))
        if (Math.abs(target - shelfFlick.contentX) < 0.5)
            return
        if (root.scrollAnimates) {
            shelfAnimation.stop()
            shelfAnimation.from = shelfFlick.contentX
            shelfAnimation.to = target
            shelfAnimation.start()
        } else {
            shelfAnimation.stop()
            shelfFlick.contentX = target
        }
    }

    NumberAnimation {
        id: shelfAnimation
        target: shelfFlick
        property: "contentX"
        duration: 260
        easing.type: Easing.OutCubic
    }

    function ensureIndexVisible(index) {
        if (index < 0 || index >= gameCount || shelfFlick.width <= 0)
            return
        const cardLeft = index * root.cardPitch
        const cardRight = cardLeft + root.tileWidth
        const viewLeft = shelfFlick.contentX
        const viewRight = viewLeft + shelfFlick.width
        const margin = DesktopTokens.px(6)
        if (cardLeft < viewLeft + margin)
            root.setScroll(cardLeft - margin)
        else if (cardRight > viewRight - margin)
            root.setScroll(cardRight - shelfFlick.width + margin)
    }

    function scrollToStart() {
        root.setScroll(0)
    }

    function scrollToEnd() {
        root.setScroll(scrollSpan)
    }

    /// Centre a card without changing the selection, used when the hero stage
    /// spotlights a game that also lives on this shelf.
    function centerOn(index) {
        if (index < 0 || index >= gameCount || shelfFlick.width <= 0)
            return
        root.setScroll(index * root.cardPitch + root.tileWidth / 2 - shelfFlick.width / 2)
    }

    function nudge(direction) {
        const step = Math.max(1, Math.floor(shelfFlick.width / Math.max(1, root.cardPitch)))
        const target = Math.max(0, Math.min(gameCount - 1,
                                            (currentIndex < 0 ? 0 : currentIndex) + direction * step))
        root.pointed(target)
        root.ensureIndexVisible(target)
    }

    onCurrentIndexChanged: {
        if (AppController.inputMode !== "pointer")
            root.ensureIndexVisible(root.currentIndex)
    }
    onGamesChanged: Qt.callLater(root.ensureIndexVisible, root.currentIndex)
    onWidthChanged: Qt.callLater(root.ensureIndexVisible, root.currentIndex)

    // =========================================================================
    // 1. Header
    // =========================================================================
    Item {
        id: railHeader
        x: 0
        y: 0
        width: parent.width
        height: root.headerHeight

        DesktopGlyph {
            id: headerIcon
            visible: root.railIcon !== ""
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: DesktopTokens.px(15)
            height: DesktopTokens.px(15)
            icon: root.railIcon
        }

        Column {
            id: headerText
            anchors.left: parent.left
            anchors.leftMargin: root.railIcon !== "" ? DesktopTokens.px(23) : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Row {
                spacing: DesktopTokens.px(8)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.railTitle
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: DesktopTokens.headingSize
                    font.weight: Font.Black
                    font.letterSpacing: -0.3
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.gameCount > 0
                    width: countLabel.implicitWidth + DesktopTokens.px(12)
                    height: DesktopTokens.px(18)
                    radius: DesktopTokens.px(9)
                    color: DesktopTokens.raised
                    border.width: 1
                    border.color: DesktopTokens.seam

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: String(root.gameCount)
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.microSize
                        font.weight: Font.Bold
                    }
                }
            }

            Text {
                visible: root.railSubtitle !== ""
                text: root.railSubtitle
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.tinySize
                font.weight: Font.DemiBold
            }
        }

        // Icon guide link — explains the launcher/feature pills on the cards.
        Item {
            id: iconGuideLink
            visible: root.showIconGuide
            anchors.right: seeAllLink.left
            anchors.rightMargin: DesktopTokens.px(18)
            anchors.verticalCenter: parent.verticalCenter
            width: guideRow.implicitWidth
            height: DesktopTokens.px(22)

            Row {
                id: guideRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: DesktopTokens.px(5)

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(12)
                    height: DesktopTokens.px(12)
                    source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-info.svg"
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("What the icons mean")
                    color: guideHover.hovered ? Qt.lighter(Theme.focus, 1.2) : Theme.focus
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.Bold
                }
            }

            HoverHandler { id: guideHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.iconGuideRequested() }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("What the icons mean")
            Accessible.onPressAction: root.iconGuideRequested()
        }

        Rectangle {
            id: sortChip
            objectName: "desktopHomeRailSort"
            visible: root.gameCount > 1 && !root.collapsed
            anchors.right: collapseButton.left
            anchors.rightMargin: DesktopTokens.px(8)
            anchors.verticalCenter: parent.verticalCenter
            width: sortRow.implicitWidth + DesktopTokens.px(16)
            height: DesktopTokens.px(22)
            radius: DesktopTokens.px(11)
            color: sortHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam
            Behavior on color { ColorAnimation { duration: 140 } }

            Row {
                id: sortRow
                anchors.centerIn: parent
                spacing: DesktopTokens.px(5)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("SORT")
                    color: DesktopTokens.textFaint
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.Bold
                    font.letterSpacing: 0.9
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sortLabel
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.ExtraBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⇅"
                    color: root.railAccent
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.Bold
                }
            }

            HoverHandler { id: sortHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.cycleSort() }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Sort %1 by %2").arg(root.railTitle).arg(root.sortLabel)
            Accessible.onPressAction: root.cycleSort()
        }

        Rectangle {
            id: collapseButton
            objectName: "desktopHomeRailCollapse"
            anchors.right: iconGuideLink.visible ? iconGuideLink.left : seeAllLink.left
            anchors.rightMargin: DesktopTokens.px(8)
            anchors.verticalCenter: parent.verticalCenter
            width: DesktopTokens.px(22)
            height: DesktopTokens.px(22)
            radius: DesktopTokens.px(11)
            color: collapseHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam

            Text {
                anchors.centerIn: parent
                text: root.collapsed ? "+" : "–"
                color: DesktopTokens.textHigh
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.px(13)
                font.weight: Font.Black
            }

            HoverHandler { id: collapseHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.toggleCollapsed() }
            Accessible.role: Accessible.Button
            Accessible.name: root.collapsed ? qsTr("Expand %1").arg(root.railTitle)
                                            : qsTr("Collapse %1").arg(root.railTitle)
            Accessible.onPressAction: root.toggleCollapsed()
        }

        Item {
            id: seeAllLink
            visible: root.showSeeAll
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: seeAllRow.implicitWidth + DesktopTokens.px(10)
            height: DesktopTokens.px(24)

            Rectangle {
                anchors.fill: parent
                radius: DesktopTokens.px(12)
                color: seeAllHover.hovered ? DesktopTokens.raisedStrong : "transparent"
                border.width: 1
                border.color: seeAllHover.hovered ? DesktopTokens.seam : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Row {
                id: seeAllRow
                anchors.centerIn: parent
                spacing: DesktopTokens.px(4)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("See all")
                    color: seeAllHover.hovered ? DesktopTokens.textHigh : DesktopTokens.textMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.Bold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: seeAllHover.hovered ? DesktopTokens.textHigh : DesktopTokens.textMuted
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: DesktopTokens.px(14)
                    font.weight: Font.Black
                }
            }

            HoverHandler { id: seeAllHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.seeAllRequested() }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("See all %1").arg(root.railTitle)
            Accessible.onPressAction: root.seeAllRequested()
        }
    }

    // =========================================================================
    // 2. Card shelf
    // =========================================================================
    Flickable {
        id: shelfFlick
        objectName: "desktopHomeRailShelf"
        x: 0
        y: root.headerHeight
        width: parent.width
        height: root.tileHeight + DesktopTokens.px(10)
        contentWidth: Math.max(width, cardRow.implicitWidth + DesktopTokens.px(10))
        contentHeight: height
        clip: true
        interactive: !root.isEmpty
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 5200
        maximumFlickVelocity: 2200
        visible: !root.isEmpty && !root.collapsed
        Accessible.role: Accessible.Pane
        Accessible.name: qsTr("%1 cards").arg(root.railTitle)

        // No Behaviour on contentX: setScroll() owns programmatic animation so
        // that animatedScroll and reduced motion are honoured in one place.

        Row {
            id: cardRow
            x: 0
            y: DesktopTokens.px(5)
            spacing: root.railGap

            Repeater {
                model: root.sortedGames
                DesktopHomePoster {
                    required property var modelData
                    required property int index
                    game: modelData
                    tileWidth: root.tileWidth
                    tileHeight: root.tileHeight
                    current: root.active && root.currentIndex === index
                    revealIndex: index
                    revealMode: root.revealMode
                    featured: root.spotlightIndex === index
                    badgeText: root.badgeFor(index)
                    onPointed: root.pointed(index)
                    onActivated: root.activated(modelData)
                    onPlayRequested: root.playRequested(modelData)
                    onFavoriteToggled: root.favoriteToggled(modelData)
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Scroll position track. Long shelves give no sense of how much is left, so
    // the rail draws a proportional thumb under the cards. It is deliberately
    // not interactive: dragging it would fight the card flickable.
    // -------------------------------------------------------------------------
    Item {
        id: scrollTrack
        x: 0
        y: shelfFlick.y + shelfFlick.height + DesktopTokens.px(4)
        width: parent.width
        height: DesktopTokens.px(3)
        visible: root.showScrollTrack && !root.collapsed && !root.isEmpty && root.scrollSpan > 0
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 160 } }

        Rectangle {
            anchors.fill: parent
            radius: DesktopTokens.px(1.5)
            color: Theme.lightMode ? "#14040610" : "#1AFFFFFF"
        }
        Rectangle {
            id: scrollThumb
            radius: DesktopTokens.px(1.5)
            height: parent.height
            width: Math.max(DesktopTokens.px(24), scrollTrack.width * root.scrollThumb)
            x: (scrollTrack.width - width) * root.scrollProgress
            color: root.canScrollLeft || root.canScrollRight ? root.railAccent : DesktopTokens.seam
            Behavior on x {
                NumberAnimation { duration: root.motionOff ? 0 : 180; easing.type: Easing.OutCubic }
            }
            Accessible.role: Accessible.Indicator
            Accessible.name: qsTr("Shelf position %1%").arg(Math.round(root.scrollProgress * 100))
        }
    }

    // =========================================================================
    // 3. Edges
    // =========================================================================
    Rectangle {
        x: 0
        y: shelfFlick.y
        width: DesktopTokens.px(30)
        height: shelfFlick.height
        visible: root.canScrollLeft && !root.collapsed
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.lightMode ? "#F4F7FB" : "#060911" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors.right: parent.right
        y: shelfFlick.y
        width: DesktopTokens.px(30)
        height: shelfFlick.height
        visible: root.canScrollRight && !root.collapsed
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.lightMode ? "#F4F7FB" : "#060911" }
        }
    }

    component RailChevron: Rectangle {
        id: chevron
        property bool chevronRight: true
        width: DesktopTokens.px(32)
        height: DesktopTokens.px(32)
        radius: DesktopTokens.px(16)
        color: chevronHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
        border.width: 1
        border.color: DesktopTokens.seam
        scale: chevronTap.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: chevron.chevronRight ? "›" : "‹"
            color: DesktopTokens.textHigh
            font.family: DesktopTokens.displayFont
            font.pixelSize: DesktopTokens.px(19)
            font.weight: Font.Black
        }

        HoverHandler { id: chevronHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: chevronTap
            onTapped: root.nudge(chevron.chevronRight ? 1 : -1)
        }
        Accessible.role: Accessible.Button
        Accessible.name: chevron.chevronRight ? qsTr("Scroll %1 right").arg(root.railTitle)
                                              : qsTr("Scroll %1 left").arg(root.railTitle)
        Accessible.onPressAction: root.nudge(chevron.chevronRight ? 1 : -1)
    }

    RailChevron {
        anchors.right: parent.right
        anchors.rightMargin: DesktopTokens.px(6)
        y: shelfFlick.y + (shelfFlick.height - height) / 2
        chevronRight: true
        visible: root.canScrollRight && !root.collapsed
        z: 40
    }

    RailChevron {
        anchors.left: parent.left
        anchors.leftMargin: DesktopTokens.px(6)
        y: shelfFlick.y + (shelfFlick.height - height) / 2
        chevronRight: false
        visible: root.canScrollLeft && !root.collapsed
        z: 40
    }

    // =========================================================================
    // 4. Empty state
    // =========================================================================
    Rectangle {
        id: emptyState
        x: 0
        y: root.headerHeight
        width: parent.width
        height: root.tileHeight
        radius: DesktopTokens.px(16)
        color: DesktopTokens.raised
        border.width: 1
        border.color: DesktopTokens.seam
        visible: root.isEmpty && root.emptyText !== "" && !root.collapsed

        Column {
            anchors.centerIn: parent
            width: parent.width - DesktopTokens.px(56)
            spacing: DesktopTokens.px(8)

            DesktopGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.railIcon !== ""
                width: DesktopTokens.px(22)
                height: DesktopTokens.px(22)
                icon: root.railIcon
                opacity: 0.6
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.emptyText
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.emptyActionLabel !== ""
                width: emptyActionLabel.implicitWidth + DesktopTokens.px(22)
                height: DesktopTokens.px(30)
                radius: DesktopTokens.px(15)
                color: emptyActionHover.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
                border.width: 1
                border.color: DesktopTokens.seam

                Text {
                    id: emptyActionLabel
                    anchors.centerIn: parent
                    text: root.emptyActionLabel
                    color: DesktopTokens.textHigh
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                    font.weight: Font.ExtraBold
                }

                HoverHandler { id: emptyActionHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.emptyActionRequested() }
                Accessible.role: Accessible.Button
                Accessible.name: root.emptyActionLabel
                Accessible.onPressAction: root.emptyActionRequested()
            }
        }
    }

    // =========================================================================
    // 5. Skeleton while syncing
    // =========================================================================
    Row {
        id: skeletonRow
        x: 0
        y: root.headerHeight + DesktopTokens.px(5)
        spacing: root.railGap
        visible: root.loading && root.gameCount === 0 && !root.collapsed
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Repeater {
            model: 6
            Rectangle {
                required property int index
                width: root.tileWidth
                height: root.tileHeight
                radius: DesktopTokens.px(14)
                color: Theme.lightMode ? "#14040610" : "#1AFFFFFF"

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: skeletonRow.visible && !root.motionOff
                    NumberAnimation { from: 0.35; to: 0.7; duration: 850; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.7; to: 0.35; duration: 850; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // =========================================================================
    // 6. Hints
    // =========================================================================
    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        visible: root.gameCount > 0 && !root.collapsed && AppController.inputMode !== "pointer"
        text: qsTr("← → scroll the shelf · Enter opens the card")
        color: Theme.lightMode ? "#8A0B1220" : "#59FFFFFF"
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.microSize
        font.letterSpacing: 0.5
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        visible: root.gameCount > 0 && !root.collapsed && AppController.inputMode !== "pointer" && root.currentIndex >= 0
        text: qsTr("Card %1 of %2").arg(root.currentIndex + 1).arg(root.gameCount)
        color: Theme.lightMode ? "#8A0B1220" : "#66FFFFFF"
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.microSize
        font.letterSpacing: 0.5
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
}
