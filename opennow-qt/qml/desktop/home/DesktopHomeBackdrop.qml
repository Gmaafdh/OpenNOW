pragma ComponentBehavior: Bound

import QtQuick
import OpenNOW

// =============================================================================
// DesktopHomeBackdrop — the full-bleed PS5 home background.
// =============================================================================
//
// On a PS5 the whole home screen is painted with the focused game's art: the
// background changes when you move along the icon bar, the art breathes slowly
// and everything above it sits on scrims tuned for legibility. This component
// is that background for OpenNOW home.
//
// Design decisions:
//   * Exactly two image layers exist (A/B). Changing games loads into the
//     hidden layer and crossfades, so the catalog is never decoded in bulk and
//     there is no white flash between slides.
//   * The art is requested at a quarter of the display size and scaled up with
//     smoothing. That produces the soft, out-of-focus key-art look PS5 uses at
//     a fraction of the cost of a full-screen blur effect, and it keeps the
//     home page responsive on integrated GPUs.
//   * A slow "breathing" scale plus pointer parallax keeps the surface alive.
//     Both are disabled under reduced motion.
//   * Scrims are theme-aware: light themes wash toward the shell colour, dark
//     themes deepen toward #060911, so the rails and hero stay readable in
//     either pack.
//
// Sections:
//   1. base shell + accent wash
//   2. artwork stage (A/B crossfade, breathing, parallax)
//   3. lighting: bloom, vignette, top/bottom/left scrims
//   4. state veils: first paint, dim hook
//   5. input + accessibility
// =============================================================================
Item {
    id: root
    objectName: "desktopHomeBackdrop"
    clip: true

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------
    /// The featured game. Its hero art (falling back to poster art) is painted.
    property var game: null

    /// When false the backdrop stops animating and stops loading new art.
    property bool active: true

    /// Extra darkness (0..1) applied above everything, used by the empty and
    /// loading states so text stays readable without any artwork.
    property real dim: 0

    /// Nudge the art horizontally (-1..1). Hero art often has its subject on
    /// the right, so the screen biases the backdrop to keep faces out from
    /// under the title block.
    property real artBias: 0.18

    /// Tint strength for the theme accent bloom (0..1).
    property real accentStrength: 1

    /// Where the key art keeps its subject. Hero art usually sits right of
    /// centre, poster art is centred; the screen can override per slide.
    /// "left" | "center" | "right"
    property string artAlignment: "right"

    /// Vignette strength (0..1). Raised automatically in light themes where
    /// bright art washes out the rails.
    property real vignette: 1

    /// Extra exposure applied to the art (0..1 darkens, >1 is clamped). The
    /// screen drops this while a modal or the command palette is open so the
    /// overlay reads as the foreground.
    property real exposure: 1

    /// Slow horizontal drift when the pointer is idle. Gives the stage life on
    /// a controller-only setup where the cursor never moves.
    property bool idleDrift: true

    /// Screen-reader copy for the painted art.
    property string artDescription: ""

    /// Per-scrim strength so the screen can tune legibility for its layout:
    /// the title block needs the most, the rail fade the least.
    property real titleScrim: 1
    property real railScrim: 1
    property real headerScrim: 1

    /// Upcoming games whose hero art should be decoded ahead of time. Moving
    /// along the dock then repaints instantly instead of waiting on the network.
    property var warmGames: []

    /// Where the hero/rail seam sits (0..1 of the height).
    property real seamPosition: 0.62

    /// True while keyboard/controller focus is inside the hero stage. The art
    /// brightens a touch so the featured game reads as "you are here".
    property bool heroFocused: false

    /// Vertical offset applied to the whole stage, letting the screen push the
    /// art up when the dock grows or down when a rail is focused.
    property real stageOffset: 0

    /// Film grain. Off under reduced motion and on software rendering, where an
    /// extra tiled layer is not worth the fill rate.
    property bool grainEnabled: true

    /// Fallback hue (0..360) used when a game has no artwork at all. Derived
    /// from the title so every game gets a stable, distinct background.
    property string fallbackSeed: ""

    /// Pointer parallax multiplier. 0 freezes the stage under the cursor, which
    /// is what the screen wants while a modal owns the pointer.
    property real parallaxStrength: 1

    /// Idle treatment: after `idleDelay` ms without pointer movement the art
    /// dims by `idleDim` so a controller-only setup does not burn a static
    /// bright image into the panel. Any movement wakes it immediately.
    property bool idleDimming: true
    property int idleDelay: 180000
    property real idleDim: 0.14

    /// Emitted whenever artState changes so owners can drive their own spinner
    /// without reaching into the crossfade internals.
    signal artStateUpdated(string value)

    // -------------------------------------------------------------------------
    // Derived state
    // -------------------------------------------------------------------------
    readonly property string heroUrl: DesktopTokens.artworkUrl(game, true)
    readonly property string posterUrl: DesktopTokens.artworkUrl(game, false)
    readonly property string displayUrl: heroUrl !== "" ? heroUrl : posterUrl
    readonly property bool motionOff: AppController.reducedMotion
    readonly property bool lightMode: Theme.lightMode

    /// Overscan keeps the stage edges covered while it breathes and parallaxes.
    readonly property int overscan: DesktopTokens.px(40)

    /// Crossfade bookkeeping.
    property string currentUrl: ""
    property string pendingUrl: ""
    property bool topIsA: true
    property bool firstPaint: true

    /// Pointer position in 0..1, smoothed by behaviours below.
    property real pointerX: 0.5
    property real pointerY: 0.5

    /// Drift phase, advanced by a timer while the pointer is idle.
    property real driftPhase: 0

    readonly property real clampedExposure: Math.max(0, Math.min(1, exposure))
    readonly property real clampedVignette: Math.max(0, Math.min(1, vignette)) * (lightMode ? 1.15 : 1)
    readonly property int alignmentOffset: artAlignment === "left" ? -DesktopTokens.px(30)
        : artAlignment === "center" ? 0 : DesktopTokens.px(26)

    /// A stable 0..360 hue from the title so art-less games still paint a
    /// background that belongs to them (and never changes between visits).
    readonly property real fallbackHue: {
        const seed = fallbackSeed !== "" ? fallbackSeed
            : (game ? String(game.title || game.id || "") : "")
        if (seed === "")
            return 210
        let hash = 0
        for (let index = 0; index < seed.length; ++index)
            hash = (hash * 31 + seed.charCodeAt(index)) % 100003
        return hash % 360
    }
    readonly property color fallbackTop: Qt.hsla(fallbackHue / 360, 0.42, lightMode ? 0.82 : 0.30, 1)
    readonly property color fallbackBottom: Qt.hsla(((fallbackHue + 38) % 360) / 360, 0.48,
                                                    lightMode ? 0.70 : 0.14, 1)
    readonly property bool artMissing: displayUrl === ""

    /// Single source of truth for "what is the backdrop showing right now".
    /// "missing" — the game has no art at all, the generated stage is painted.
    /// "loading" — a crossfade to new art is in flight.
    /// "ready"   — art is on screen.
    /// "idle"    — nothing requested yet (first paint, inactive).
    readonly property string artState: artMissing ? "missing"
        : pendingUrl !== "" ? "loading" : currentUrl !== "" ? "ready" : "idle"
    /// True once the idle timer has elapsed; cleared by any pointer movement.
    property bool idleArmed: false
    /// Multiplies the idle dim so callers can fade it in one place.
    readonly property real idleAmount: idleArmed && idleDimming && !motionOff ? idleDim : 0

    onArtStateChanged: root.artStateUpdated(artState)

    /// Restart the idle countdown. Called from the pointer handler and whenever
    /// the featured game changes, both of which count as activity.
    function wakeFromIdle() {
        root.idleArmed = false
        if (root.idleDelay > 0)
            idleTimer.restart()
    }

    Timer {
        id: idleTimer
        interval: Math.max(1000, root.idleDelay)
        repeat: false
        running: root.active && root.idleDimming && !root.artMissing && root.idleDelay > 0
        onTriggered: root.idleArmed = true
    }

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Background artwork")
    Accessible.ignored: true

    Behavior on pointerX {
        NumberAnimation { duration: root.motionOff ? 0 : 520; easing.type: Easing.OutCubic }
    }
    Behavior on pointerY {
        NumberAnimation { duration: root.motionOff ? 0 : 520; easing.type: Easing.OutCubic }
    }

    // -------------------------------------------------------------------------
    // Crossfade state machine
    // -------------------------------------------------------------------------
    function hiddenLayer() {
        return root.topIsA ? layerB : layerA
    }

    function topLayer() {
        return root.topIsA ? layerA : layerB
    }

    function requestArt(url) {
        const next = String(url || "")
        if (next === "")
            return
        if (next === root.currentUrl && !root.firstPaint)
            return

        // Reduced motion (and the very first paint) shows the art immediately.
        if (root.motionOff || root.firstPaint) {
            layerA.artUrl = next
            layerB.artUrl = next
            root.currentUrl = next
            root.pendingUrl = ""
            root.firstPaint = false
            root.topIsA = true
            return
        }

        root.pendingUrl = next
        root.hiddenLayer().artUrl = next
        swapFallback.restart()
    }

    function promoteHiddenLayer() {
        if (root.pendingUrl === "")
            return
        swapFallback.stop()
        root.currentUrl = root.pendingUrl
        root.pendingUrl = ""
        root.topIsA = !root.topIsA
    }

    onDisplayUrlChanged: {
        root.requestArt(displayUrl)
        root.wakeFromIdle()
    }
    onActiveChanged: if (active) root.requestArt(displayUrl)
    Component.onCompleted: {
        root.firstPaint = true
        root.requestArt(displayUrl)
    }

    /// Safety net: if the hidden layer never reports ready (network stall), the
    /// swap still happens so the backdrop cannot get stuck on the old game.
    Timer {
        id: swapFallback
        interval: 2600
        onTriggered: root.promoteHiddenLayer()
    }

    /// Idle drift. One full sweep takes about two minutes, slow enough to read
    /// as ambience rather than motion, and it stops as soon as the pointer moves.
    Timer {
        id: driftTicker
        interval: 80
        repeat: true
        running: root.active && root.idleDrift && !root.motionOff
            && !parallaxHover.hovered && !root.artMissing
        onTriggered: root.driftPhase = (root.driftPhase + 0.004) % 1
    }

    onMotionOffChanged: if (motionOff) driftPhase = 0
    onHeroFocusedChanged: root.wakeFromIdle()
    onArtMissingChanged: if (artMissing) driftPhase = 0

    /// One crossfading art layer. The image is decoded small and scaled up,
    /// which is what gives the background its soft, cinematic focus.
    component ArtLayer: Item {
        id: artLayer
        property string artUrl: ""
        property bool onTop: true
        property real artOpacity: onTop ? 1 : 0
        signal artReady()

        opacity: artOpacity
        visible: opacity > 0.01

        Behavior on artOpacity {
            NumberAnimation {
                duration: root.motionOff ? 0 : Theme.duration(560)
                easing.type: Easing.OutCubic
            }
        }

        Image {
            id: artImage
            objectName: "desktopHomeBackdropArt"
            anchors.fill: parent
            source: artLayer.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: false
            // Quarter resolution: soft focus for free, and fast to decode.
            sourceSize: Qt.size(Math.max(1, Math.ceil(width / 4)), Math.max(1, Math.ceil(height / 4)))
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.motionOff ? 0 : Theme.duration(420) }
            }
            onStatusChanged: {
                if (status === Image.Ready && artLayer.artUrl !== "")
                    artLayer.artReady()
            }
        }

        // Placeholder tint while the art is in flight.
        Rectangle {
            anchors.fill: parent
            color: root.lightMode ? "#E8EDF5" : "#0D1524"
            opacity: artImage.status === Image.Ready ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 260 } }
        }
    }

    // -------------------------------------------------------------------------
    // Art cache warm-up. ArtworkSource is the same loader RoundedArtwork uses,
    // so warming it here means the dock's next selection is already decoded.
    // -------------------------------------------------------------------------
    Repeater {
        model: (root.warmGames || []).slice(0, 3)
        ArtworkSource {
            required property var modelData
            sourceUrl: DesktopTokens.artworkUrl(modelData, true)
            active: root.active && !root.motionOff
            requestActive: root.visible
        }
    }

    // =========================================================================
    // 1. Base shell + accent wash
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: Theme.shell
    }

    Rectangle {
        anchors.fill: parent
        opacity: (root.lightMode ? 0.10 : 0.18) * Math.max(0, Math.min(1, root.accentStrength))
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Theme.atmosphere }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.00; color: Theme.focus }
        }
    }

    // -------------------------------------------------------------------------
    // Generated fallback: two-tone wash plus a soft key shape, so a game with
    // no artwork still gets a background of its own instead of a flat shell.
    // -------------------------------------------------------------------------
    Item {
        id: fallbackStage
        anchors.fill: parent
        visible: root.artMissing
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 320 } }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.fallbackTop }
                GradientStop { position: 1.0; color: root.fallbackBottom }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: -parent.width * 0.12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.52
            height: width
            radius: width / 2
            color: "#14FFFFFF"
        }
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: -parent.width * 0.18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -parent.height * 0.2
            width: parent.width * 0.46
            height: width
            radius: width / 2
            color: "#10000000"
        }
    }

    // =========================================================================
    // 2. Artwork stage
    // =========================================================================
    Item {
        id: artStage
        visible: !root.artMissing
        anchors.fill: parent
        anchors.margins: -root.overscan
        scale: 1
        transformOrigin: Item.Center
        transform: Translate {
            x: (root.pointerX - 0.5) * -DesktopTokens.px(18) * root.parallaxStrength
               + root.artBias * DesktopTokens.px(24)
               + root.alignmentOffset
               + Math.sin(root.driftPhase * Math.PI * 2) * DesktopTokens.px(10)
            y: root.stageOffset
               + (root.pointerY - 0.5) * -DesktopTokens.px(10) * root.parallaxStrength
               + Math.cos(root.driftPhase * Math.PI * 2) * DesktopTokens.px(4)
        }

        // Slow breathing zoom, frozen under reduced motion.
        SequentialAnimation {
            id: breathe
            loops: Animation.Infinite
            running: root.active && !root.motionOff && root.currentUrl !== ""
            onRunningChanged: if (!running) artStage.scale = 1
            NumberAnimation {
                target: artStage
                property: "scale"
                from: 1
                to: 1.045
                duration: 16000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: artStage
                property: "scale"
                from: 1.045
                to: 1
                duration: 16000
                easing.type: Easing.InOutSine
            }
        }

        // Coarse halo behind the crossfade pair. Decoding the same URL at an
        // eighth of the display size gives a bloom that costs almost nothing
        // and stops hard-edged key art from fighting the title block.
        Image {
            id: haloImage
            anchors.fill: parent
            anchors.margins: -root.overscan
            source: root.topIsA ? layerA.artUrl : layerB.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize: Qt.size(Math.max(1, Math.ceil(width / 8)), Math.max(1, Math.ceil(height / 8)))
            scale: 1.12
            transformOrigin: Item.Center
            opacity: status === Image.Ready ? (root.lightMode ? 0.28 : 0.42) : 0
            Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 420 } }
        }

        ArtLayer {
            id: layerA
            anchors.fill: parent
            onTop: root.topIsA
            z: root.topIsA ? 2 : 1
            onArtReady: {
                if (!root.topIsA && root.pendingUrl === layerA.artUrl)
                    root.promoteHiddenLayer()
            }
        }

        ArtLayer {
            id: layerB
            anchors.fill: parent
            onTop: !root.topIsA
            z: root.topIsA ? 1 : 2
            onArtReady: {
                if (root.topIsA && root.pendingUrl === layerB.artUrl)
                    root.promoteHiddenLayer()
            }
        }
    }

    // =========================================================================
    // 3. Lighting and scrims
    // =========================================================================
    // Focus brightening: a barely-there wash that lifts the art while the hero
    // owns keyboard focus, then settles back when a rail takes over.
    Rectangle {
        anchors.fill: parent
        color: "#FFFFFF"
        opacity: root.heroFocused && !root.motionOff ? 0.05 : 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
    }

    // Accent bloom anchored to the hero subject side.
    Rectangle {
        anchors.fill: parent
        opacity: root.lightMode ? 0.16 : 0.30
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.62; color: "transparent" }
            GradientStop {
                position: 1.00
                color: Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.55)
            }
        }
    }

    // Left wash that anchors the hero title block.
    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0, Math.min(1.4, root.titleScrim))
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 240 } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: root.lightMode ? "#E6F4F7FB" : "#EE060911" }
            GradientStop { position: 0.34; color: root.lightMode ? "#C4F4F7FB" : "#B8070B14" }
            GradientStop { position: 0.62; color: root.lightMode ? "#5CF4F7FB" : "#4A080D18" }
            GradientStop { position: 1.00; color: "transparent" }
        }
    }

    // Vertical scrim: darkens the top for the shell header and the bottom for
    // the dock and rails. The two ends are tuned independently.
    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0, Math.min(1.4, root.railScrim))
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 240 } }
        gradient: Gradient {
            GradientStop { position: 0.00; color: root.lightMode ? "#66F4F7FB" : "#66060911" }
            GradientStop { position: 0.18; color: "transparent" }
            GradientStop { position: 0.52; color: "transparent" }
            GradientStop { position: 0.80; color: root.lightMode ? "#BFF4F7FB" : "#A8060911" }
            GradientStop { position: 1.00; color: root.lightMode ? "#F4F7FB" : "#F0060911" }
        }
    }

    // Hairline seam where the hero stage meets the scrolling rails. It gives
    // the stage a defined edge without drawing a box around it.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: parent.height * root.seamPosition
        height: 1
        color: root.lightMode ? "#14040610" : "#14FFFFFF"
        opacity: root.currentUrl === "" ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // =========================================================================
    // 4. State veils
    // =========================================================================
    // Dim hook (empty state, loading, signed out).
    Rectangle {
        anchors.fill: parent
        color: root.lightMode ? "#F4F7FB" : "#060911"
        opacity: Math.max(0, Math.min(1, root.dim))
        Behavior on opacity { NumberAnimation { duration: 260 } }
    }

    // First-paint veil: hides the bare shell colour until art resolves.
    Rectangle {
        anchors.fill: parent
        color: root.lightMode ? "#F4F7FB" : "#060911"
        opacity: root.currentUrl === "" && root.displayUrl !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
    }

    // Exposure veil: the screen dims the backdrop while a modal is open so the
    // overlay reads as the foreground layer.
    Rectangle {
        anchors.fill: parent
        color: root.lightMode ? "#F4F7FB" : "#03060C"
        opacity: Math.min(0.92, (1 - root.clampedExposure) * (root.lightMode ? 0.75 : 0.85) + root.idleAmount)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.motionOff ? 0 : 240 } }
    }

    // Vignette: corners fall away so the rails sit on a calmer surface.
    Rectangle {
        anchors.fill: parent
        opacity: 0.55 * root.clampedVignette
        gradient: Gradient {
            GradientStop { position: 0.00; color: root.lightMode ? "#33F4F7FB" : "#66000000" }
            GradientStop { position: 0.30; color: "transparent" }
            GradientStop { position: 0.70; color: "transparent" }
            GradientStop { position: 1.00; color: root.lightMode ? "#33F4F7FB" : "#73000000" }
        }
    }

    // Pointer spotlight. A wide, very soft highlight that follows the cursor so
    // the surface responds to the pointer even when the art is static.
    Rectangle {
        id: spotlight
        visible: parallaxHover.hovered && !root.motionOff && !root.artMissing
        width: DesktopTokens.px(520)
        height: DesktopTokens.px(520)
        radius: width / 2
        x: root.pointerX * root.width - width / 2
        y: root.pointerY * root.height - height / 2
        opacity: visible ? 0.16 : 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#FFFFFF" }
            GradientStop { position: 0.55; color: "#33FFFFFF" }
            GradientStop { position: 1.0; color: "transparent" }
        }
        Behavior on opacity { NumberAnimation { duration: 320 } }
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    // Ghost title. When a game ships no art at all, its name becomes the
    // background at very low contrast — the stage never looks broken.
    Text {
        id: ghostTitle
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        text: root.game ? String(root.game.title || "") : ""
        color: root.lightMode ? "#14040610" : "#1AFFFFFF"
        font.family: DesktopTokens.displayFont
        font.pixelSize: DesktopTokens.px(96)
        font.weight: Font.Black
        font.letterSpacing: -3
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        visible: root.artMissing && text !== ""
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
    }

    // Indeterminate loading line while the next art is in flight.
    Rectangle {
        id: loadingLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: DesktopTokens.px(2)
        color: "transparent"
        visible: root.pendingUrl !== "" && !root.motionOff

        Rectangle {
            id: loadingFill
            width: parent.width * 0.28
            height: parent.height
            color: DesktopTokens.mint
            opacity: 0.75

            SequentialAnimation on x {
                loops: Animation.Infinite
                running: loadingLine.visible
                NumberAnimation {
                    from: -loadingFill.width
                    to: loadingLine.width
                    duration: 1500
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation { duration: 200 }
            }
        }
    }

    // Film grain. One small canvas is generated once and reused as a tile; the
    // loader keeps it out of the tree entirely when grain is disabled.
    Loader {
        id: grainLoader
        anchors.fill: parent
        active: root.grainEnabled && !root.motionOff && !root.artMissing
        sourceComponent: Item {
            id: grainHost

            Canvas {
                id: grainCanvas
                width: 96
                height: 96
                visible: false
                renderStrategy: Canvas.Image
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const image = ctx.createImageData(width, height)
                    for (let pixel = 0; pixel < image.data.length; pixel += 4) {
                        const value = 120 + Math.floor(Math.random() * 40)
                        image.data[pixel] = value
                        image.data[pixel + 1] = value
                        image.data[pixel + 2] = value
                        image.data[pixel + 3] = 14
                    }
                    ctx.putImageData(image, 0, 0)
                }
                Component.onCompleted: requestPaint()
            }

            Image {
                anchors.fill: parent
                source: grainCanvas.visible ? "" : grainCanvas.toDataURL("image/png")
                fillMode: Image.Tile
                opacity: root.lightMode ? 0.35 : 0.5
                cache: true
                asynchronous: false
            }
        }
    }

    // Live status for assistive tech: what is painted, and whether it is loading.
    Item {
        Accessible.role: Accessible.StaticText
        Accessible.name: root.artDescription !== "" ? root.artDescription
            : root.artMissing ? qsTr("No artwork for this game")
            : root.pendingUrl !== "" ? qsTr("Loading artwork") : qsTr("Featured artwork loaded")
        Accessible.ignored: false
        width: 1
        height: 1
        opacity: 0
    }

    // =========================================================================
    // 5. Input
    // =========================================================================
    HoverHandler {
        id: parallaxHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onPointChanged: {
            root.wakeFromIdle()
            if (root.motionOff || !root.active || root.parallaxStrength <= 0)
                return
            const local = point.position
            root.pointerX = Math.max(0, Math.min(1, local.x / Math.max(1, root.width)))
            root.pointerY = Math.max(0, Math.min(1, local.y / Math.max(1, root.height)))
        }
        onHoveredChanged: {
            root.wakeFromIdle()
            if (!hovered) {
                root.pointerX = 0.5
                root.pointerY = 0.5
            }
        }
    }
}
