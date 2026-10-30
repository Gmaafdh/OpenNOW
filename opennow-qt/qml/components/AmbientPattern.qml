import QtQuick
import OpenNOW

Canvas {
    id: root
    objectName: "ambientPatternCanvas"
    property bool active: true
    property string pattern: Theme.ambientPattern
    property color patternColor: Theme.focus
    property color secondaryColor: Theme.atmosphere
    property real intensity: Theme.patternOpacity

    anchors.fill: parent
    visible: active && pattern !== "none" && intensity > 0
    opacity: Math.min(0.32, intensity * 0.32)
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPatternChanged: requestPaint()
    onPatternColorChanged: requestPaint()
    onSecondaryColorChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onPaint: {
        const context = getContext("2d")
        context.clearRect(0, 0, width, height)
        if (!visible || width <= 0 || height <= 0) return
        context.lineWidth = 1
        if (pattern === "grid") {
            const step = 64
            context.strokeStyle = patternColor
            context.globalAlpha = 0.65
            context.beginPath()
            for (let x = 0.5; x < width; x += step) {
                context.moveTo(x, 0)
                context.lineTo(x, height)
            }
            for (let y = 0.5; y < height; y += step) {
                context.moveTo(0, y)
                context.lineTo(width, y)
            }
            context.stroke()
            return
        }
        if (pattern === "constellation") {
            const points = []
            for (let index = 0; index < 28; ++index) {
                points.push({x:((index * 67) % 101) / 100 * width,
                    y:((index * 43 + 17) % 97) / 96 * height})
            }
            context.strokeStyle = secondaryColor
            context.globalAlpha = 0.35
            context.beginPath()
            for (let index = 0; index + 1 < points.length; ++index) {
                context.moveTo(points[index].x, points[index].y)
                context.lineTo(points[index + 1].x, points[index + 1].y)
            }
            context.stroke()
            context.fillStyle = patternColor
            context.globalAlpha = 0.9
            for (const point of points) {
                context.beginPath()
                context.arc(point.x, point.y, 2.2, 0, Math.PI * 2)
                context.fill()
            }
            return
        }
        if (pattern === "contour") {
            context.globalAlpha = 0.7
            context.lineWidth = 1.4
            for (let index = -1; index < 9; ++index) {
                const y = index * height / 7
                context.strokeStyle = index % 2 === 0 ? patternColor : secondaryColor
                context.beginPath()
                context.moveTo(-40, y)
                context.bezierCurveTo(width * 0.22, y - 90, width * 0.36, y + 100, width * 0.58, y + 5)
                context.bezierCurveTo(width * 0.76, y - 70, width * 0.9, y + 65, width + 40, y - 20)
                context.stroke()
            }
        }
    }
}
