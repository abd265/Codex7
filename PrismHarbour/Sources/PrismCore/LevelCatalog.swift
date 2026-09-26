import Foundation

public enum LevelCatalog {
    public static let campaignCount = 36
    public static let regionNames = ["Lantern Bay", "Coral Cove", "Moonlit Marina"]
    public static let campaign: [Level] = (1...campaignCount).map { number in
        if number == 1 { return introduction }
        if number == 2 { return firstCrossing }
        return makeLevel(id: number, difficulty: number, seed: UInt64(number) &* 7_919 &+ 0x505249534D)
    }

    public static func daily(for date: Date = Date()) -> Level {
        let key = Progress.dailyKey(for: date)
        // FNV-1a is explicit: Swift's randomized Hasher must never select daily puzzles.
        let seed = key.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        return makeLevel(id: 10_000 + Int(seed % 1_000_000), difficulty: 27 + Int(seed % 10),
                         seed: seed, title: "Daily Current")
    }

    private static let introduction = Level(
        id: 1, title: "Welcome Aboard", region: 0, timeLimit: 120, parMoves: 3,
        pieces: [
            Piece(id: 1, color: .coral, cells: shape([(0, 0), (0, 1)]), origin: Cell(x: 0, y: 3)),
            Piece(id: 2, color: .mint, cells: shape([(0, 0), (1, 0)]), origin: Cell(x: 4, y: 4)),
            Piece(id: 3, color: .amber, cells: shape([(0, 0), (1, 0), (1, 1)]), origin: Cell(x: 2, y: 1))
        ], gates: [
            Gate(color: .coral, side: .up, start: 0, span: 2),
            Gate(color: .mint, side: .down, start: 4, span: 2),
            Gate(color: .amber, side: .right, start: 1, span: 2)
        ], solution: [PuzzleMove(pieceID: 1, direction: .up, steps: 4),
                      PuzzleMove(pieceID: 2, direction: .down, steps: 4),
                      PuzzleMove(pieceID: 3, direction: .right, steps: 3)]
    )

    private static let firstCrossing = Level(
        id: 2, title: "Make Some Room", region: 0, timeLimit: 150, parMoves: 5,
        pieces: [
            Piece(id: 1, color: .coral, cells: shape([(0, 0), (0, 1)]), origin: Cell(x: 2, y: 3)),
            Piece(id: 2, color: .amber, cells: shape([(0, 0), (1, 0), (0, 1), (1, 1)]), origin: Cell(x: 0, y: 1)),
            Piece(id: 3, color: .mint, cells: shape([(0, 0), (1, 0)]), origin: Cell(x: 3, y: 6))
        ], gates: [
            Gate(color: .coral, side: .up, start: 0, span: 2),
            Gate(color: .amber, side: .left, start: 1, span: 2),
            Gate(color: .mint, side: .down, start: 4, span: 2)
        ], solution: [PuzzleMove(pieceID: 2, direction: .left),
                      PuzzleMove(pieceID: 1, direction: .left, steps: 2),
                      PuzzleMove(pieceID: 1, direction: .up, steps: 4),
                      PuzzleMove(pieceID: 3, direction: .right),
                      PuzzleMove(pieceID: 3, direction: .down, steps: 2)]
    )

    private static func shape(_ coordinates: [(Int, Int)]) -> [Cell] {
        coordinates.map { Cell(x: $0.0, y: $0.1) }
    }

    private static let titles = [
        "Welcome Aboard", "Make Some Room", "Little Detour", "Crosswinds", "Tidal Steps", "Colour Crossing",
        "Quiet Inlet", "Dockside Dance", "Harbour Lights", "Coral Passage", "Open Water", "Quay Master",
        "Fresh Current", "Marina Maze", "Passing Places", "Drifting Apart", "Mint Condition", "Ripple Effect",
        "The Long Way", "Mooring Lines", "Narrow Waters", "Turning Tide", "Safe Passage", "Marina Master",
        "Evening Glow", "Violet Voyage", "Hidden Channel", "Moonlit Mooring", "The Weave", "Tidal Lock",
        "Deep Water", "Starboard Story", "A Perfect Exit", "Final Crossing", "Northern Lights", "Harbour Master"
    ]

