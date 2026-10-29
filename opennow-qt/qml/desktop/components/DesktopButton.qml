import QtQuick
import QtQuick.Controls
import OpenNOW

// Halo button. One control covers the whole hierarchy:
//   variant "primary"  accent fill, glow, dark ink — exactly one per group
//   variant "glass"    translucent fill with hairline (default secondary)
//   variant "ghost"    text/icon only, fills in on hover
//   variant "outline"  hairline outline with accent ink
//   variant "danger"   tinted destructive action
// Press state is a 90 ms scale dip; hover is a 160 ms light lift.
Button {
    id: root
    property bool primary: false
    property bool danger: false
    property bool onMediaBackground: false
    property string variant: primary ? "primary" : danger ? "danger" : "glass"
    property string shortcutText: ""
    property string shortcutSequence: shortcutText
    property string glyph: ""
    property string themedGlyph: ""
    property int glyphSize: DesktopTokens.px(15)
    property int cornerRadius: DesktopTokens.radiusSm + DesktopTokens.px(2)
    property string size: "md"
    property bool block: false
    property bool selected: false

    readonly property bool accent: root.variant === "primary"
    readonly property bool ghost: root.variant === "ghost"
    readonly property bool outlined: root.variant === "outline"
    readonly property bool destructive: root.variant === "danger"
    readonly property bool large: root.size === "lg"
    readonly property bool small: root.size === "sm"
    // Primary ink stays the literal near-black the acceptance tests pin: the
    // accent fills in this product are always light, so contrast is guaranteed.
    readonly property color ink: root.accent ? "#0A0D14"
        : root.destructive ? (Theme.lightMode ? "#8C2F27" : "#FFB4AE")
        : root.onMediaBackground ? Theme.mediaForeground
        : root.outlined ? DesktopTokens.focus
        : DesktopTokens.textHigh
    readonly property real hoverAmount: (root.hovered || root.selected) && root.enabled ? 1 : 0

    height: root.small ? DesktopTokens.controlHeightSm
        : root.large ? DesktopTokens.controlHeightLg : DesktopTokens.controlHeight
    leftPadding: root.ghost ? DesktopTokens.px(10) : DesktopTokens.px(root.small ? 12 : 16)
    rightPadding: leftPadding
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    font.family: DesktopTokens.bodyFont
    font.pixelSize: root.small ? DesktopTokens.smallSize : DesktopTokens.captionSize
    font.weight: Font.Bold
    font.letterSpacing: 0.1
    opacity: enabled ? 1 : 0.45
    scale: AppController.reducedMotion ? 1 : (root.down ? 0.965 : 1)
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation { duration: DesktopTokens.pressDuration; easing.type: Easing.OutCubic }
    }

    implicitWidth: root.block ? Math.max(DesktopTokens.px(68), contentRow.implicitWidth + leftPadding + rightPadding)
                              : Math.max(DesktopTokens.px(68), contentRow.implicitWidth + leftPadding + rightPadding)

    background: Item {
        // Soft bloom beneath the accent button — a blurred-looking halo made
        // from layered translucent rings, so it needs no shader pass.
        Rectangle {
            visible: root.accent
            anchors.fill: parent
            anchors.margins: -DesktopTokens.px(3)
            radius: root.cornerRadius + DesktopTokens.px(3)
            color: Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b,
                           0.10 + 0.10 * root.hoverAmount)
            Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
        }

        Rectangle {
            id: face
            anchors.fill: parent
            radius: root.cornerRadius

            color: root.accent
                ? Qt.tint(DesktopTokens.focus, Qt.rgba(1, 1, 1, root.down ? 0 : 0.10 + 0.08 * root.hoverAmount))
                : root.destructive
                    ? Qt.rgba(1, 0.478, 0.478, root.hoverAmount > 0 ? 0.20 : 0.10)
                    : root.outlined
                        ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b,
                                  0.06 + 0.08 * root.hoverAmount)
                        : root.ghost
                            ? Qt.rgba(1, 1, 1, Theme.lightMode ? 0.10 * root.hoverAmount : 0.08 * root.hoverAmount)
                            : (Theme.lightMode
                                ? Qt.rgba(1, 1, 1, 0.62 + 0.3 * root.hoverAmount)
                                : Qt.rgba(1, 1, 1, 0.06 + 0.05 * root.hoverAmount))
            border.width: root.accent ? 0 : 1
            border.color: root.destructive
                ? Qt.rgba(1, 0.478, 0.478, 0.40)
                : root.outlined
                    ? Qt.rgba(DesktopTokens.focus.r, DesktopTokens.focus.g, DesktopTokens.focus.b, 0.55)
                    : root.ghost ? "transparent" : DesktopTokens.hairline

            Behavior on color { ColorAnimation { duration: DesktopTokens.hoverDuration } }
            Behavior on border.color { ColorAnimation { duration: DesktopTokens.hoverDuration } }

            // Top sheen: the lit edge of the glass.
            Rectangle {
                visible: !root.accent && !root.ghost
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - root.cornerRadius * 1.6)
                height: 1
                radius: 1
                color: Theme.lightMode ? "#FFFFFF" : "#26FFFFFF"
                opacity: 0.8
            }
        }

        // Keyboard focus ring: 2 px accent with a 2 px offset, never hidden.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -DesktopTokens.px(3)
            radius: root.cornerRadius + DesktopTokens.px(3)
            color: "transparent"
            border.width: 2
            border.color: root.onMediaBackground ? Theme.mediaAccent : DesktopTokens.focus
            visible: root.activeFocus
        }
    }

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: root.glyph !== "" || root.themedGlyph !== "" ? DesktopTokens.px(9) : DesktopTokens.px(7)
            DesktopGlyph {
                visible: root.glyph !== "" && root.themedGlyph === ""
                anchors.verticalCenter: parent.verticalCenter
                width: root.glyphSize
                height: root.glyphSize
                icon: root.glyph
            }
            Loader {
                active: root.themedGlyph !== ""
                visible: active
                anchors.verticalCenter: parent.verticalCenter
                width: root.glyphSize; height: root.glyphSize
                sourceComponent: DesktopSettingsIcon {
                    glyph: root.themedGlyph
                    ink: root.ink
                }
            }
            Text {
                visible: root.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.ink
                font: root.font
            }
            KeyboardGlyph {
                visible: root.shortcutText !== ""
                anchors.verticalCenter: parent.verticalCenter
                shortcut: root.shortcutSequence
                Accessible.name: root.shortcutText
                keySize: DesktopTokens.px(18)
                ink: root.accent ? "#0B0F1A"
                    : root.onMediaBackground ? Theme.mediaMuted : DesktopTokens.textMuted
            }
        }
    }
}
