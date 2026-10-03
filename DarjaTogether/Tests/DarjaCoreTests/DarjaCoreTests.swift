import XCTest
@testable import DarjaCore

final class DarjaCoreTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private var day: Date { Date(timeIntervalSince1970: 1_790_985_600) }

    func testFirstRememberedReviewSchedulesTomorrowAndEarnsStar() {
        let result = LearningRules.nextReview(previous: nil, remembered: true, at: day, calendar: calendar)
        XCTAssertEqual(result.state.intervalDays, 1)
        XCTAssertEqual(result.state.successfulReviews, 1)
        XCTAssertTrue(result.earnsStar)
        XCTAssertEqual(result.state.dueDate, calendar.date(byAdding: .day, value: 1, to: day))
    }

    func testDueReviewsAdvanceThroughTheSpacingIntervals() {
        var previous: WordReviewState?
        var current = day
        for interval in [1, 3, 7, 14, 30, 30] {
            let result = LearningRules.nextReview(previous: previous, remembered: true, at: current, calendar: calendar)
            XCTAssertEqual(result.state.intervalDays, interval)
            XCTAssertEqual(result.state.dueDate, calendar.date(byAdding: .day, value: interval, to: current))
            XCTAssertTrue(result.earnsStar)
            previous = result.state
            current = result.state.dueDate
        }
    }

    func testSameDayRepeatsDoNotFarmStarsOrAdvanceSpacing() {
        let first = LearningRules.nextReview(previous: nil, remembered: true, at: day, calendar: calendar)
        let repeatResult = LearningRules.nextReview(previous: first.state, remembered: true, at: day.addingTimeInterval(60), calendar: calendar)
        XCTAssertFalse(repeatResult.earnsStar)
        XCTAssertEqual(repeatResult.state.intervalDays, first.state.intervalDays)
        XCTAssertEqual(repeatResult.state.successfulReviews, first.state.successfulReviews)
        XCTAssertEqual(repeatResult.state.dueDate, first.state.dueDate)
    }

    func testEarlyRevisitKeepsScheduledRecallDate() {
        let previous = WordReviewState(dueDate: day.addingTimeInterval(3 * 86400), intervalDays: 3, successfulReviews: 2, lastReviewed: day)
        let early = LearningRules.nextReview(previous: previous, remembered: true, at: day.addingTimeInterval(86400), calendar: calendar)
        XCTAssertEqual(early.state.intervalDays, previous.intervalDays)
        XCTAssertEqual(early.state.dueDate, previous.dueDate)
        XCTAssertEqual(early.state.successfulReviews, previous.successfulReviews)
    }

    func testForgottenWordReturnsInTenMinutes() {
        let known = WordReviewState(dueDate: day, intervalDays: 14, successfulReviews: 4, lastReviewed: day.addingTimeInterval(-14 * 86400))
        let result = LearningRules.nextReview(previous: known, remembered: false, at: day, calendar: calendar)
        XCTAssertFalse(result.earnsStar)
        XCTAssertEqual(result.state.successfulReviews, 0)
        XCTAssertEqual(result.state.intervalDays, 0)
        XCTAssertEqual(result.state.dueDate, day.addingTimeInterval(600))
    }

    func testDayKeysFollowTheLearnersCalendar() {
        var eastern = calendar
        eastern.timeZone = TimeZone(identifier: "America/New_York")!
        let instant = Date(timeIntervalSince1970: 1_790_899_200)
        XCTAssertNotEqual(LearningRules.dayKey(for: instant, calendar: calendar), LearningRules.dayKey(for: instant, calendar: eastern))
    }

    func testAllSixLearningSkillsAreDistinct() {
        XCTAssertEqual(Set(Skill.allCases.map(\.rawValue)), ["listening", "speaking", "vocabulary", "reading", "writing", "conversation"])
    }

    func testProgressRoundTripsCompletedSessionsAndReviewDates() throws {
        var progress = LearnerProgress()
        progress.completedSessions = ["w1-s1", "w1-s2"]
        progress.stars = 8
        progress.reviewStates["salam"] = WordReviewState(dueDate: day, intervalDays: 3, successfulReviews: 2, lastReviewed: day.addingTimeInterval(-86400))
        let decoded = try JSONDecoder().decode(LearnerProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(decoded.completedSessions, progress.completedSessions)
        XCTAssertEqual(decoded.stars, 8)
        XCTAssertEqual(decoded.reviewStates["salam"]?.dueDate, day)
        XCTAssertEqual(decoded.reviewStates["salam"]?.intervalDays, 3)
    }

    func testBundledCurriculumDecodesAndEveryLessonReferenceExists() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("DarjaTogether/Resources/curriculum.json"))
        let curriculum = try JSONDecoder().decode(Curriculum.self, from: data)
        XCTAssertEqual(curriculum.weeks.count, 36)
        XCTAssertEqual(curriculum.stages.count, 6)
        XCTAssertEqual(curriculum.weeks.map(\.id).sorted(), Array(1...36))
        let words = Set(curriculum.words.map(\.id))
        XCTAssertEqual(words.count, curriculum.words.count, "Word IDs must be unique")
        XCTAssertGreaterThanOrEqual(words.count, 150)
        let sessions = curriculum.weeks.flatMap(\.sessions)
        XCTAssertEqual(sessions.count, 180)
        XCTAssertEqual(Set(sessions.map(\.id)).count, sessions.count)
        let stories = Set(curriculum.stories.map(\.id))
        for week in curriculum.weeks {
            XCTAssertEqual(week.sessions.count, 5)
            XCTAssertTrue(curriculum.stages.contains { $0.id == week.stageId })
            for id in week.wordIds + week.reviewWordIds + week.sessions.flatMap(\.wordIds) {
                XCTAssertTrue(words.contains(id), "Week \(week.id) references missing word \(id)")
            }
            if let storyID = week.storyId { XCTAssertTrue(stories.contains(storyID)) }
        }
        for tip in curriculum.pronunciationTips { XCTAssertTrue(words.contains(tip.exampleWordId)) }
        for word in curriculum.words {
            XCTAssertFalse(word.arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(word.english.isEmpty)
            XCTAssertFalse(word.french.isEmpty)
        }
    }
}
