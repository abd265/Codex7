import XCTest

@MainActor
final class DarjaTogetherUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 12), "Expected control does not exist", file: file, line: line)
        for _ in 0..<4 {
            if element.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<6 {
            if element.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable, "Expected control is not reachable", file: file, line: line)
        element.tap()
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFirstAdventurePersistsAndSupportsTryingAgain() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tap(app.buttons["beginButton"], in: app)
        XCTAssertTrue(app.buttons["startLesson"].waitForExistence(timeout: 12))
        capture("Today before first lesson", app: app)
        tap(app.buttons["startLesson"], in: app)

        let expectedWords = ["hello", "yes", "no"]
        for (index, id) in expectedWords.enumerated() {
            XCTAssertTrue(app.buttons["hearWord"].waitForExistence(timeout: 10))
            if index == 0 { capture("Discover an Arabic word", app: app) }
            tap(app.buttons["hearWord"], in: app)
            tap(app.buttons["lessonNext"], in: app)
            XCTAssertTrue(app.buttons["listenPrompt"].waitForExistence(timeout: 10))
            tap(app.buttons["listenPrompt"], in: app)
            if index == 0 {
                let wrong = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "answer-", "answer-" + id)).firstMatch
                tap(wrong, in: app)
                XCTAssertTrue(app.staticTexts["Let’s listen once more and try another picture."].waitForExistence(timeout: 5))
                XCTAssertFalse(app.buttons["lessonNext"].exists)
                capture("A gentle retry", app: app)
            }
            let answerCard = app.buttons["answer-" + id]
            XCTAssertTrue(answerCard.waitForExistence(timeout: 12))
            if !answerCard.isHittable { app.swipeUp() }
            XCTAssertTrue(answerCard.isHittable)
            // Exercise the card's empty padded region, outside the emoji itself.
            answerCard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.15)).tap()
            let foundAnswer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "You found it!")).firstMatch
            XCTAssertTrue(foundAnswer.waitForExistence(timeout: 8), "The full answer card must accept a tap")
            if index == 2 { capture("Answer card responds outside the picture", app: app) }
            tap(app.buttons["lessonNext"], in: app)
            tap(app.buttons["speakingAttempt"], in: app)
            tap(app.buttons["lessonNext"], in: app)
            let canvas = app.descendants(matching: .any).matching(identifier: "tracingCanvas").firstMatch
            XCTAssertTrue(canvas.waitForExistence(timeout: 8))
            if !canvas.isHittable { app.swipeUp() }
            let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45))
            let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.6))
            start.press(forDuration: 0.1, thenDragTo: end)
            if index == 0 { capture("Real finger tracing", app: app) }
            tap(app.buttons["lessonNext"], in: app)
        }
        XCTAssertTrue(app.buttons["finishLesson"].waitForExistence(timeout: 12))
        capture("First adventure completed", app: app)
        tap(app.buttons["finishLesson"], in: app)
        app.terminate()
        app.launchArguments = ["--uitesting", "--preserve-progress"]
        app.launch()
        XCTAssertFalse(app.buttons["beginButton"].exists)
        tap(app.tabBars.buttons["Journey"], in: app)
        XCTAssertTrue(app.staticTexts.matching(identifier: "1 of 5 adventures").firstMatch.waitForExistence(timeout: 12), "Completion should survive app relaunch")
        capture("Saved journey after relaunch", app: app)
    }

    func testBookmarkAndCafeConversation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--screenshot-home"]
        app.launch()
        tap(app.tabBars.buttons["My words"], in: app)
        let word = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hello")).firstMatch
        tap(word, in: app)
        tap(app.buttons["Save to my collection"], in: app)
        XCTAssertTrue(app.buttons["Saved in my collection"].waitForExistence(timeout: 5))
        capture("Saved word in my collection", app: app)
        tap(app.tabBars.buttons["Play"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Darja café")).firstMatch, in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Water")).firstMatch, in: app)
        tap(app.buttons["I said my order to my partner"], in: app)
        XCTAssertTrue(app.staticTexts["Swap roles! Now you are the café host. Ask your partner what they would like."].waitForExistence(timeout: 5))
        capture("A Darja cafe conversation", app: app)
    }

    func testParentPINPersistsAndRecordingStartsDisabled() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--screenshot-home"]
        app.launch()
        tap(app.buttons["parentButton"], in: app)
        tap(app.secureTextFields["parentPIN"], in: app)
        app.secureTextFields["parentPIN"].typeText("1234")
        tap(app.secureTextFields["confirmPIN"], in: app)
        app.secureTextFields["confirmPIN"].typeText("1234")
        tap(app.buttons["unlockParents"], in: app)
        XCTAssertTrue(app.staticTexts["Small steps, real connection."].waitForExistence(timeout: 8))
        capture("Parent space with fresh progress", app: app)
        tap(app.buttons["Done"], in: app)
        app.terminate()

        app.launchArguments = ["--uitesting", "--preserve-progress"]
        app.launch()
        tap(app.buttons["parentButton"], in: app)
        XCTAssertFalse(app.secureTextFields["confirmPIN"].exists, "The saved parent PIN should already be configured")
        tap(app.secureTextFields["parentPIN"], in: app)
        app.secureTextFields["parentPIN"].typeText("9999")
        tap(app.buttons["unlockParents"], in: app)
        XCTAssertTrue(app.staticTexts["That PIN did not match. Try again."].waitForExistence(timeout: 5))
        tap(app.secureTextFields["parentPIN"], in: app)
        app.secureTextFields["parentPIN"].typeText("1234")
        tap(app.buttons["unlockParents"], in: app)
        XCTAssertTrue(app.staticTexts["Small steps, real connection."].waitForExistence(timeout: 8))

        let microphone = app.switches["Allow local voice recording"]
        for _ in 0..<8 {
            if microphone.exists && microphone.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(microphone.exists)
        XCTAssertEqual(microphone.value as? String, "0", "Recording must remain off until a parent opts in")
        capture("Parent-controlled recording is off", app: app)
        tap(app.buttons["Algerian voice"], in: app)
        let modelVoice = app.switches["useOfflineDarjaVoice"]
        XCTAssertTrue(modelVoice.waitForExistence(timeout: 8))
        XCTAssertEqual(modelVoice.value as? String, "1", "The bundled Algerian voice is selected by default")
        capture("Offline Algerian voice settings", app: app)
        // SwiftUI exposes this Form toggle's whole row as the switch. Its label
        // midpoint is not the UISwitch hit target; tap the observed trailing control.
        XCTAssertTrue(modelVoice.isHittable)
        let switchControl = modelVoice.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25, dy: 0))
        switchControl.tap()
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: modelVoice)
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 5), .completed,
                       "Only a parent can explicitly select approximate device speech")
        capture("Parent explicitly selected device speech", app: app)
        switchControl.tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: modelVoice)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        capture("Parent restored offline Algerian voice", app: app)
        tap(app.buttons["Clear generated speech cache"], in: app)
        let cacheConfirmation = app.staticTexts["Generated speech cache cleared. Family recordings are kept."]
        for _ in 0..<6 {
            if cacheConfirmation.exists && cacheConfirmation.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(cacheConfirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(cacheConfirmation.isHittable)
        capture("Generated cache cleared without removing family recordings", app: app)
        tap(app.navigationBars["Algerian voice"].buttons["Parent space"], in: app)
        tap(app.buttons["Done"], in: app)
        tap(app.buttons["parentButton"], in: app)
        XCTAssertTrue(app.secureTextFields["parentPIN"].waitForExistence(timeout: 5), "Closing the parent panel must lock it")
    }

}
