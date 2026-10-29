import QtQuick
import QtTest
import OpenNOW

TestCase {
    id: testCase
    name: "ProfileAvatar"
    width: 160
    height: 120
    when: windowShown
    visible: true

    ProfileAvatar {
        id: avatar
        x: 16; y: 16
        width: 64; height: 64
        account: ({userId:"profile-avatar-test",displayName:"Maya"})
    }

    function namedChild(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        const children = item.children || []
        for (let index = 0; index < children.length; ++index) {
            const match = namedChild(children[index], name)
            if (match) return match
        }
        return null
    }

    function init() {
        ShellStore.settings = {customProfileImages:{}}
    }

    function test_initialFallback() {
        const image = namedChild(avatar, "profileAvatarImage")
        const fallback = namedChild(avatar, "profileAvatarFallback")
        verify(image && fallback)
        compare(avatar.customImage, "")
        compare(avatar.initial, "M")
        compare(image.source.toString(), "")
        compare(fallback.visible, true)
    }

    function test_localImageAndRemovalFallback() {
        const source = Qt.resolvedUrl("../../res/brand/opennow-mark.png")
        const images = {}
        images["profile-avatar-test"] = source
        ShellStore.settings = {customProfileImages:images}
        const image = namedChild(avatar, "profileAvatarImage")
        const fallback = namedChild(avatar, "profileAvatarFallback")
        compare(avatar.customImage, source)
        compare(image.source.toString(), source)
        tryCompare(image, "status", Image.Ready, 3000)
        compare(avatar.imageReady, true)
        compare(fallback.visible, false)

        ShellStore.settings = {customProfileImages:{}}
        compare(avatar.customImage, "")
        compare(image.source.toString(), "")
        tryCompare(fallback, "visible", true, 1000)
        compare(fallback.text, "M")
    }
}
