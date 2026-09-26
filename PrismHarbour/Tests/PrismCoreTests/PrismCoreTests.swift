import Foundation
import XCTest
@testable import PrismCore

final class PrismCoreTests: XCTestCase {
    private func piece(_ id: Int = 1, color: PrismColor = .coral, at origin: Cell = Cell(x: 0, y: 0),
                       cells: [Cell] = [Cell(x: 0, y: 0)]) -> Piece {
        Piece(id: id, color: color, cells: cells, origin: origin)
    }
    private func level(pieces: [Piece], gates: [Gate] = [], blocked: [Cell] = []) -> Level {
        Level(id: 1, title: "Test", pieces: pieces, gates: gates, blocked: blocked)
    }
    private func assertValid(_ state: GameState, file: StaticString = #filePath, line: UInt = #line) {
        let cells = state.pieces.flatMap(\.worldCells)
        XCTAssertEqual(Set(cells).count, cells.count, "Pieces overlap", file: file, line: line)
        XCTAssertTrue(cells.allSatisfy { state.level.contains($0) }, "A partial exit was retained", file: file, line: line)
        XCTAssertTrue(Set(cells).isDisjoint(with: state.level.blocked), "A piece overlaps a fixed obstacle", file: file, line: line)
    }

    func testCollisionDoesNotChangeBoardOrMoveCount() {
        var state = GameState(level: level(pieces: [piece(), piece(2, at: Cell(x: 1, y: 0))]))
        let original = state
        XCTAssertEqual(state.move(pieceID: 1, direction: .right), .blocked)
        XCTAssertEqual(state, original)
    }

    func testFixedObstacleStopsMovement() {
        var state = GameState(level: level(pieces: [piece(at: Cell(x: 2, y: 3))], blocked: [Cell(x: 2, y: 2)]))
        XCTAssertEqual(state.move(pieceID: 1, direction: .up), .blocked)
        XCTAssertEqual(state.moves, 0)
    }

    func testWrongColorAndWrongSideCannotExit() {
        var wrongColor = GameState(level: level(pieces: [piece()], gates: [Gate(color: .mint, side: .up, start: 0, span: 2)]))
        XCTAssertEqual(wrongColor.move(pieceID: 1, direction: .up), .blocked)
        var wrongSide = GameState(level: level(pieces: [piece()], gates: [Gate(color: .coral, side: .down, start: 0, span: 2)]))
        XCTAssertEqual(wrongSide.move(pieceID: 1, direction: .up), .blocked)
        XCTAssertEqual(wrongSide.pieces.count, 1)
    }

