import QtQuick
import QtTest
import OpenNOW

TestCase {
    id: testCase
    name: "LibraryHero"
    width: 1200
    height: 800
    when: windowShown
    visible: true

    property var fixtureGames: [
        {title: "Far Cry 3", publisherName: "Ubisoft", genre: "Action"},
        {title: "Black Myth: Wukong", publisherName: "Game Science", genre: "Adventure"},
        {title: "Assassin's Creed Unity", publisherName: "Ubisoft", genre: "Action"}
    ]

    DesktopLibraryHero {
        id: hero
        x: 20
        y: 20
        width: 900
        height: 280
        games: testCase.fixtureGames
        active: false
    }

    function descendants(item) {
        let result = []
        for (const child of item.children || [])
            result = result.concat([child], descendants(child))
        return result
    }

    function named(name) {
        return descendants(hero).find(item => item.objectName === name)
    }

    function init() {
        DesktopTokens.uiScale = 1
        AppController.reducedMotion = true
        hero.active = false
        hero.selectedAction = -1
        hero.games = fixtureGames
        hero.width = 900
        hero.height = 280
    }

    function cleanup() {
        hero.active = false
        AppController.reducedMotion = true
        DesktopTokens.uiScale = 1
    }

    function test_actionsAndNavigation() {
        let played = null
        let detailed = null
        const onPlay = game => { played = game }
        const onDetails = game => { detailed = game }
        hero.playRequested.connect(onPlay)
        hero.detailsRequested.connect(onDetails)
        named("desktopHeroPlay").clicked()
        named("desktopHeroDetails").clicked()
        compare(played.title, "Far Cry 3")
        compare(detailed.title, "Far Cry 3")
        hero.playRequested.disconnect(onPlay)
        hero.detailsRequested.disconnect(onDetails)

        hero.selectedAction = 1
        compare(named("desktopHeroPlay").navigationFocus, false)
        compare(named("desktopHeroDetails").navigationFocus, true)
        hero.previousSlide()
        compare(hero.currentIndex, 2)
        hero.nextSlide()
        compare(hero.currentIndex, 0)
        hero.showSlide(99)
        compare(hero.currentIndex, 2)
        hero.showSlide(-8)
        compare(hero.currentIndex, 0)
        compare(hero.transition, 1)
        compare(hero.slideProgress, 0)
    }

    function test_transitionAndReducedMotion() {
        hero.active = false
        AppController.reducedMotion = false
        compare(hero.autoCycleActive, false)
        hero.slideProgress = 0.65
        hero.nextSlide()
        compare(hero.currentIndex, 1)
        compare(hero.slideProgress, 0)
        verify(hero.transition < 1)

        hero.slideProgress = 0.65
        AppController.reducedMotion = true
        compare(hero.transition, 1)
        compare(hero.slideProgress, 0)
        compare(hero.autoCycleActive, false)
        hero.previousSlide()
        compare(hero.currentIndex, 0)
        compare(hero.transition, 1)
    }

    function test_scaledGeometry_data() {
        return [
            {tag: "compact-scale-100", width: 900, height: 280, scale: 1, lines: 1},
            {tag: "compact-scale-140", width: 900, height: 280, scale: 1.4, lines: 1},
            {tag: "home-scale-100", width: 1120, height: 400, scale: 1, lines: 2},
            {tag: "home-scale-140", width: 1120, height: 400, scale: 1.4, lines: 2}
        ]
    }

    function test_scaledGeometry(data) {
        const longTitle = "An exceptionally long featured game title that must remain readable"
        hero.games = [
            {title: longTitle, publisherName: "A publisher with a longer name", genre: "Adventure"},
            fixtureGames[1], fixtureGames[2]
        ]
        DesktopTokens.uiScale = data.scale
        hero.width = data.width
        hero.height = data.height
        waitForRendering(hero)

        const editorial = named("desktopHeroEditorial")
        const dock = named("desktopHeroStoryDock")
        const play = named("desktopHeroPlay")
        const details = named("desktopHeroDetails")
        verify(editorial && dock && play && details)
        const editorialPoint = editorial.mapToItem(hero, 0, 0)
        const dockPoint = dock.mapToItem(hero, 0, 0)
        const detailsPoint = details.mapToItem(hero, 0, 0)
        verify(editorialPoint.y >= 0, "Editorial content is clipped at the top")
        verify(editorialPoint.y + editorial.height + 4 <= dockPoint.y,
            "Actions overlap the story dock; editorialBottom=" + (editorialPoint.y + editorial.height)
                + " dockY=" + dockPoint.y)
        verify(detailsPoint.x + details.width <= hero.width,
            "Hero actions exceed the available width")
        verify(dockPoint.y + dock.height <= hero.height,
            "Story dock exceeds the hero height")
        compare(named("desktopHeroTitle").maximumLineCount, data.lines)
    }
}
