import Foundation
import XCTest
@testable import PrismCore

/// Validates the shipped boards with the production move engine, independently of the offline solver.
final class ChallengeCatalogTests: XCTestCase {
    private func assertValidPosition(_ state: GameState, file: StaticString = #filePath, line: UInt = #line) {
        let occupied = state.pieces.flatMap(\.worldCells)
        XCTAssertEqual(Set(occupied).count, occupied.count, "Overlapping prisms in challenge \(state.level.id)",
                       file: file, line: line)
        XCTAssertTrue(occupied.allSatisfy { state.level.contains($0) },
                      "A prism is partly outside challenge \(state.level.id)", file: file, line: line)
        XCTAssertTrue(Set(occupied).isDisjoint(with: state.level.blocked),
                      "A prism overlaps a wall in challenge \(state.level.id)", file: file, line: line)
    }

    func testCatalogIdentityNamesTiersAndLookupBoundaries() {
        XCTAssertEqual(ChallengeCatalog.count, 20)
        XCTAssertEqual(ChallengeCatalog.levels.count, 20)
        XCTAssertEqual(ChallengeCatalog.levels.map(\.id), Array(101...120))
        XCTAssertEqual(Set(ChallengeCatalog.levels.map(\.title)).count, 20)
        var tierNamesByRegion: [Int: String] = [:]
        for (index, level) in ChallengeCatalog.levels.enumerated() {
            XCTAssertEqual(ChallengeCatalog.number(for: level.id), index + 1)
            XCTAssertEqual(ChallengeCatalog.level(id: level.id), level)
            XCTAssertFalse(level.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let tier = ChallengeCatalog.tierName(for: level.id)
            XCTAssertFalse(tier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let existing = tierNamesByRegion[level.region] { XCTAssertEqual(tier, existing) }
            tierNamesByRegion[level.region] = tier
        }
        XCTAssertGreaterThanOrEqual(tierNamesByRegion.count, 3, "The voyage should progress through distinct tiers")
        XCTAssertEqual(Set(tierNamesByRegion.values).count, tierNamesByRegion.count)
        for invalid in [Int.min, -1, 0, 1, 36, 99, 100, 121, 1_000, 10_000, Int.max] {
            XCTAssertNil(ChallengeCatalog.number(for: invalid), "Invalid challenge ID \(invalid)")
            XCTAssertNil(ChallengeCatalog.level(id: invalid), "Invalid challenge ID \(invalid)")
        }
    }

    func testEveryInitialBoardHasNormalizedNonoverlappingGeometryAndValidGates() {
        for level in ChallengeCatalog.levels {
            XCTAssertEqual(level.columns, 6, "Challenge \(level.id)")
            XCTAssertEqual(level.rows, 8, "Challenge \(level.id)")
            XCTAssertGreaterThanOrEqual(level.pieces.count, 2)
            XCTAssertLessThanOrEqual(level.pieces.count, 10, "The packed hint solver supports up to ten live prisms")
            XCTAssertEqual(Set(level.pieces.map(\.id)).count, level.pieces.count)
            XCTAssertEqual(Set(level.blocked).count, level.blocked.count)
            XCTAssertTrue(level.blocked.allSatisfy { level.contains($0) })
            XCTAssertFalse(level.gates.isEmpty)
            XCTAssertEqual(Set(level.gates).count, level.gates.count)
            for gate in level.gates {
                XCTAssertGreaterThanOrEqual(gate.start, 0, "Challenge \(level.id)")
                XCTAssertGreaterThan(gate.span, 0)
                XCTAssertLessThanOrEqual(gate.start + gate.span, gate.side.isVertical ? level.columns : level.rows)
            }
            for piece in level.pieces {
                XCTAssertFalse(piece.cells.isEmpty)
                XCTAssertEqual(Set(piece.cells).count, piece.cells.count)
                XCTAssertEqual(piece.cells.map(\.x).min(), 0)
                XCTAssertEqual(piece.cells.map(\.y).min(), 0)
                XCTAssertTrue(piece.cells.allSatisfy { $0.x >= 0 && $0.y >= 0 })
                XCTAssertTrue(level.contains(piece.origin))
                XCTAssertTrue(level.gates.contains { $0.color == piece.color }, "A prism has no matching gate")
            }
            assertValidPosition(GameState(level: level))
        }
    }

    func testEveryExactSolutionCertificateClearsItsBoardAtTheThreeStarTarget() {
        for level in ChallengeCatalog.levels {
            XCTAssertFalse(level.solution.isEmpty, "Challenge \(level.id) has no certificate")
            XCTAssertEqual(level.parMoves, level.solution.count, "Stars must use the verified gesture count")
            var state = GameState(level: level)
            for (index, action) in level.solution.enumerated() {
                XCTAssertGreaterThan(action.steps, 0)
                XCTAssertFalse(state.isComplete, "Challenge \(level.id) has trailing certificate moves")
                XCTAssertNotEqual(state.apply(action), .blocked,
                                  "Invalid certificate move \(index + 1) in challenge \(level.id): \(action)")
                assertValidPosition(state)
            }
            XCTAssertTrue(state.isComplete, "Certificate did not solve challenge \(level.id)")
            XCTAssertEqual(state.clearedCount, level.pieces.count)
            XCTAssertEqual(state.moves, level.parMoves)
            XCTAssertEqual(PrismCore.Progress.starsEarned(moves: state.moves, parMoves: level.parMoves), 3)
            XCTAssertEqual(PrismCore.Progress.starsEarned(moves: state.moves + 1, parMoves: level.parMoves), 2)
        }
    }

    func testEveryChallengeRequiresCooperationBeforeAnyPrismCanLeave() {
        for level in ChallengeCatalog.levels {
            let initial = GameState(level: level)
            for piece in initial.pieces {
                // Other pieces never move. Explore every reachable origin of this one prism using
                // unit translations; GameState itself checks collision, gate fit, and atomic exits.
                var queue = [initial], visited: Set<Cell> = [piece.origin], head = 0
                var escaped = false
                while head < queue.count && !escaped {
                    let state = queue[head]; head += 1
                    for direction in Direction.allCases {
                        var candidate = state
                        switch candidate.move(pieceID: piece.id, direction: direction, steps: 1) {
                        case .blocked: continue
                        case .exited: escaped = true
                        case .moved:
                            guard let moved = candidate.pieces.first(where: { $0.id == piece.id }) else {
                                XCTFail("A move lost its prism without an exit"); continue
                            }
                            if visited.insert(moved.origin).inserted { queue.append(candidate) }
                        }
                        if escaped { break }
                    }
                }
                XCTAssertFalse(escaped,
                    "Challenge \(level.id) lets prism \(piece.id) leave without repositioning any other prism")
                XCTAssertLessThanOrEqual(visited.count, level.columns * level.rows)
            }
        }
    }
}
