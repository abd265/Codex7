import Foundation

/// A board stores only fully in-bounds pieces. Crossing a gate completes the entire exit atomically.
public struct GameState: Codable, Equatable, Sendable {
    public let level: Level
    public private(set) var pieces: [Piece]
    public private(set) var moves: Int
    public var clearedCount: Int { level.pieces.count - pieces.count }
    public var isComplete: Bool { pieces.isEmpty }

    public init(level: Level) { self.level = level; self.pieces = level.pieces; self.moves = 0 }

    public mutating func move(pieceID: Int, direction: Direction, steps: Int = 1) -> MoveResult {
        guard steps > 0, let index = pieces.firstIndex(where: { $0.id == pieceID }) else { return .blocked }
        let obstacles = Set(level.blocked + pieces.filter { $0.id != pieceID }.flatMap(\.worldCells))
        var piece = pieces[index]
        var didMove = false
        // A legal request can never need more than the larger board dimension to reach an edge.
        for _ in 0..<min(steps, max(level.columns, level.rows) + 1) {
            let next = piece.translated(by: direction.delta)
            if next.worldCells.allSatisfy({ level.contains($0) }) {
                guard next.worldCells.allSatisfy({ !obstacles.contains($0) }) else { break }
                piece = next
                didMove = true
            } else {
                if canExit(piece, direction: direction, obstacles: obstacles) {
                    pieces.remove(at: index)
                    moves += 1
                    return .exited
                }
                break
            }
        }
        guard didMove else { return .blocked }
        pieces[index] = piece
        moves += 1
        return .moved
    }

    @discardableResult
    public mutating func apply(_ move: PuzzleMove) -> MoveResult {
        self.move(pieceID: move.pieceID, direction: move.direction, steps: move.steps)
    }

    public func canMove(pieceID: Int, direction: Direction, steps: Int = 1) -> Bool {
        var copy = self
        return copy.move(pieceID: pieceID, direction: direction, steps: steps) != .blocked
    }

    /// Slide as far as possible with one gesture.
    @discardableResult
    public mutating func slide(pieceID: Int, direction: Direction) -> MoveResult {
        move(pieceID: pieceID, direction: direction, steps: max(level.columns, level.rows) + 1)
    }

    public var legalMoves: [PuzzleMove] {
        var result: [PuzzleMove] = []
        for piece in pieces {
            for direction in Direction.allCases {
                var previous = stateKey
                for steps in 1...max(level.columns, level.rows) {
                    let action = PuzzleMove(pieceID: piece.id, direction: direction, steps: steps)
                    var copy = self
                    let outcome = copy.apply(action)
                    let key = copy.stateKey
                    guard outcome != .blocked, key != previous else { break }
                    result.append(action)
                    previous = key
                    if outcome == .exited { break }
                }
            }
        }
        return result
    }

    /// Returns a gesture from the recorded solution or a shortest route to another exit.
    /// Removing a piece can only free space, so an exit is always useful progress.
    /// Search is bounded to keep hints responsive even on a heavily rearranged board.
    public func hint(maxVisited: Int = 12_000) -> PuzzleMove? {
        guard !isComplete, maxVisited > 0 else { return nil }
        // The construction proof doubles as an instant hint route. Compare positions,
        // not move counters, so this also works after undoing or resuming a saved game.
        var planned = GameState(level: level)
        var knownNext: PuzzleMove?
        for action in level.solution {
            // A construction proof may revisit a board. Select its latest occurrence
            // so following repeated hints skips that reversible cycle.
            if planned.pieces == pieces { knownNext = action }
            if planned.apply(action) == .blocked { break }
        }
        if let action = knownNext { return action }
        // Most positions have a clear exit. Avoid enumerating intermediate positions
        // and allocating a search queue for that common case.
        for piece in pieces {
            for gate in level.gates where gate.color == piece.color {
                let action = PuzzleMove(pieceID: piece.id, direction: gate.side,
                                        steps: max(level.columns, level.rows) + 1)
                var probe = self
                if probe.apply(action) == .exited { return action }
            }
        }
        var queue: [(state: GameState, first: PuzzleMove?)] = [(self, nil)]
        var visited: Set<String> = [stateKey]
        var head = 0
        while head < queue.count && visited.count < maxVisited {
            let node = queue[head]
            head += 1
            for action in node.state.legalMoves {
                var next = node.state
                let result = next.apply(action)
                let first = node.first ?? action
                if result == .exited { return first }
                let key = next.stateKey
                if visited.insert(key).inserted {
                    queue.append((next, first))
                    if visited.count >= maxVisited { break }
                }
            }
        }
        return nil
    }

    private func canExit(_ piece: Piece, direction: Direction, obstacles: Set<Cell>) -> Bool {
        let projections = piece.worldCells.map { direction.isVertical ? $0.x : $0.y }
        guard let lower = projections.min(), let upper = projections.max(),
              level.gates.contains(where: {
                  $0.color == piece.color && $0.side == direction && $0.span > 0
                      && lower >= $0.start && upper < $0.start + $0.span
              }) else { return false }

        // Concave shapes sweep cells not occupied in their current footprint. Check every
        // intermediate translation until every cell has left, not just the leading edge.
        for distance in 1...(max(level.columns, level.rows) + max(piece.width, piece.height) + 1) {
            let cells = piece.translated(by: direction.delta * distance).worldCells
            let inside = cells.filter { level.contains($0) }
            if inside.contains(where: { obstacles.contains($0) }) { return false }
            // Never permit a shape to escape through a different side or past a corner.
            if cells.contains(where: { cell in
                switch direction {
                case .up: return cell.x < 0 || cell.x >= level.columns || cell.y >= level.rows
                case .down: return cell.x < 0 || cell.x >= level.columns || cell.y < 0
                case .left: return cell.y < 0 || cell.y >= level.rows || cell.x >= level.columns
                case .right: return cell.y < 0 || cell.y >= level.rows || cell.x < 0
                }
            }) { return false }
            if inside.isEmpty { return true }
        }
        return false
    }

    internal var stateKey: String {
        pieces.sorted { $0.id < $1.id }.map { "\($0.id):\($0.origin.x),\($0.origin.y)" }.joined(separator: ";")
    }
}
