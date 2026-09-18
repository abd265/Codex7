import XCTest

final class RiseBakeUITests: XCTestCase {
    func testBakeryProfileAndBrandedReceipt() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launchArguments = ["--receipt-fixture"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 10))
        app.tabBars.buttons["More"].tap()
        app.buttons["bakery.profile"].tap()
        let field = app.textFields["profile.name"]
        for _ in 0..<4 { if field.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(field.isHittable)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count))
        field.typeText("Rose & Flour Studio")
        app.buttons["profile.save"].tap()
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.staticTexts["Rose & Flour Studio"].waitForExistence(timeout: 5))
        app.buttons["bakery.profile"].tap()
        XCTAssertTrue(app.buttons["Remove logo"].waitForExistence(timeout: 5), "Logo must survive saving and relaunch")
        capture("Bakery-profile")
        app.buttons["Back"].tap()
        app.tabBars.buttons["Orders"].tap()
        app.buttons["order.1201"].tap()
        let receipt = app.buttons["View receipt"]
        for _ in 0..<6 { if receipt.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(receipt.isHittable); receipt.tap()
        XCTAssertTrue(app.staticTexts["Rose & Flour Studio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["hello@example.com"].exists)
        capture("Branded-receipt")
        let preview = app.buttons["receipt.preview"]
        for _ in 0..<8 { if preview.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(preview.isHittable); preview.tap()
        XCTAssertTrue(app.navigationBars["PDF preview"].waitForExistence(timeout: 5))
        capture("Receipt-PDF")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["receipt.share"].tap()
        // iOS exposes activity actions as cells, not buttons.
        XCTAssertTrue(app.cells["Save to Files"].waitForExistence(timeout: 8), "The system share sheet must offer saving the PDF")
        XCTAssertTrue(app.cells["Print"].exists, "The shared file must support printing")
        capture("Receipt-sharing")
        app.terminate()
    }
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