    func testEntireShapeMustFitWithinGateSpan() {
        let domino = piece(at: Cell(x: 1, y: 0), cells: [Cell(x: 0, y: 0), Cell(x: 1, y: 0)])
        var state = GameState(level: level(pieces: [domino], gates: [Gate(color: .coral, side: .up, start: 0, span: 2)]))
        XCTAssertEqual(state.move(pieceID: 1, direction: .up), .blocked)
        XCTAssertEqual(state.move(pieceID: 1, direction: .left), .moved)
        XCTAssertEqual(state.move(pieceID: 1, direction: .up), .exited)
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.clearedCount, 1)
        XCTAssertEqual(state.moves, 2)
    }

    func testConcaveShapeCannotSweepThroughObstacleDuringAtomicExit() {
        let elbow = piece(cells: [Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)])
        var state = GameState(level: level(pieces: [elbow], gates: [Gate(color: .coral, side: .up, start: 0, span: 2)],
                                          blocked: [Cell(x: 1, y: 0)]))
        assertValid(state)
        XCTAssertEqual(state.move(pieceID: 1, direction: .up), .blocked)
        assertValid(state)
    }

    func testConcaveShapeCannotSweepThroughAnotherPieceDuringExit() {
        let elbow = piece(cells: [Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)])
        var state = GameState(level: level(pieces: [elbow, piece(2, color: .mint, at: Cell(x: 1, y: 0))],
                                          gates: [Gate(color: .coral, side: .up, start: 0, span: 2)]))
        XCTAssertEqual(state.move(pieceID: 1, direction: .up), .blocked)
        XCTAssertEqual(state.pieces.count, 2)
    }

    func testAllFourExitDirections() {
        for direction in Direction.allCases {
            let origin: Cell
            switch direction {
            case .up: origin = Cell(x: 2, y: 0)
            case .right: origin = Cell(x: 5, y: 2)
            case .down: origin = Cell(x: 2, y: 7)
            case .left: origin = Cell(x: 0, y: 2)
            }
            var state = GameState(level: level(pieces: [piece(at: origin)],
                                              gates: [Gate(color: .coral, side: direction, start: 2, span: 2)]))
            XCTAssertEqual(state.move(pieceID: 1, direction: direction), .exited, "\(direction)")
            XCTAssertTrue(state.isComplete)
            XCTAssertEqual(state.moves, 1)
        }
    }

    func testLongGestureStopsAtCollisionAndCountsOnce() {
        var state = GameState(level: level(pieces: [piece()], blocked: [Cell(x: 3, y: 0)]))
        XCTAssertEqual(state.move(pieceID: 1, direction: .right, steps: 5), .moved)
        XCTAssertEqual(state.pieces[0].origin, Cell(x: 2, y: 0))
        XCTAssertEqual(state.moves, 1)
        XCTAssertEqual(state.move(pieceID: 1, direction: .right, steps: 5), .blocked)
        XCTAssertEqual(state.moves, 1)
    }

    func testInvalidMoveRequestsAreNoOps() {
        var state = GameState(level: level(pieces: [piece()]))
        let original = state
        XCTAssertEqual(state.move(pieceID: 99, direction: .down), .blocked)
        XCTAssertEqual(state.move(pieceID: 1, direction: .down, steps: 0), .blocked)
        XCTAssertEqual(state.move(pieceID: 1, direction: .down, steps: -1), .blocked)
        XCTAssertEqual(state, original)
    }

    func testEveryCampaignLevelHasAValidCompleteSolution() {
        XCTAssertEqual(LevelCatalog.campaign.count, 36)
        XCTAssertEqual(Set(LevelCatalog.campaign.map(\.id)).count, 36)
        for level in LevelCatalog.campaign {
            XCTAssertEqual(level.columns, 6)
            XCTAssertEqual(level.rows, 8)
            XCTAssertGreaterThanOrEqual(level.pieces.count, 3, "Level \(level.id)")
            XCTAssertEqual(Set(level.pieces.map(\.id)).count, level.pieces.count)
            XCTAssertFalse(level.solution.isEmpty)
            var state = GameState(level: level)
            assertValid(state)
            for action in level.solution {
                XCTAssertNotEqual(state.apply(action), .blocked, "Invalid solution action in level \(level.id): \(action)")
                assertValid(state)
            }
            XCTAssertTrue(state.isComplete, "Unsolved campaign level \(level.id)")
            XCTAssertLessThanOrEqual(state.moves, level.parMoves)
        }
        XCTAssertTrue(LevelCatalog.campaign.suffix(12).contains { !$0.blocked.isEmpty })
        XCTAssertTrue(LevelCatalog.campaign.suffix(12).contains { $0.solution.count > $0.pieces.count })
    }

    func testDailyPuzzlesAreDeterministicAndSolvableAcrossDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let initial = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12))!
        let first = LevelCatalog.daily(for: initial)
        XCTAssertEqual(first, LevelCatalog.daily(for: initial.addingTimeInterval(60)))
        for offset in 0..<14 {
            let date = calendar.date(byAdding: .day, value: offset, to: initial)!
            let daily = LevelCatalog.daily(for: date)
            var state = GameState(level: daily)
            for action in daily.solution {
                XCTAssertNotEqual(state.apply(action), .blocked)
                assertValid(state)
            }
            XCTAssertTrue(state.isComplete)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: initial)!
        XCTAssertNotEqual(first.pieces, LevelCatalog.daily(for: tomorrow).pieces)
    }

    func testHintFindsAlignmentMoveWhenNoDirectExitExists() {
        var state = GameState(level: level(pieces: [piece(at: Cell(x: 3, y: 3))],
                                          gates: [Gate(color: .coral, side: .up, start: 0, span: 2)]))
        for _ in 0..<4 {
            guard !state.isComplete else { break }
            let hint = state.hint(maxVisited: 1_000)
            XCTAssertNotNil(hint)
            guard let action = hint else { return }
            XCTAssertNotEqual(state.apply(action), .blocked)
        }
        XCTAssertTrue(state.isComplete)
    }

    func testStateRoundTripPreservesMidGameAndRemainingSolution() throws {
        let level = LevelCatalog.campaign[11]
        var original = GameState(level: level)
        let prefix = max(1, level.solution.count / 2)
        for action in level.solution.prefix(prefix) { _ = original.apply(action) }
        let data = try JSONEncoder().encode(original)
        var restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(restored, original)
        for action in level.solution.dropFirst(prefix) { XCTAssertNotEqual(restored.apply(action), .blocked) }
        XCTAssertTrue(restored.isComplete)
    }

    func testCampaignRewardsAreMonotonicAndCannotBeFarmedByReplay() {
        let level = LevelCatalog.campaign[0]
        var progress = PrismCore.Progress()
        let first = progress.recordCompletion(level: level, moves: 99)
        XCTAssertEqual(first.stars, 1)
        XCTAssertEqual(first.coins, 35)
        XCTAssertTrue(first.isFirstCompletion)
        XCTAssertEqual(progress.highestUnlocked, 2)
        let improved = progress.recordCompletion(level: level, moves: 3)
        XCTAssertEqual(improved.stars, 3)
        XCTAssertEqual(improved.coins, 20)
        XCTAssertFalse(improved.isFirstCompletion)
        let replay = progress.recordCompletion(level: level, moves: 4)
        XCTAssertEqual(replay.coins, 0)
        XCTAssertEqual(progress.stars[1], 3)
        XCTAssertEqual(progress.bestMoves[1], 3)
        XCTAssertEqual(progress.coins, 175)
        XCTAssertEqual(progress.stats.totalWins, 3)
    }

    func testDailyRewardsAwardOnceAndDoNotUnlockCampaign() {
        var progress = PrismCore.Progress()
        let daily = LevelCatalog.daily(for: Date(timeIntervalSince1970: 1_795_046_400))
        let first = progress.recordCompletion(level: daily, moves: daily.parMoves, dailyKey: "2026-09-26")
        let duplicate = progress.recordCompletion(level: daily, moves: daily.parMoves, dailyKey: "2026-09-26")
        XCTAssertEqual(first.coins, 75)
        XCTAssertEqual(duplicate.coins, 0)
        XCTAssertEqual(progress.completedDailyKeys, ["2026-09-26"])
        XCTAssertEqual(progress.highestUnlocked, 1)
        XCTAssertTrue(progress.stars.isEmpty)
        XCTAssertEqual(progress.stats.dailyWins, 1)
    }

    func testDailyStreakHandlesMissedDaysAndExpiredDisplay() {
        var progress = PrismCore.Progress()
        let level = LevelCatalog.campaign[0]
        for key in ["2026-09-23", "2026-09-24", "2026-09-26"] {
            progress.recordCompletion(level: level, moves: 3, dailyKey: key)
        }
        XCTAssertEqual(progress.stats.currentDailyStreak, 1)
        XCTAssertEqual(progress.stats.bestDailyStreak, 2)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 12))!
        let missed = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
        XCTAssertEqual(progress.currentDailyStreak(for: tomorrow), 1)
        XCTAssertEqual(progress.currentDailyStreak(for: missed), 0)
    }

    func testInitialAndResumedSolutionHintsNeedNoSearchBudget() {
        let level = LevelCatalog.campaign[11]
        var state = GameState(level: level)
        for _ in 0..<level.solution.count {
            guard !state.isComplete else { break }
            guard let action = state.hint(maxVisited: 1) else {
                XCTFail("A known solution hint should not require search")
                return
            }
            XCTAssertNotEqual(state.apply(action), .blocked)
        }
        XCTAssertTrue(state.isComplete, "Repeated hints must skip any cycle in the recorded proof")
        XCTAssertNil(state.hint(maxVisited: 1))
    }

    func testZeroHintBudgetAndStrictLimitReturnImmediately() {
        let state = GameState(level: level(pieces: [piece(at: Cell(x: 3, y: 3))],
                                          gates: [Gate(color: .coral, side: .up, start: 0, span: 2)]))
        XCTAssertNil(state.hint(maxVisited: 0))
        XCTAssertNil(state.hint(maxVisited: 1))
        XCTAssertNil(state.hint(maxVisited: -1))
        XCTAssertNil(GameState(level: LevelCatalog.campaign[0]).hint(maxVisited: 0))
    }

    func testGeneratorMatchesIndependentReferenceBoard() {
        // This fixture was produced by the independently written Python geometry audit.
        let third = LevelCatalog.campaign[2]
        let signature = third.pieces.map { piece in
            "\(piece.id):\(piece.color.rawValue):\(piece.origin.x),\(piece.origin.y):" +
                piece.cells.map { "\($0.x),\($0.y)" }.joined(separator: "/")
        }.joined(separator: ";")
        XCTAssertEqual(signature, "1:mint:2,5:0,0/1,0;2:amber:3,2:0,0/1,0/0,1/1,1;3:violet:0,7:0,0/1,0;4:violet:0,2:0,0/0,1/1,0/1,1")
        XCTAssertEqual(third.solution.count, 10)
    }

    func testProgressPersistenceAndMissingFieldMigration() throws {
        var progress = PrismCore.Progress()
        progress.recordCompletion(level: LevelCatalog.campaign[5], moves: 15)
        let data = try JSONEncoder().encode(progress)
        XCTAssertEqual(try JSONDecoder().decode(PrismCore.Progress.self, from: data), progress)
        let oldData = Data("{\"coins\":240}".utf8)
        let migrated = try JSONDecoder().decode(PrismCore.Progress.self, from: oldData)
        XCTAssertEqual(migrated.coins, 240)
        XCTAssertEqual(migrated.highestUnlocked, 1)
        XCTAssertTrue(migrated.stars.isEmpty)
    }
}
