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
            tap(app.buttons["answer-" + id], in: app)
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
}
