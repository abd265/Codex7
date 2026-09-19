import XCTest
import StoreKitTest

final class RiseBakeUITests: XCTestCase {
    func testAccountPagesValidateWithoutCreatingFakeAccounts() throws {
        continueAfterFailure = false
        executionTimeAllowance = 120
        let app = XCUIApplication()
        app.launchArguments = ["--show-welcome"]
        app.launch()
        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["auth.apple"].exists)
        XCTAssertTrue(app.buttons["auth.google"].exists)
        XCTAssertFalse(app.buttons["auth.apple"].isEnabled)
        XCTAssertFalse(app.buttons["auth.google"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["auth.availability"].firstMatch.exists)
        capture("Account-sign-in")
        let submit = app.buttons["auth.submit"]
        for _ in 0..<3 { if submit.isHittable { break }; app.swipeUp() }
        submit.tap()
        XCTAssertTrue(app.alerts.staticTexts["Enter a valid email address."].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()
        let switcher = app.buttons["auth.switch"]
        for _ in 0..<3 { if switcher.isHittable { break }; app.swipeUp() }
        switcher.tap()
        XCTAssertTrue(app.secureTextFields["auth.confirm"].exists)
        app.swipeDown()
        capture("Account-sign-up")
        let email = app.textFields["auth.email"]
        email.tap(); email.typeText("baker@example.com")
        app.secureTextFields["auth.password"].tap(); app.secureTextFields["auth.password"].typeText("short")
        app.swipeUp()
        for _ in 0..<4 { if submit.isHittable { break }; app.swipeUp() }
        submit.tap()
        XCTAssertTrue(app.alerts.staticTexts["Use a password with 12–128 characters."].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()
        let local = app.buttons["auth.local"]
        for _ in 0..<5 { if local.isHittable { break }; app.swipeUp() }
        local.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        app.terminate()
    }
    func testAccountAndPricingAreReachableWithoutServiceConfiguration() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        let app = XCUIApplication()
        // No account-preview switch: these are the normal released navigation paths.
        app.launch()
        openLocalBakery(app)
        app.tabBars.buttons["More"].tap()
        tapVisible(app.buttons["account.signup"], in: app)
        XCTAssertTrue(app.secureTextFields["auth.confirm"].waitForExistence(timeout: 5))
        tapVisible(app.buttons["auth.plans"], in: app)
        XCTAssertTrue(app.buttons["plans.select.monthly"].waitForExistence(timeout: 5))
        capture("Plans-and-pricing")
        XCTAssertTrue(app.buttons["plans.select.monthly"].label.contains("C$9.99"))
        XCTAssertTrue(app.buttons["plans.select.annual"].label.contains("C$79.99"))
        tapVisible(app.buttons["plans.select.offline"], in: app)
        XCTAssertTrue(app.buttons["plans.select.offline"].label.contains("C$49.99"))
        let purchase = app.buttons["plans.purchase"]
        for _ in 0..<8 { if purchase.isHittable { break }; app.swipeUp() }
        XCTAssertFalse(purchase.isEnabled, "Unavailable payments must never start a charge")
        tapVisible(app.buttons["plans.restore"], in: app)
        XCTAssertTrue(app.alerts.staticTexts["App Store purchases aren’t available in this installation. Your existing bakery remains available."].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.buttons["plans.done"].tap()
        tapVisible(app.buttons["auth.local"], in: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5), "Continuing locally must persist without deleting records")
        app.tabBars.buttons["More"].tap()
        capture("Account-and-plans-menu")
        tapVisible(app.buttons["membership.plans"], in: app)
        XCTAssertTrue(app.buttons["plans.select.annual"].waitForExistence(timeout: 5))
    }
    func testStoreKitPurchaseAndRestoreUseVerifiedEntitlements() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        let session = try SKTestSession(configurationFileNamed: "RiseBakePlans")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["--storekit-test"]
        app.launch()
        openLocalBakery(app)
        app.tabBars.buttons["More"].tap()
        tapVisible(app.buttons["membership.plans"], in: app)
        tapVisible(app.buttons["plans.select.offline"], in: app)
        XCTAssertFalse(app.otherElements["plans.active.offline"].exists)
        // Bring the purchase area on screen before observing its ready state.
        for _ in 0..<4 { if app.buttons["plans.purchase"].isHittable { break }; app.swipeUp() }
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["plans.purchase"])
        wait(for: [ready], timeout: 45)
        tapVisible(app.buttons["plans.purchase"], in: app)
        XCTAssertTrue(app.alerts.staticTexts["Your purchase is active. Thank you for supporting Rise & Bake."].waitForExistence(timeout: 15))
        app.alerts.buttons["OK"].tap()
        app.terminate(); app.launch()
        app.tabBars.buttons["More"].tap()
        tapVisible(app.buttons["membership.plans"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["plans.active.offline"].firstMatch.waitForExistence(timeout: 10))
        tapVisible(app.buttons["plans.restore"], in: app)
        XCTAssertTrue(app.alerts.staticTexts["Your purchases have been restored."].waitForExistence(timeout: 15))
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(app.buttons["plans.purchase"].exists, "An active plan must prevent a second charge")
    }
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
    func testCostingShoppingAndPantryPersist() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launchArguments = ["--costing-fixture"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 10))
        app.tabBars.buttons["More"].tap()
        app.buttons["costing.home"].tap()
        let recipe = app.buttons["cost.recipe.recipe-p0"]
        for _ in 0..<8 { if recipe.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(recipe.isHittable); recipe.tap()
        let total = app.staticTexts["costing.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "Estimated total, $17.40")
        capture("Recipe-costing")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["shopping.home"].tap()
        app.buttons["shopping.plan"].tap()
        XCTAssertTrue(app.buttons["shopping.generate"].waitForExistence(timeout: 5))
        app.buttons["shopping.generate"].tap()
        let flour = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shopping.item.' AND label CONTAINS 'Bread flour'")).firstMatch
        for _ in 0..<5 { if flour.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(flour.isHittable)
        XCTAssertTrue(flour.label.contains("0.3 kg"))
        flour.tap()
        XCTAssertTrue(flour.label.hasSuffix("checked"))
        XCTAssertFalse(flour.label.hasSuffix("not checked"))
        capture("Shopping-list")
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabBars.buttons["More"].tap()
        app.buttons["shopping.home"].tap()
        for _ in 0..<5 { if flour.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(flour.exists); XCTAssertFalse(flour.label.hasSuffix("not checked"))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["costing.home"].tap()
        app.buttons["costing.pantry"].tap()
        app.buttons["pantry.item.qa-flour"].tap()
        XCTAssertEqual(app.textFields["pantry.stock"].value as? String, "0.25", "Checking a shopping item must not silently change stock")
        app.buttons["Cancel"].tap()
        app.buttons["pantry.add"].tap()
        let name = app.textFields["pantry.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Unsalted butter")
        let price = app.textFields["pantry.price"]
        price.tap(); price.typeText("5.00")
        app.buttons["pantry.save"].tap()
        app.terminate(); app.launch()
        app.tabBars.buttons["More"].tap(); app.buttons["costing.home"].tap(); app.buttons["costing.pantry"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'pantry.item.' AND label CONTAINS 'Unsalted butter'")).firstMatch.waitForExistence(timeout: 5))
        capture("Ingredient-prices")
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways
        add(shot)
    }
    private func tapVisible(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 { if element.isHittable { break }; app.swipeUp() }
        if !element.isHittable { for _ in 0..<10 { if element.isHittable { break }; app.swipeDown() } }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
    private func openLocalBakery(_ app: XCUIApplication) {
        if app.buttons["auth.local"].waitForExistence(timeout: 3) { tapVisible(app.buttons["auth.local"], in: app) }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    }
}
