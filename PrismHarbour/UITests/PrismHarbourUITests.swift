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

        // A wall hit must animate feedback without counting a move or corrupting undo.
        shiftedCoral.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        let blockedMove = app.buttons["Move Coral left"]
        XCTAssertTrue(blockedMove.waitForExistence(timeout: 5))
        blockedMove.tap()
        XCTAssertTrue(shiftedCoral.exists)
        XCTAssertTrue(app.staticTexts["1 moves"].exists)
        let undo = textButton("Undo")
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        let originalCoral = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Coral prism, 2 squares, column 1, row 4")
        ).firstMatch
        XCTAssertTrue(originalCoral.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 moves"].exists)
        originalCoral.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        app.buttons["Move Coral up"].tap()
        XCTAssertTrue(shiftedCoral.waitForExistence(timeout: 5))

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

    func testChallengeVoyagePlanningUnlockAndOriginalProgress() throws {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-testing-completed-campaign"]
        app.launch()

        // An upgrading player who has cleared the original voyage should see the new game first.
        let play = textButton("Play challenge 1")
        XCTAssertTrue(play.waitForExistence(timeout: 15), "Completed original voyage must prioritize Challenge 1")
        play.tap()
        XCTAssertTrue(app.staticTexts["CHALLENGE 1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[ChallengeFixtures.firstTitle].exists)
        XCTAssertTrue(app.staticTexts["Untimed"].exists, "Challenges must allow time to plan")
        XCTAssertTrue(app.staticTexts["0 moves"].exists)
        XCTAssertTrue(app.staticTexts["AIM FOR 20"].exists, "The first challenge uses its certified twenty-gesture target")
        XCTAssertFalse(textButton("+30 sec").exists, "Untimed play should not sell extra seconds")
        attachScreenshot("Challenge 1 planning board")

        XCTAssertEqual(ChallengeFixtures.solution.count, 20, "The first fixed challenge has a twenty-gesture optimal route")
        for (index, move) in ChallengeFixtures.solution.enumerated() {
            let piece = app.descendants(matching: .any).matching(identifier: "prism-\(move.pieceID)").firstMatch
            XCTAssertTrue(piece.waitForExistence(timeout: 5), "Move \(index+1) must find piece \(move.pieceID)")
            let shape = try XCTUnwrap(ChallengeFixtures.pieces[move.pieceID], "Every scripted piece needs occupied-cell geometry")
            let cell = piece.frame.width / CGFloat(shape.width)
            XCTAssertGreaterThan(cell, 10, "The piece must have a visible on-screen frame")
            let start = piece.coordinate(withNormalizedOffset: CGVector(
                dx: (CGFloat(shape.cellX) + 0.5) / CGFloat(shape.width),
                dy: (CGFloat(shape.cellY) + 0.5) / CGFloat(shape.height)
            ))
            let end = start.withOffset(CGVector(dx: CGFloat(move.dx * move.steps) * cell,
                                               dy: CGFloat(move.dy * move.steps) * cell))
            start.press(forDuration: 0.1, thenDragTo: end)
            XCTAssertTrue(app.staticTexts["\(index+1) moves"].waitForExistence(timeout: 5),
                          "Real drag \(index+1) must execute exactly one planned move")
            if index == ChallengeFixtures.solution.count / 2 { attachScreenshot("Challenge 1 interlocking sequence") }
        }
        XCTAssertTrue(app.staticTexts["Clear waters."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["CHALLENGE 1 COMPLETE!"].exists)
        XCTAssertTrue(app.staticTexts["Three stars: 20 moves or fewer"].exists)
        attachScreenshot("Challenge 1 solved at target")

        let next = textButton("Next challenge")
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        if !next.isHittable { app.swipeUp() }
        next.tap()
        XCTAssertTrue(app.staticTexts["CHALLENGE 2"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Untimed"].exists)
        XCTAssertTrue(app.staticTexts["0 moves"].exists)
        attachScreenshot("Challenge 2 unlocked")

        app.buttons["Pause game"].tap()
        let home = textButton("Return to harbour")
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        if !home.isHittable { app.swipeUp() }
        home.tap()
        let resume = textButton("Continue challenge 2")
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.staticTexts["CHALLENGE 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 moves"].exists)

        app.buttons["Pause game"].tap()
        let challengeMap = textButton("Back to challenges")
        XCTAssertTrue(challengeMap.waitForExistence(timeout: 5))
        if !challengeMap.isHittable { app.swipeUp() }
        challengeMap.tap()
        XCTAssertTrue(app.buttons["Original"].waitForExistence(timeout: 5))
        attachScreenshot("Challenge map progression")
        app.buttons["Original"].tap()
        XCTAssertTrue(app.staticTexts["Original voyage, 36 of 36 harbours completed, 108 stars"].waitForExistence(timeout: 5),
                      "Challenge play must preserve every original completion and star")
        attachScreenshot("Original voyage progress preserved")
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
