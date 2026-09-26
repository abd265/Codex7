import XCTest
@testable import PrismCore

final class ChallengeHintTests: XCTestCase {
    func testEveryChallengeCanFollowItsRecordedHintRouteWithoutSearch() {
        for level in ChallengeCatalog.levels {
            var state = GameState(level: level)
            for _ in 0...level.solution.count {
                if state.isComplete { break }
                guard let hint = state.hint(maxVisited: 1) else {
                    XCTFail("Missing recorded hint in challenge \(level.id)")
                    break
                }
                XCTAssertNotEqual(state.apply(hint), .blocked, "Challenge \(level.id)")
            }
            XCTAssertTrue(state.isComplete, "Challenge \(level.id)")
            XCTAssertNil(state.hint(maxVisited: 150_000))
        }
    }

    func testLegalOffRouteDetoursStillProduceLegalChallengeHints() {
        for (stage, index) in [0, 7, 13].enumerated() {
            let level = ChallengeCatalog.levels[index]
            var planned = GameState(level: level)
            var route: Set<String> = [planned.stateKey]
            for move in level.solution { _ = planned.apply(move); route.insert(planned.stateKey) }
            var original = GameState(level: level)
            for move in level.solution.prefix(level.solution.count * stage / 4) { _ = original.apply(move) }
            var detour: GameState?
            for action in original.legalMoves {
                var candidate = original
                if candidate.apply(action) == .moved, !route.contains(candidate.stateKey) {
                    detour = candidate; break
                }
            }
            guard var state = detour else {
                XCTFail("Expected an off-route reversible detour for challenge \(level.id)")
                continue
            }
            XCTAssertNil(state.hint(maxVisited: 0))
            guard let hint = state.hint(maxVisited: 150_000) else {
                XCTFail("No hint after a reversible detour in challenge \(level.id)")
                continue
            }
            XCTAssertNotEqual(state.apply(hint), .blocked, "Challenge \(level.id)")
        }
    }

    func testPackedSearchRespectsFixedWallsAndReachesAnAlignedGate() {
        let piece = Piece(id: 4, color: .coral, cells: [Cell(x: 0, y: 0)], origin: Cell(x: 3, y: 3))
        let level = Level(id: 101, title: "Hint fixture", pieces: [piece],
                          gates: [Gate(color: .coral, side: .up, start: 0, span: 1)],
                          blocked: [Cell(x: 2, y: 2), Cell(x: 1, y: 2), Cell(x: 0, y: 2)])
        var state = GameState(level: level)
        XCTAssertNil(ChallengeHintSolver.firstGesture(state, maxVisited: 1))
        for _ in 0..<6 {
            if state.isComplete { break }
            guard let action = ChallengeHintSolver.firstGesture(state, maxVisited: 5_000) else {
                XCTFail("The prism must route around the wall before aligning with the gate")
                return
            }
            XCTAssertNotEqual(state.apply(action), .blocked)
        }
        XCTAssertTrue(state.isComplete)
    }

    func testPackedSearchCannotExitConcaveShapeThroughItsOccupiedNotch() {
        let elbow = Piece(id: 1, color: .coral,
                          cells: [Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)],
                          origin: Cell(x: 0, y: 0))
        let trapped = Level(id: 101, title: "Swept-cell fixture", columns: 2, rows: 2,
                            pieces: [elbow], gates: [Gate(color: .coral, side: .up, start: 0, span: 2)],
                            blocked: [Cell(x: 1, y: 0)])
        let state = GameState(level: trapped)
        XCTAssertFalse(state.canMove(pieceID: 1, direction: .up))
        XCTAssertNil(ChallengeHintSolver.firstGesture(state, maxVisited: 1_000))
    }

    func testPackedSearchHonorsAllFourGateSidesAndPieceIDs() {
        for direction in Direction.allCases {
            let piece = Piece(id: 42, color: .mint, cells: [Cell(x: 0, y: 0), Cell(x: 1, y: 0)],
                              origin: Cell(x: 2, y: 3))
            let level = Level(id: 101, title: "Exit fixture", pieces: [piece],
                              gates: [Gate(color: .mint, side: direction, start: 2, span: 2)])
            var state = GameState(level: level)
            guard let action = ChallengeHintSolver.firstGesture(state, maxVisited: 5_000) else {
                XCTFail("No route to \(direction) gate"); continue
            }
            XCTAssertEqual(action.pieceID, 42)
            XCTAssertEqual(state.apply(action), .exited)
        }
    }
}
