import QtQuick
import OpenNOW

// Settings group container on the Halo surface: frosted fill, hairline, top
// sheen. `paperStyle` keeps the flat variant for dense, scrollable pages.
DesktopSurface {
    id: panel
    property bool paperStyle: false
    property int padding: paperStyle ? 0 : DesktopTokens.px(18)
    default property alias content: body.data

    implicitHeight: body.implicitHeight + padding * 2
    corner: paperStyle ? DesktopTokens.radiusMd : DesktopTokens.radiusLg
    fill: paperStyle
        ? (Theme.lightMode ? Qt.rgba(1, 1, 1, 0.60) : Qt.rgba(1, 1, 1, 0.035))
        : (Theme.lightMode ? Qt.rgba(1, 1, 1, 0.74) : Qt.rgba(1, 1, 1, 0.05))
    fillTop: paperStyle ? fill : (Theme.lightMode ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(1, 1, 1, 0.075))
    fillBottom: paperStyle ? fill : (Theme.lightMode ? Qt.rgba(0.97, 0.98, 1, 0.80) : Qt.rgba(0, 0, 0, 0.16))
    stroke: paperStyle ? DesktopTokens.hairlineSoft : DesktopTokens.hairline
    sheen: !paperStyle
    // Dense settings rows sit over live artwork; keep the glass readable.
    tint: paperStyle
        ? (Theme.lightMode ? 0.72 : 0.60)
        : (Theme.lightMode ? 0.80 : 0.70)

    Column {
        id: body
        x: panel.padding
        y: panel.padding
        width: panel.width - panel.padding * 2
    }
}
