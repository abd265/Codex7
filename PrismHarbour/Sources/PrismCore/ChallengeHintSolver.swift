import Foundation

/// A bounded search for the next removable prism, using the same atomic exit rules as GameState.
/// Each origin occupies six bits; each occupied board cell occupies one bit.
internal enum ChallengeHintSolver {
    static func firstGesture(_ state: GameState, maxVisited: Int) -> PuzzleMove? {
        guard maxVisited > 1, !state.isComplete, let board = PreparedBoard(state) else { return nil }
        guard let action = board.search(maxVisited: maxVisited) else { return nil }
        // Keep the public move engine as the final authority over every suggestion.
        var probe = state
        return probe.apply(action) == .blocked ? nil : action
    }

    private struct Edge {
        let target: Int
        let direction: Direction
        let steps: Int
        let swept: UInt64
    }
    private struct SearchNode {
        let state: UInt64
        let cost: Int
        let estimate: Int
        let first: PuzzleMove?
        func precedes(_ other: SearchNode) -> Bool {
            let score = cost + estimate, otherScore = other.cost + other.estimate
            if score != otherScore { return score < otherScore }
            if estimate != other.estimate { return estimate < other.estimate }
            return state < other.state
        }
    }
    private struct Heap {
        var nodes: [SearchNode] = []
        mutating func push(_ node: SearchNode) {
            nodes.append(node)
            var index = nodes.count - 1
            while index > 0 {
                let parent = (index - 1) / 2
                guard node.precedes(nodes[parent]) else { break }
                nodes[index] = nodes[parent]; index = parent
            }
            nodes[index] = node
        }
        mutating func pop() -> SearchNode? {
            guard let first = nodes.first else { return nil }
            let last = nodes.removeLast()
            guard !nodes.isEmpty else { return first }
            var index = 0
            while index * 2 + 1 < nodes.count {
                var child = index * 2 + 1
                if child + 1 < nodes.count, nodes[child + 1].precedes(nodes[child]) { child += 1 }
                guard nodes[child].precedes(last) else { break }
                nodes[index] = nodes[child]; index = child
            }
            nodes[index] = last
            return first
        }
    }

    private final class PreparedBoard {
        let level: Level
        let pieces: [Piece]
        var walls: UInt64 = 0
        var initial: UInt64 = 0
        var masks: [[UInt64]] = []
        var edges: [[[Edge]]] = []
        var distances: [[Int]] = []
        let unreachable = 999

        init?(_ state: GameState) {
            level = state.level; pieces = state.pieces
            guard level.columns > 0, level.rows > 0, level.columns * level.rows < 63,
                  !pieces.isEmpty, pieces.count <= 10,
                  Set(pieces.map(\.id)).count == pieces.count else { return nil }
            for cell in level.blocked {
                guard level.contains(cell) else { return nil }
                walls |= UInt64(1) << (cell.x + cell.y * level.columns)
            }
            for piece in pieces {
                // Shipped pieces are normalized; reject unsupported representations instead of guessing.
                guard !piece.cells.isEmpty, piece.cells.map(\.x).min() == 0,
                      piece.cells.map(\.y).min() == 0, level.contains(piece.origin),
                      Set(piece.cells).count == piece.cells.count else { return nil }
            }
            masks = Array(repeating: Array(repeating: 0, count: 64), count: pieces.count)
            edges = Array(repeating: Array(repeating: [], count: 64), count: pieces.count)
            distances = Array(repeating: Array(repeating: unreachable, count: 64), count: pieces.count)
            for index in pieces.indices {
                let piece = pieces[index]
                let start = piece.origin.x + piece.origin.y * level.columns
                initial |= UInt64(start) << (index * 6)
                for position in 0..<(level.columns * level.rows) {
                    let shape = footprint(index, x: position % level.columns,
                                          y: position / level.columns, direction: .up)
                    if !shape.outside, shape.mask & walls == 0 { masks[index][position] = shape.mask }
                }
                for position in 0..<(level.columns * level.rows) where masks[index][position] != 0 {
                    buildEdges(index, position: position)
                }
                var reverse = Array(repeating: [Int](), count: 64)
                for position in 0..<64 {
                    for edge in edges[index][position] { reverse[edge.target].append(position) }
                }
                distances[index][63] = 0
                var queue = [63], head = 0
                while head < queue.count {
                    let position = queue[head]; head += 1
                    for previous in reverse[position] where distances[index][previous] == unreachable {
                        distances[index][previous] = distances[index][position] + 1
                        queue.append(previous)
                    }
                }
            }
            var occupied = walls
            for index in pieces.indices {
                let mask = masks[index][position(initial, index)]
                guard mask != 0, occupied & mask == 0 else { return nil }
                occupied |= mask
            }
        }

