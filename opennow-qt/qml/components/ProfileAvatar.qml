import QtQuick
import QtQuick.Effects
import OpenNOW

Item {
    id: root
    objectName: "profileAvatar"

    property var account: null
    property string displayName: String(account && account.displayName || qsTr("OpenNOW profile"))
    property color fallbackStart: Theme.violet
    property color fallbackEnd: Theme.focus
    property real cornerRadius: Math.min(width, height) / 2
    property color borderColor: "transparent"
    property real borderWidth: 0

    readonly property string customImage: ShellStore.customProfileImageFor(account)
    readonly property bool imageReady: avatar.status === Image.Ready
    readonly property string initial: displayName.trim().length > 0
        ? displayName.trim().charAt(0).toUpperCase() : "O"

    implicitWidth: 48
    implicitHeight: 48
    clip: false

    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: root.cornerRadius
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
            maskSource: roundedMask
            maskThresholdMin: 0.25
            maskSpreadAtMin: 0.2
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.fallbackStart }
                GradientStop { position: 1; color: root.fallbackEnd }
            }
        }
        Image {
            id: avatar
            objectName: "profileAvatarImage"
            anchors.fill: parent
            source: root.visible && root.customImage !== "" ? root.customImage : ""
            sourceSize: Qt.size(Math.max(1, Math.ceil(width * 2)), Math.max(1, Math.ceil(height * 2)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
        }
        Text {
            objectName: "profileAvatarFallback"
            anchors.centerIn: parent
            visible: !root.imageReady
            text: root.initial
            color: Theme.contrastText(root.fallbackStart)
            font.family: Theme.displayFont
            font.pixelSize: Math.max(10, Math.round(Math.min(root.width, root.height) * 0.42))
            font.weight: Font.Black
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: root.borderWidth
        border.color: root.borderColor
    }
}
