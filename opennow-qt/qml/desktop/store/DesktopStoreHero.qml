import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import OpenNOW

Item {
    id: root

    // Marquee slides from the CMS panels document:
    // {kind:"game"|"marketing", title, body, image, game?, actionLabel?}
    property var slides: []
    property int currentSlide: 0
    property int selectedAction: -1

    signal playRequested(var game)
    signal detailsRequested(var game)
    signal actionPointed(int index)

    width: 1160
    height: 260

    readonly property var slide: slides.length ? slides[Math.max(0, Math.min(currentSlide, slides.length - 1))] : null
    readonly property var slideGame: slide && slide.game ? slide.game : null

    function nextSlide() {
        if (slides.length > 1)
            currentSlide = (currentSlide + 1) % slides.length
    }

    onSlidesChanged: currentSlide = 0

    Timer {
        id: advanceTimer
        interval: 6000
        repeat: true
        running: root.visible && slides.length > 1 && !AppController.reducedMotion && !heroHover.hovered
        onTriggered: root.nextSlide()
    }

    // Keep the text's contrast backing outside the effect layer. Qt's software
    // renderer cannot draw MultiEffect masks, but must still show a readable hero.
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#0B0F1A"
    }

    Rectangle {
        id: heroMask
        anchors.fill: parent
        radius: 16
        color: "white"
        visible: false
        layer.enabled: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: heroMask
            maskThresholdMin: 0.25
            maskSpreadAtMin: 0.2
        }

        Repeater {
            model: root.slides
            Item {
                required property var modelData
                required property int index
                anchors.fill: parent
                visible: opacity > 0
                opacity: index === root.currentSlide ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: AppController.reducedMotion ? 0 : 450; easing.type: Easing.OutCubic } }

                Image {
                    x: Math.round(parent.width * 0.28)
                    width: parent.width - x
                    height: parent.height
                    source: DesktopTokens.decodeArtworkUrl(String(modelData.image || ""))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0.043, 0.059, 0.102, 0.96) }
                GradientStop { position: 0.45; color: Qt.rgba(0.043, 0.059, 0.102, 0.72) }
                GradientStop { position: 0.75; color: Qt.rgba(0.043, 0.059, 0.102, 0.12) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: DesktopTokens.radiusXl + 2
        color: "transparent"
        border.width: 1
        border.color: DesktopTokens.hairlineStrong
    }

    HoverHandler { id: heroHover }

    Column {
        x: 24
        y: 24
        width: Math.min(520, Math.max(300, root.width * 0.42))
        spacing: 10

        Rectangle {
            width: featuredRow.implicitWidth + DesktopTokens.px(20)
            height: DesktopTokens.px(24)
            radius: DesktopTokens.radiusPill
            color: Qt.rgba(0, 0, 0, 0.34)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)
            Row {
                id: featuredRow
                anchors.centerIn: parent
                spacing: DesktopTokens.px(7)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(5)
                    height: width
                    radius: width / 2
                    color: DesktopTokens.mint
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.slide && root.slide.kind === "marketing" ? qsTr("GeForce NOW") : qsTr("Featured")
                    color: "#FFFFFF"
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.microSize
                    font.weight: Font.Bold
                    font.letterSpacing: 1.0
                    font.capitalization: Font.AllUppercase
                }
            }
        }

        Text {
            width: parent.width
            text: root.slide ? String(root.slide.title || "") : ""
            color: "#FFFFFF"
            font.family: Theme.displayFont
            font.pixelSize: DesktopTokens.px(36)
            font.weight: Font.Black
            font.letterSpacing: -1.2
            style: Text.Raised
            styleColor: "#66000000"
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.slide ? String(root.slide.body || "") : ""
            color: Qt.rgba(1, 1, 1, 0.72)
            font.family: Theme.bodyFont
            font.pixelSize: DesktopTokens.captionSize
            font.weight: Font.Medium
            lineHeightMode: Text.FixedHeight
            lineHeight: 19
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.WordWrap
        }
    }

    Row {
        x: 24
        y: parent.height - 58
        height: 36
        spacing: 9
        visible: root.slideGame !== null

        Button {
            id: playButton
            width: 121
            height: 36
            padding: 0
            focusPolicy: Qt.NoFocus
            hoverEnabled: true
            Accessible.name: text
            text: qsTr("Play")
            onHoveredChanged: if (hovered) root.actionPointed(0)
            onClicked: if (root.slideGame) root.playRequested(root.slideGame)
            background: Rectangle {
                radius: DesktopTokens.radiusPill
                color: playButton.down
                    ? Qt.tint(DesktopTokens.focus, Qt.rgba(1, 1, 1, 0))
                    : Qt.tint(DesktopTokens.focus, Qt.rgba(1, 1, 1, playButton.hovered ? 0.10 : 0.04))
                border.width: root.selectedAction === 0 ? 2 : 0
                border.color: Qt.rgba(1, 1, 1, 0.85)
            }
            contentItem: Text {
                text: playButton.text
                color: DesktopTokens.inkOnAccent
                font.family: Theme.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Black
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Button {
            id: detailsButton
            width: 153
            height: 36
            padding: 0
            focusPolicy: Qt.NoFocus
            hoverEnabled: true
            Accessible.name: text
            text: qsTr("View details")
            onHoveredChanged: if (hovered) root.actionPointed(1)
            onClicked: if (root.slideGame) root.detailsRequested(root.slideGame)
            background: Rectangle {
                radius: DesktopTokens.radiusPill
                color: Qt.rgba(1, 1, 1, detailsButton.down ? 0.20 : detailsButton.hovered ? 0.18 : 0.12)
                border.width: root.selectedAction === 1 ? 2 : 1
                border.color: root.selectedAction === 1 ? DesktopTokens.focus : Qt.rgba(1, 1, 1, 0.22)
            }
            contentItem: Text {
                text: detailsButton.text
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: Theme.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Row {
        x: 24
        y: parent.height - 20
        spacing: 6
        visible: root.slides.length > 1
        Repeater {
            model: root.slides.length
            Rectangle {
                required property int index
                width: index === root.currentSlide ? 26 : 6
                height: 5
                radius: height / 2
                color: index === root.currentSlide ? DesktopTokens.focus : Qt.rgba(1, 1, 1, 0.32)
                Behavior on width { NumberAnimation { duration: AppController.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.currentSlide = index }
            }
        }
    }
}