        private func position(_ state: UInt64, _ piece: Int) -> Int {
            Int((state >> (piece * 6)) & 63)
        }
        private func replacing(_ state: UInt64, piece: Int, target: Int) -> UInt64 {
            (state & ~(UInt64(63) << (piece * 6))) | (UInt64(target) << (piece * 6))
        }
        private func footprint(_ index: Int, x: Int, y: Int, direction: Direction)
            -> (mask: UInt64, outside: Bool, wrongSide: Bool) {
            var mask: UInt64 = 0, outside = false, wrong = false
            for cell in pieces[index].cells {
                let cx = x + cell.x, cy = y + cell.y
                if cx >= 0, cx < level.columns, cy >= 0, cy < level.rows {
                    mask |= UInt64(1) << (cx + cy * level.columns)
                } else { outside = true }
                switch direction {
                case .up: wrong = wrong || cx < 0 || cx >= level.columns || cy >= level.rows
                case .down: wrong = wrong || cx < 0 || cx >= level.columns || cy < 0
                case .left: wrong = wrong || cy < 0 || cy >= level.rows || cx >= level.columns
                case .right: wrong = wrong || cy < 0 || cy >= level.rows || cx < 0
                }
            }
            return (mask, outside, wrong)
        }
        private func gateFits(_ index: Int, x: Int, y: Int, direction: Direction) -> Bool {
            let projections = pieces[index].cells.map { direction.isVertical ? x + $0.x : y + $0.y }
            guard let low = projections.min(), let high = projections.max() else { return false }
            return level.gates.contains {
                $0.color == pieces[index].color && $0.side == direction && $0.span > 0 &&
                    low >= $0.start && high < $0.start + $0.span
            }
        }
        private func buildEdges(_ index: Int, position: Int) {
            let x = position % level.columns, y = position / level.columns
            let maximum = max(level.columns, level.rows) + max(pieces[index].width, pieces[index].height) + 1
            for direction in Direction.allCases {
                let delta = direction.delta
                var swept: UInt64 = 0
                for step in 1...maximum {
                    let nx = x + delta.x * step, ny = y + delta.y * step
                    let shape = footprint(index, x: nx, y: ny, direction: direction)
                    swept |= shape.mask
                    if shape.wrongSide || swept & walls != 0 { break }
                    if !shape.outside {
                        edges[index][position].append(Edge(target: nx + ny * level.columns,
                            direction: direction, steps: step, swept: swept))
                        continue
                    }
                    guard gateFits(index, x: x, y: y, direction: direction) else { break }
                    // GameState exits atomically on the first out-of-bounds translation. The entire
                    // trailing shape must still clear obstacles, including the notch of a concave piece.
                    var valid = true, remaining = shape.mask
                    if remaining != 0, step < maximum {
                        for distance in (step + 1)...maximum {
                            let tail = footprint(index, x: x + delta.x * distance,
                                                 y: y + delta.y * distance, direction: direction)
                            swept |= tail.mask; remaining = tail.mask
                            if tail.wrongSide || swept & walls != 0 { valid = false; break }
                            if remaining == 0 { break }
                        }
                    }
                    if valid, remaining == 0 {
                        edges[index][position].append(Edge(target: 63, direction: direction,
                                                          steps: step, swept: swept))
                    }
                    break
                }
            }
        }
        private func estimate(_ state: UInt64) -> Int {
            var best = unreachable
            for index in pieces.indices { best = min(best, distances[index][position(state, index)]) }
            return best
        }
        func search(maxVisited: Int) -> PuzzleMove? {
            let initialEstimate = estimate(initial)
            guard initialEstimate < unreachable else { return nil }
            var open = Heap()
            open.push(SearchNode(state: initial, cost: 0, estimate: initialEstimate, first: nil))
            var costs: [UInt64: Int] = [initial: 0]
            costs.reserveCapacity(min(maxVisited, 150_000))
            while let node = open.pop() {
                guard costs[node.state] == node.cost else { continue }
                var occupied: UInt64 = 0
                for index in pieces.indices { occupied |= masks[index][position(node.state, index)] }
                // If this position has an exit, it reaches the search goal in one gesture.
                // Return that path immediately; removing a piece cannot obstruct later play.
                for index in pieces.indices {
                    let pos = position(node.state, index), other = occupied ^ masks[index][pos]
                    for edge in edges[index][pos] where edge.target == 63 && edge.swept & other == 0 {
                        return node.first ?? PuzzleMove(pieceID: pieces[index].id,
                                                       direction: edge.direction, steps: edge.steps)
                    }
                }
                for index in pieces.indices {
                    let pos = position(node.state, index), other = occupied ^ masks[index][pos]
                    for edge in edges[index][pos] where edge.target != 63 && edge.swept & other == 0 {
                        let next = replacing(node.state, piece: index, target: edge.target)
                        let cost = node.cost + 1
                        if let previous = costs[next], previous <= cost { continue }
                        let heuristic = estimate(next)
                        guard heuristic < unreachable else { continue }
                        if costs[next] == nil, costs.count >= maxVisited { return nil }
                        costs[next] = cost
                        let first = node.first ?? PuzzleMove(pieceID: pieces[index].id,
                                                             direction: edge.direction, steps: edge.steps)
                        open.push(SearchNode(state: next, cost: cost, estimate: heuristic, first: first))
                    }
                }
            }
            return nil
        }
    }
}
