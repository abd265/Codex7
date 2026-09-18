import XCTest

final class RiseBakeUITests: XCTestCase {
    func testRecipeJournalAndBackgroundPersist() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Bake"].waitForExistence(timeout: 10))
        capture("Today")
        app.tabBars.buttons["Bake"].tap()
        app.buttons["Recipes"].tap()
        let recipe = app.buttons["recipe.recipe-p4"]
        // Native navigation links are exposed as buttons by SwiftUI.
        XCTAssertTrue(recipe.waitForExistence(timeout: 5))
        recipe.tap()
        XCTAssertTrue(app.buttons["bake.start"].waitForExistence(timeout: 5))
        app.buttons["bake.start"].tap()
        let timer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'timer.'")).firstMatch
        for _ in 0..<5 { if timer.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(timer.isHittable)
        timer.tap()
        XCTAssertEqual(timer.label, "Pause")
        capture("Baking-timer")
        app.terminate()
        app.launch()
        app.tabBars.buttons["Bake"].tap()
        let session = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'session.'")).firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 5))
        session.tap()
        let resumed = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'timer.'")).firstMatch
        for _ in 0..<5 { if resumed.isHittable { break }; app.swipeUp() }
        XCTAssertEqual(resumed.label, "Pause", "A running timer must survive relaunch")
        resumed.tap()
        XCTAssertEqual(resumed.label, "Start timer")
        app.tabBars.buttons["More"].tap()
        app.buttons["Backgrounds"].tap()
        app.buttons["background.berryPatisserie"].tap()
        capture("Backgrounds")
        app.terminate()
        app.launch()
        app.tabBars.buttons["More"].tap()
        app.buttons["Backgrounds"].tap()
        XCTAssertTrue(app.buttons["background.berryPatisserie"].label.contains("selected"))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Menu"].tap()
        for _ in 0..<3 { if app.buttons["Add Sourdough Loaf to basket"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["Add Sourdough Loaf to basket"].isHittable)
        app.buttons["Add Sourdough Loaf to basket"].tap()
        XCTAssertTrue(app.buttons["Basket (1)"].exists)
        capture("Menu")
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways
        add(shot)
    }
}
