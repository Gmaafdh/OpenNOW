import QtQuick
import QtTest
import OpenNOW

TestCase {
    id: testCase
    name: "RoundedArtworkFit"
    width: 1000
    height: 500
    when: windowShown
    visible: true

    RoundedArtwork {
        id: artwork
        width: 900
        height: 400
        cinematicFit: true
        alignArtworkRight: true
        scrimStart: 1
    }

    function init() {
        artwork.cinematicFit = true
        artwork.alignArtworkRight = true
    }

    function namedChild(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        const children = item.children || []
        for (let i = 0; i < children.length; ++i) {
            const match = namedChild(children[i], name)
            if (match)
                return match
        }
        return null
    }

    function test_cinematicForegroundIsContained() {
        const primary = namedChild(artwork, "roundedArtworkPrimary")
        const fallback = namedChild(artwork, "roundedArtworkFallback")
        const backdrop = namedChild(artwork, "roundedArtworkCinematicBackdrop")
        verify(primary && fallback && backdrop)
        compare(primary.fillMode, Image.PreserveAspectFit)
        compare(fallback.fillMode, Image.PreserveAspectFit)
        compare(primary.horizontalAlignment, Image.AlignRight)
        compare(fallback.horizontalAlignment, Image.AlignRight)
        compare(primary.sourceSize.width, -1)
        compare(primary.sourceSize.height, 400)
        compare(backdrop.visible, true)
        compare(backdrop.fillMode, Image.PreserveAspectCrop)
    }

    function test_regularArtworkKeepsCropContract() {
        artwork.cinematicFit = false
        const primary = namedChild(artwork, "roundedArtworkPrimary")
        const fallback = namedChild(artwork, "roundedArtworkFallback")
        const backdrop = namedChild(artwork, "roundedArtworkCinematicBackdrop")
        compare(primary.fillMode, Image.PreserveAspectCrop)
        compare(fallback.fillMode, Image.PreserveAspectCrop)
        compare(primary.horizontalAlignment, Image.AlignHCenter)
        compare(fallback.horizontalAlignment, Image.AlignHCenter)
        compare(primary.sourceSize.width, 900)
        compare(primary.sourceSize.height, 400)
        compare(backdrop.visible, false)
    }

    function test_containedArtworkCanBeCentered() {
        artwork.cinematicFit = true
        artwork.alignArtworkRight = false
        const primary = namedChild(artwork, "roundedArtworkPrimary")
        compare(primary.fillMode, Image.PreserveAspectFit)
        compare(primary.horizontalAlignment, Image.AlignHCenter)
        artwork.alignArtworkRight = true
    }
}