    private static func gates(for variant: Int) -> [Gate] {
        switch variant % 3 {
        case 0:
            return [Gate(color: .coral, side: .up, start: 0, span: 2),
                    Gate(color: .amber, side: .up, start: 4, span: 2),
                    Gate(color: .mint, side: .left, start: 1, span: 2),
                    Gate(color: .sky, side: .right, start: 1, span: 2),
                    Gate(color: .violet, side: .left, start: 5, span: 2),
                    Gate(color: .rose, side: .right, start: 5, span: 2)]
        case 1:
            return [Gate(color: .coral, side: .up, start: 2, span: 2),
                    Gate(color: .amber, side: .down, start: 0, span: 2),
                    Gate(color: .mint, side: .down, start: 4, span: 2),
                    Gate(color: .sky, side: .left, start: 1, span: 2),
                    Gate(color: .violet, side: .right, start: 3, span: 2),
                    Gate(color: .rose, side: .left, start: 5, span: 2)]
        default:
            return [Gate(color: .coral, side: .up, start: 0, span: 2),
                    Gate(color: .amber, side: .up, start: 4, span: 2),
                    Gate(color: .mint, side: .down, start: 0, span: 2),
                    Gate(color: .sky, side: .down, start: 4, span: 2),
                    Gate(color: .violet, side: .left, start: 3, span: 2),
                    Gate(color: .rose, side: .right, start: 3, span: 2)]
        }
    }

    private static func makeLevel(id: Int, difficulty: Int, seed: UInt64, title: String? = nil) -> Level {
        let levelGates = gates(for: difficulty)
        let blockedPatterns: [[Cell]] = [
            [Cell(x: 2, y: 3)], [Cell(x: 3, y: 4)],
            [Cell(x: 1, y: 3), Cell(x: 4, y: 4)],
            [Cell(x: 2, y: 2), Cell(x: 3, y: 5)],
            [Cell(x: 2, y: 3), Cell(x: 3, y: 4)],
            [Cell(x: 1, y: 4), Cell(x: 4, y: 3), Cell(x: 2, y: 6)]
        ]
        let blocked = difficulty < 7 ? [] : blockedPatterns[(difficulty / 3) % blockedPatterns.count]
        let target = min(9, 4 + (difficulty - 3) / 5)
        var best: (pieces: [Piece], solution: [PuzzleMove], score: Int)?
        // Every candidate is constructed by inserting pieces into empty space and making
        // reversible moves. Reversing that history is a proof of solvability, not a guess.
        for attempt in 0..<8 {
            var random = HarbourRandom(seed: seed &+ UInt64(attempt) &* 104_729)
            var draft = Draft(gates: levelGates, blocked: blocked)
            for pieceID in 1...target {
                var inserted = false
                for _ in 0..<40 {
                    let startingGate = random.next(levelGates.count)
                    for offset in 0..<levelGates.count {
                        let gate = levelGates[(startingGate + offset) % levelGates.count]
                        let shapeNumber = random.next(difficulty < 10 ? 4 : 6)
                        let cells = pieceShape(shapeNumber, vertical: gate.side.isVertical)
                        let width = cells.map(\.x).max()! + 1
                        let height = cells.map(\.y).max()! + 1
                        let transverse = gate.side.isVertical ? width : height
                        let alignment = gate.start + random.next(gate.span - transverse + 1)
                        let origin: Cell
                        switch gate.side {
                        case .up: origin = Cell(x: alignment, y: 0)
                        case .right: origin = Cell(x: 6 - width, y: alignment)
                        case .down: origin = Cell(x: alignment, y: 8 - height)
                        case .left: origin = Cell(x: 0, y: alignment)
                        }
                        let piece = Piece(id: pieceID, color: gate.color, cells: cells, origin: origin)
                        if draft.insert(piece, gate: gate) {
                            inserted = true
                            _ = draft.translate(pieceID: pieceID, direction: gate.side.opposite, steps: 1 + random.next(3))
                            break
                        }
                    }
                    if inserted { break }
                    if !draft.shuffle(using: &random) { break }
                }
                if !inserted { break }
                for _ in 0..<(1 + difficulty / 12) { _ = draft.shuffle(using: &random) }
            }
            for _ in 0..<(3 + difficulty / 6) { _ = draft.shuffle(using: &random) }
            let solution = draft.solution()
            let score = draft.pieces.count * 100 + min(solution.count, target * 4) * 3 - draft.directExitCount * 14
            if best == nil || score > best!.score { best = (draft.pieces, solution, score) }
        }
        let chosen = best!
        return Level(id: id, title: title ?? titles[min(campaignCount, max(1, id)) - 1],
                     region: min(2, (difficulty - 1) / 12), timeLimit: 150 + difficulty * 5,
                     parMoves: max(chosen.pieces.count, chosen.solution.count), pieces: chosen.pieces,
                     gates: levelGates, blocked: blocked, solution: chosen.solution)
    }

