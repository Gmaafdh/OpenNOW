import QtQuick
import QtQuick.Controls
import QtQuick.Window
import OpenNOW

// Halo sidebar. A translucent spine that keeps only icons when it rests and
// glides open on hover. The active route owns an accent halo; everything else
// is quiet type on glass.
FocusScope {
    id: root
    objectName: "desktopSidebar"
    property string currentRoute: "home"
    property bool collapsed: true
    property bool hoverExpanded: false
    readonly property bool overlayOpen: !collapsed || hoverExpanded
    readonly property bool compact: !overlayOpen
    readonly property real reveal: Math.max(0, Math.min(1, (width - DesktopTokens.railCollapsedWidth) / (DesktopTokens.railWidth - DesktopTokens.railCollapsedWidth)))
    readonly property bool consoleModeOn: DesktopTokens.consoleModeOn(Window.window)
    readonly property bool consoleModePending: DesktopTokens.consoleModePending(Window.window)
    readonly property bool friendsAvailable: Boolean(ShellStore.socialCapabilities && ShellStore.socialCapabilities.friendsAvailable)
    signal routeRequested(string route)
    signal consoleModeRequested()
    signal collapseRequested(bool collapsed)
    signal createCollectionRequested()
    signal accountSwitcherRequested()

    x: 0
    width: overlayOpen ? DesktopTokens.railWidth : DesktopTokens.railCollapsedWidth
    height: parent ? parent.height : 900
    z: overlayOpen ? 40 : 3

    function closeOverlay() {
        hoverExpanded = false
    }

    Behavior on width {
        NumberAnimation { duration: AppController.reducedMotion ? 0 : DesktopTokens.morphDuration; easing.type: Easing.Bezier; easing.bezierCurve: DesktopTokens.easeSleek }
    }

    readonly property var navItems: [
        { route: "home", icon: "desktop-nav-home.svg", name: qsTr("Home"), hint: qsTr("Library picks") },
        { route: "library", icon: "desktop-nav-library.svg", name: qsTr("Library"), hint: qsTr("All your games") },
        { route: "store", icon: "desktop-nav-store.svg", name: qsTr("Store"), hint: qsTr("Browse GeForce NOW") },
        { route: "friends", icon: "desktop-nav-friends.svg", name: qsTr("Friends"), hint: qsTr("Play together") },
        { route: "settings", icon: "desktop-nav-settings.svg", name: qsTr("Settings"), hint: qsTr("Stream and app") }
    ]

    function liveMembershipTier() {
        // The login claim goes stale (e.g. upgrade after sign-in); the live
        // subscription is authoritative, the cached claim is the fallback.
        if (ShellStore.subscription && ShellStore.subscription.membershipTier)
            return String(ShellStore.subscription.membershipTier).toUpperCase()
        if (ShellStore.signedIn && ShellStore.authSession && ShellStore.authSession.user
                && ShellStore.authSession.user.membershipTier)
            return String(ShellStore.authSession.user.membershipTier).toUpperCase()
        return ShellStore.signedIn ? qsTr("Member").toUpperCase() : qsTr("NOT SIGNED IN")
    }

    function routeSelected(route) {
        if (route === "settings")
            return root.currentRoute.indexOf("settings") === 0
        if (route === "library")
            return root.currentRoute === "library" || root.currentRoute === "game-detail"
        return root.currentRoute === route
    }

    // Glass spine --------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(DesktopTokens.shell.r, DesktopTokens.shell.g, DesktopTokens.shell.b,
                               Theme.lightMode ? 0.94 : 0.88)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(DesktopTokens.shell.r, DesktopTokens.shell.g, DesktopTokens.shell.b,
                               Theme.lightMode ? 0.90 : 0.78)
            }
        }

        // Accent light bleeding in from the top of the rail.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: DesktopTokens.px(220)
            opacity: 0.5
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.12) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: root.overlayOpen ? DesktopTokens.hairline : DesktopTokens.hairlineSoft
            Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
        }
    }

    // Cast shadow when the rail floats above the content.
    Rectangle {
        visible: root.overlayOpen
        x: root.width
        width: DesktopTokens.px(36)
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.lightMode ? "#1A0B0F1A" : "#8C000000" }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    HoverHandler {
        acceptedDevices: PointerDevice.Mouse
        enabled: !SmokeTestMode && ShellStore.settings.desktopSidebarHover !== false
        onHoveredChanged: root.hoverExpanded = root.collapsed && hovered && ShellStore.settings.desktopSidebarHover !== false
    }

    Item {
        anchors.fill: parent
        clip: true
        anchors.topMargin: DesktopTokens.px(14)
        anchors.leftMargin: DesktopTokens.px(12)
        anchors.rightMargin: DesktopTokens.px(12)
        anchors.bottomMargin: DesktopTokens.px(12)

        Flickable {
            id: railFlick
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: dock.top
            anchors.bottomMargin: DesktopTokens.px(10)
            clip: true
            contentWidth: width
            contentHeight: topColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: topColumn
                width: railFlick.width
                spacing: DesktopTokens.px(12)

                // Brand ------------------------------------------------------
                Item {
                    width: parent.width
                    height: DesktopTokens.px(34)

                    DesktopBrandLockup {
                        id: brand
                        anchors.verticalCenter: parent.verticalCenter
                        x: DesktopTokens.px(6)
                        markHeight: DesktopTokens.px(24)
                        fontPixelSize: DesktopTokens.px(18)
                        spacing: DesktopTokens.px(10)
                        textReveal: root.reveal
                    }

                    // The mark reads on its own when the rail is at rest.
                    Rectangle {
                        visible: root.compact
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: DesktopTokens.px(38)
                        height: DesktopTokens.px(30)
                        radius: DesktopTokens.radiusSm
                        color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.12)
                        Rectangle {
                            anchors.centerIn: parent
                            width: DesktopTokens.px(22)
                            height: width
                            radius: width / 2
                            color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.10)
                        }
                    }

                    Rectangle {
                        id: collapseButton
                        visible: root.overlayOpen
                        width: DesktopTokens.px(26)
                        height: DesktopTokens.px(26)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        radius: DesktopTokens.radiusXs
                        color: collapseHover.hovered ? DesktopTokens.fillRaised : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Collapse sidebar")
                        Accessible.onPressAction: {
                            root.hoverExpanded = false
                            root.collapseRequested(true)
                        }
                        DesktopGlyph {
                            anchors.centerIn: parent
                            width: DesktopTokens.px(12)
                            height: width
                            icon: "desktop-collapse.svg"
                            opacity: collapseHover.hovered ? 1 : 0.7
                        }
                        HoverHandler { id: collapseHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                root.hoverExpanded = false
                                root.collapseRequested(true)
                            }
                        }
                    }
                }

                // Navigation -------------------------------------------------
                Column {
                    width: parent.width
                    spacing: DesktopTokens.px(3)

                    Repeater {
                        model: root.navItems
                        delegate: ItemDelegate {
                            id: navButton
                            required property var modelData
                            width: parent.width
                            height: DesktopTokens.px(44)
                            padding: 0
                            hoverEnabled: true
                            readonly property bool selected: root.routeSelected(modelData.route)
                            readonly property real lift: hovered || activeFocus ? 1 : 0
                            Accessible.name: modelData.name
                            Accessible.description: modelData.hint

                            background: Item {
                                // Accent halo behind the active route.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.rightMargin: DesktopTokens.px(2)
                                    radius: DesktopTokens.radiusSm
                                    visible: navButton.selected
                                    color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g,
                                                   DesktopTokens.focus.b, Theme.lightMode ? 0.14 : 0.16)
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.rightMargin: DesktopTokens.px(2)
                                    radius: DesktopTokens.radiusSm
                                    color: navButton.selected
                                        ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g,
                                                  DesktopTokens.focus.b, 0.10)
                                        : DesktopTokens.fillRaised
                                    opacity: navButton.selected ? 1 : navButton.lift
                                    border.width: 1
                                    border.color: navButton.selected
                                        ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g,
                                                  DesktopTokens.focus.b, 0.28)
                                        : DesktopTokens.hairlineSoft
                                    Behavior on opacity { NumberAnimation { duration: DesktopTokens.hoverDuration } }
                                }
                            }

                            contentItem: Item {
                                Item {
                                    // Collapsed rail: the icon sits dead centre in a halo.
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.compact ? parent.width : DesktopTokens.px(46)
                                    height: parent.height

                                    DesktopGlyph {
                                        objectName: "sidebarIcon-" + navButton.modelData.route
                                        anchors.centerIn: parent
                                        width: DesktopTokens.px(19)
                                        height: width
                                        icon: navButton.modelData.icon
                                        active: navButton.selected
                                        scale: navButton.lift === 1 && !AppController.reducedMotion && !navButton.selected ? 1.06 : 1
                                        Behavior on scale { NumberAnimation { duration: DesktopTokens.hoverDuration; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Column {
                                    x: DesktopTokens.px(46)
                                    width: Math.max(0, parent.width - x - DesktopTokens.px(18))
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.reveal > 0
                                    opacity: root.reveal
                                    spacing: DesktopTokens.px(1)

                                    Text {
                                        width: parent.width
                                        text: navButton.modelData.name
                                        elide: Text.ElideRight
                                        color: navButton.selected ? DesktopTokens.textHigh : DesktopTokens.textBody
                                        font.family: DesktopTokens.bodyFont
                                        font.pixelSize: DesktopTokens.px(14)
                                        font.weight: navButton.selected ? Font.Bold : Font.Medium
                                        font.letterSpacing: 0.1
                                    }
                                    Text {
                                        width: parent.width
                                        visible: navButton.selected || navButton.hovered
                                        text: navButton.modelData.hint
                                        elide: Text.ElideRight
                                        color: DesktopTokens.textFaint
                                        font.family: DesktopTokens.bodyFont
                                        font.pixelSize: DesktopTokens.microSize
                                        opacity: navButton.hovered ? 1 : 0.8
                                    }
                                }

                                // Friends presence dot / active route marker.
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: DesktopTokens.px(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: navButton.modelData.route === "friends" && !navButton.selected
                                    width: DesktopTokens.px(6)
                                    height: width
                                    radius: width / 2
                                    color: root.friendsAvailable ? DesktopTokens.mint : DesktopTokens.textFaint
                                }

                                // Selected route marker: a small accent dot reads
                                // as a state, where an edge bar reads as a
                                // scrollbar.
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: DesktopTokens.px(13)
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: navButton.selected && !root.compact
                                    width: DesktopTokens.px(6)
                                    height: width
                                    radius: width / 2
                                    color: DesktopTokens.focus
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: DesktopTokens.px(12)
                                        height: width
                                        radius: width / 2
                                        z: -1
                                        color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g,
                                                       DesktopTokens.focus.b, 0.22)
                                    }
                                }
                            }

                            onClicked: {
                                if (modelData.route === "library")
                                    ShellStore.activeCollectionId = ""
                                root.routeRequested(modelData.route)
                            }
                        }
                    }
                }

                // Collections ------------------------------------------------
                Item {
                    width: parent.width
                    height: DesktopTokens.px(30)

                    Rectangle {
                        x: DesktopTokens.px(8)
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.compact ? 0 : DesktopTokens.px(18)
                        height: 1
                        color: DesktopTokens.hairline
                    }
                    Text {
                        x: DesktopTokens.px(34)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.reveal > 0
                        opacity: root.reveal * 0.9
                        text: qsTr("COLLECTIONS")
                        color: DesktopTokens.textFaint
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.tinySize
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        font.capitalization: Font.AllUppercase
                    }
                    Rectangle {
                        id: createCollectionButton
                        objectName: "createCollectionButton"
                        anchors.right: parent.right
                        anchors.rightMargin: DesktopTokens.px(4)
                        anchors.verticalCenter: parent.verticalCenter
                        width: DesktopTokens.px(26)
                        height: DesktopTokens.px(26)
                        radius: DesktopTokens.radiusXs
                        visible: root.reveal > 0
                        opacity: root.reveal * (collectionHover.hovered ? 1 : 0.65)
                        enabled: root.overlayOpen && !ShellStore.collectionsBusy
                        color: collectionHover.hovered ? DesktopTokens.fillRaised : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("New collection")
                        ToolTip.visible: collectionHover.hovered
                        ToolTip.text: qsTr("New collection")
                        ToolTip.delay: 400
                        DesktopGlyph {
                            anchors.centerIn: parent
                            width: DesktopTokens.px(12)
                            height: width
                            icon: "desktop-plus.svg"
                        }
                        HoverHandler { id: collectionHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.createCollectionRequested() }
                    }
                }

                Column {
                    id: collectionRows
                    width: parent.width
                    visible: height > 0
                    height: Math.max(0, implicitHeight * root.reveal)
                    clip: true
                    spacing: DesktopTokens.px(1)

                    Repeater {
                        model: ShellStore.gameCollections
                        delegate: ItemDelegate {
                            id: collectionRow
                            required property var modelData
                            width: parent.width
                            height: DesktopTokens.px(34)
                            padding: 0
                            hoverEnabled: true
                            opacity: root.reveal
                            enabled: root.overlayOpen
                            Accessible.name: modelData.name
                            background: Rectangle {
                                anchors.rightMargin: DesktopTokens.px(2)
                                radius: DesktopTokens.radiusXs
                                color: ShellStore.activeCollectionId === collectionRow.modelData.id && root.currentRoute === "library"
                                    ? DesktopTokens.fillRaised
                                    : collectionRow.hovered || collectionRow.activeFocus ? DesktopTokens.fill : "transparent"
                                border.width: ShellStore.activeCollectionId === collectionRow.modelData.id && root.currentRoute === "library" ? 1 : 0
                                border.color: DesktopTokens.hairline
                            }
                            contentItem: Item {
                                DesktopGlyph {
                                    objectName: "sidebarCollectionIcon-" + collectionRow.modelData.id
                                    x: DesktopTokens.px(12)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: DesktopTokens.px(14)
                                    height: width
                                    icon: "desktop-folder.svg"
                                    opacity: collectionRow.hovered ? 1 : 0.7
                                }
                                Text {
                                    x: DesktopTokens.px(36)
                                    width: Math.max(0, parent.width - x - DesktopTokens.px(40))
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.reveal > 0
                                    text: collectionRow.modelData.name
                                    color: collectionRow.hovered ? DesktopTokens.textHigh : DesktopTokens.textBody
                                    font.family: DesktopTokens.bodyFont
                                    font.pixelSize: DesktopTokens.px(12.5)
                                    font.weight: Font.Medium
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: DesktopTokens.px(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.reveal > 0
                                    text: collectionRow.modelData.gameIds.length
                                    color: DesktopTokens.textFaint
                                    font.family: DesktopTokens.monoFont
                                    font.pixelSize: DesktopTokens.tinySize
                                    font.weight: Font.DemiBold
                                }
                            }
                            onClicked: {
                                ShellStore.activeCollectionId = modelData.id
                                root.routeRequested("library")
                                root.closeOverlay()
                            }
                        }
                    }

                    Text {
                        x: DesktopTokens.px(12)
                        width: parent.width - DesktopTokens.px(20)
                        visible: ShellStore.gameCollections.length === 0 && root.reveal > 0
                        text: qsTr("Create your first collection with +")
                        wrapMode: Text.WordWrap
                        color: DesktopTokens.textFaint
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.px(11)
                    }
                }
            }
        }

        // Dock -----------------------------------------------------------------
        Column {
            id: dock
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: DesktopTokens.px(8)

            // Console-mode bento card
            Rectangle {
                id: consoleCard
                width: parent.width
                height: root.compact ? DesktopTokens.px(44) : DesktopTokens.px(58)
                radius: DesktopTokens.radiusSm + DesktopTokens.px(1)
                color: root.consoleModeOn
                    ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.14)
                    : DesktopTokens.fill
                border.width: 1
                border.color: root.consoleModeOn
                    ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.30)
                    : DesktopTokens.hairlineSoft
                opacity: root.consoleModePending ? 0.7 : 1
                enabled: !root.consoleModePending
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Console mode")
                Accessible.description: root.consoleModePending
                    ? qsTr("Switching surfaces")
                    : (root.consoleModeOn ? qsTr("Console mode is on") : qsTr("Console mode is off"))
                Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
                Behavior on opacity { NumberAnimation { duration: DesktopTokens.quickDuration } }

                Rectangle {
                    id: consoleIconWell
                    width: DesktopTokens.px(28)
                    height: width
                    radius: DesktopTokens.radiusXs
                    x: DesktopTokens.px(9)
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.consoleModeOn
                        ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.22)
                        : DesktopTokens.fillRaised
                    DesktopGlyph {
                        anchors.centerIn: parent
                        width: DesktopTokens.px(16)
                        height: width
                        icon: "desktop-gamepad.svg"
                        active: root.consoleModeOn
                    }
                    // Compact rail: a live LED tells the whole story.
                    Rectangle {
                        visible: root.compact
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -DesktopTokens.px(3)
                        anchors.topMargin: -DesktopTokens.px(3)
                        width: DesktopTokens.px(7)
                        height: width
                        radius: width / 2
                        border.width: 1
                        border.color: DesktopTokens.shell
                        color: root.consoleModePending ? DesktopTokens.amber
                            : root.consoleModeOn ? DesktopTokens.mint : DesktopTokens.ledAmber
                    }
                }

                Column {
                    x: consoleIconWell.x + consoleIconWell.width + DesktopTokens.px(10)
                    width: Math.max(0, parent.width - x - DesktopTokens.px(14))
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.compact === false
                    spacing: DesktopTokens.px(3)

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.consoleModePending ? qsTr("Switching…") : qsTr("Console mode")
                        color: DesktopTokens.textHigh
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.px(12.5)
                        font.weight: Font.Bold
                    }
                    Row {
                        spacing: DesktopTokens.px(5)
                        Rectangle {
                            width: DesktopTokens.px(5)
                            height: width
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.consoleModePending ? DesktopTokens.amber
                                : root.consoleModeOn ? DesktopTokens.mint : DesktopTokens.ledAmber
                            SequentialAnimation on opacity {
                                running: root.consoleModePending
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 420 }
                                NumberAnimation { to: 1; duration: 420 }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.consoleModePending ? qsTr("SWITCHING")
                                : root.consoleModeOn ? qsTr("CONSOLE ON") : qsTr("GAMEPAD READY")
                            color: DesktopTokens.textMuted
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: DesktopTokens.tinySize
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                        }
                    }
                }

                // Sleepy toggle, revealed with the rail.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: DesktopTokens.px(9)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.compact === false
                    width: DesktopTokens.px(30)
                    height: DesktopTokens.px(17)
                    radius: width / 2
                    color: root.consoleModeOn
                        ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.85)
                        : DesktopTokens.fillRaised
                    border.width: 1
                    border.color: DesktopTokens.hairline
                    Rectangle {
                        x: root.consoleModeOn ? parent.width - width - 2 : 2
                        y: 2
                        width: DesktopTokens.px(12)
                        height: width
                        radius: width / 2
                        color: root.consoleModeOn ? DesktopTokens.inkOnAccent : "#D9FFFFFF"
                        Behavior on x { NumberAnimation { duration: DesktopTokens.hoverDuration; easing.type: Easing.OutCubic } }
                    }
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.consoleModeRequested() }
            }

            // Profile row
            Item {
                id: profileButton
                objectName: "sidebarProfileButton"
                width: parent.width
                height: DesktopTokens.px(54)
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Switch account")
                Accessible.description: ShellStore.signedIn && ShellStore.authSession.user
                    ? qsTr("Signed in as %1").arg(ShellStore.authSession.user.displayName) : ""
                Accessible.onPressAction: root.accountSwitcherRequested()

                Rectangle {
                    anchors.fill: parent
                    radius: DesktopTokens.radiusSm
                    color: profileHover.hovered ? DesktopTokens.fill : "transparent"
                    Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
                }

                DesktopAccountTile {
                    x: DesktopTokens.px(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(36)
                    visible: Boolean(ShellStore.signedIn && ShellStore.authSession && ShellStore.authSession.user)
                    account: visible ? {userId: ShellStore.authSession.user.userId, displayName: ShellStore.authSession.user.displayName} : null
                    tileSize: DesktopTokens.px(36)
                    cornerRadius: DesktopTokens.px(18)
                    avatarOnly: true
                    enabled: false
                }
                Rectangle {
                    x: DesktopTokens.px(4)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !Boolean(ShellStore.signedIn && ShellStore.authSession && ShellStore.authSession.user)
                    width: DesktopTokens.px(36)
                    height: width
                    radius: width / 2
                    color: DesktopTokens.fillRaised
                    border.width: 1
                    border.color: DesktopTokens.hairline
                    Text {
                        anchors.centerIn: parent
                        text: "?"
                        color: DesktopTokens.textHigh
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.monoSize
                        font.weight: Font.Black
                    }
                }

                // Presence pip on the avatar.
                Rectangle {
                    x: DesktopTokens.px(31)
                    y: DesktopTokens.px(11)
                    width: DesktopTokens.px(10)
                    height: width
                    radius: width / 2
                    visible: ShellStore.signedIn
                    color: DesktopTokens.mint
                    border.width: 2
                    border.color: DesktopTokens.shell
                }

                Column {
                    x: DesktopTokens.px(48)
                    width: Math.max(0, parent.width - x - DesktopTokens.px(26))
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.reveal > 0
                    opacity: root.reveal
                    spacing: DesktopTokens.px(2)
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: ShellStore.signedIn && ShellStore.authSession.user
                            ? ShellStore.authSession.user.displayName
                            : qsTr("Guest")
                        color: DesktopTokens.textHigh
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: DesktopTokens.captionSize
                        font.weight: Font.Bold
                    }
                    Text {
                        text: root.liveMembershipTier()
                        width: parent.width
                        elide: Text.ElideRight
                        color: DesktopTokens.focus
                        font.family: DesktopTokens.monoFont
                        font.pixelSize: DesktopTokens.px(9)
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                    }
                }
                DesktopGlyph {
                    anchors.right: parent.right
                    anchors.rightMargin: DesktopTokens.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.reveal > 0
                    opacity: root.reveal * 0.6
                    width: DesktopTokens.px(10)
                    height: width
                    rotation: 180
                    icon: "desktop-chevron-up.svg"
                }
                HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: ShellStore.signedIn ? root.accountSwitcherRequested() : root.routeRequested("settings-account")
                }
            }
        }
    }
}
