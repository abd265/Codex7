import XCTest

/// Runs against the production UI and game engine using a clean, in-memory save.
final class PrismHarbourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testFirstVoyageDragDockAndContinue() {
        let play = textButton("Play level 1")
        XCTAssertTrue(play.waitForExistence(timeout: 15), "Fresh launch must offer Level 1")
        play.tap()
        XCTAssertTrue(app.staticTexts["Welcome Aboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["3 left"].exists)

        // A real vertical drag exercises gesture priority inside the scroll view.
        let coral = prism("Coral")
        XCTAssertTrue(coral.waitForExistence(timeout: 5))
        let start = coral.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = start.withOffset(CGVector(dx: 0, dy: -coral.frame.height / 2))
        start.press(forDuration: 0.1, thenDragTo: end)
        let shiftedCoral = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Coral prism, 2 squares, column 1, row 3")
        ).firstMatch
        XCTAssertTrue(shiftedCoral.waitForExistence(timeout: 5), "Dragging one cell should move coral upward")
        XCTAssertTrue(app.staticTexts["1 moves"].exists)
        attachScreenshot("Level 1 after vertical drag")

        // Arrow controls then exercise each remaining dock direction and the win flow.
        dock("Coral", direction: "up", steps: 3)
        XCTAssertTrue(app.staticTexts["2 left"].exists)
        dock("Mint", direction: "down", steps: 4)
        XCTAssertTrue(app.staticTexts["1 left"].exists)
        dock("Amber", direction: "right", steps: 3)
        XCTAssertTrue(app.staticTexts["Clear waters."].waitForExistence(timeout: 8))
        attachScreenshot("First level victory")

        let next = textButton("Next harbour")
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        if !next.isHittable { app.swipeUp() }
        next.tap()
        XCTAssertTrue(app.staticTexts["Make Some Room"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["0 moves"].exists)
        attachScreenshot("Level 2 unlocked")

        app.buttons["Pause game"].tap()
        XCTAssertTrue(app.staticTexts["A moment of calm."].waitForExistence(timeout: 5))
        let home = textButton("Return to harbour")
        if !home.isHittable { app.swipeUp() }
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.tap()
        let resume = textButton("Continue level 2")
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.staticTexts["Make Some Room"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 moves"].exists)
    }

    private func textButton(_ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func prism(_ color: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "\(color) prism,")
        ).firstMatch
    }

    private func dock(_ color: String, direction: String, steps: Int) {
        let piece = prism(color)
        XCTAssertTrue(piece.waitForExistence(timeout: 5))
        // Top-left cell is occupied for all three introductory pieces, including the L.
        piece.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        for _ in 0..<steps {
            let button = app.buttons["Move \(color) \(direction)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertTrue(button.isHittable)
            button.tap()
        }
        let disappeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: prism(color))
        XCTAssertEqual(XCTWaiter.wait(for: [disappeared], timeout: 5), .completed, "The \(color) prism should dock")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