    private static func pieceShape(_ number: Int, vertical: Bool) -> [Cell] {
        let points: [(Int, Int)]
        switch number {
        case 0: points = [(0, 0), (0, 1)]
        case 1: points = [(0, 0), (1, 0)]
        case 2: points = [(0, 0), (0, 1), (1, 1)]
        case 3: points = [(0, 0), (1, 0), (0, 1), (1, 1)]
        case 4: points = [(0, 0), (0, 1), (0, 2), (1, 2)]
        default: points = [(0, 0), (1, 0), (1, 1), (1, 2)]
        }
        return points.map { vertical ? Cell(x: $0.0, y: $0.1) : Cell(x: $0.1, y: $0.0) }
    }

    private struct Draft {
        let gates: [Gate]
        let blocked: [Cell]
        var pieces: [Piece] = []
        // Each entry is an action that undoes the immediately preceding construction step.
        var undoHistory: [PuzzleMove] = []
        var board: Level { Level(id: 0, title: "Draft", pieces: pieces, gates: gates, blocked: blocked) }

        mutating func insert(_ piece: Piece, gate: Gate) -> Bool {
            let obstacles = Set(blocked + pieces.flatMap(\.worldCells))
            guard piece.worldCells.allSatisfy({ board.contains($0) && !obstacles.contains($0) }) else { return false }
            let probe = Level(id: 0, title: "Insertion", pieces: pieces + [piece], gates: gates, blocked: blocked)
            var state = GameState(level: probe)
            guard state.move(pieceID: piece.id, direction: gate.side) == .exited else { return false }
            pieces.append(piece)
            undoHistory.append(PuzzleMove(pieceID: piece.id, direction: gate.side))
            return true
        }

        @discardableResult
        mutating func translate(pieceID: Int, direction: Direction, steps: Int) -> Bool {
            guard let index = pieces.firstIndex(where: { $0.id == pieceID }), steps > 0 else { return false }
            let obstacles = Set(blocked + pieces.filter { $0.id != pieceID }.flatMap(\.worldCells))
            var moved = pieces[index]
            for _ in 0..<steps {
                let next = moved.translated(by: direction.delta)
                guard next.worldCells.allSatisfy({ board.contains($0) && !obstacles.contains($0) }) else { return false }
                moved = next
            }
            pieces[index] = moved
            undoHistory.append(PuzzleMove(pieceID: pieceID, direction: direction.opposite, steps: steps))
            return true
        }

        mutating func shuffle(using random: inout HarbourRandom) -> Bool {
            guard !pieces.isEmpty else { return false }
            let start = random.next(pieces.count)
            let directionStart = random.next(4)
            for pieceOffset in 0..<pieces.count {
                let pieceID = pieces[(start + pieceOffset) % pieces.count].id
                for directionOffset in 0..<4 {
                    let direction = Direction.allCases[(directionStart + directionOffset) % 4]
                    if let last = undoHistory.last, last.pieceID == pieceID && last.direction == direction { continue }
                    for distance in stride(from: 1 + random.next(3), through: 1, by: -1) {
                        if translate(pieceID: pieceID, direction: direction, steps: distance) { return true }
                    }
                }
            }
            return false
        }

        var directExitCount: Int {
            let state = GameState(level: board)
            return pieces.filter { piece in
                gates.filter { $0.color == piece.color }.contains { gate in
                    var probe = state
                    return probe.slide(pieceID: piece.id, direction: gate.side) == .exited
                }
            }.count
        }

        func solution() -> [PuzzleMove] {
            var state = GameState(level: board)
            var result: [PuzzleMove] = []
            for undo in undoHistory.reversed() {
                // Shorten the construction proof by releasing any piece that can leave now.
                // Early removals never invalidate the remaining reverse moves.
                var released = true
                while released {
                    released = false
                    for piece in state.pieces.reversed() {
                        for gate in gates where gate.color == piece.color {
                            var probe = state
                            let action = PuzzleMove(pieceID: piece.id, direction: gate.side, steps: 9)
                            if probe.apply(action) == .exited {
                                state = probe
                                result.append(action)
                                released = true
                                break
                            }
                        }
                        if released { break }
                    }
                }
                if state.isComplete { break }
                if state.pieces.contains(where: { $0.id == undo.pieceID }), state.apply(undo) != .blocked {
                    result.append(undo)
                }
            }
            precondition(state.isComplete, "Reverse construction must yield a complete solution")
            return result
        }
    }
}

private struct HarbourRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(_ upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Int(value % UInt64(upperBound))
    }
}
