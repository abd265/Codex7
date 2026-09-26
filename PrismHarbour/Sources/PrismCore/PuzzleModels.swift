import Foundation

public enum PrismColor: String, CaseIterable, Codable, Hashable, Sendable {
    case coral, amber, mint, sky, violet, rose
    public var displayName: String { rawValue.capitalized }
}

public enum Direction: String, CaseIterable, Codable, Hashable, Sendable {
    case up, right, down, left
    public var delta: Cell {
        switch self {
        case .up: return Cell(x: 0, y: -1)
        case .right: return Cell(x: 1, y: 0)
        case .down: return Cell(x: 0, y: 1)
        case .left: return Cell(x: -1, y: 0)
        }
    }
    public var opposite: Direction {
        switch self {
        case .up: return .down
        case .right: return .left
        case .down: return .up
        case .left: return .right
        }
    }
    public var isVertical: Bool { self == .up || self == .down }
}

public struct Cell: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
    public static func + (lhs: Cell, rhs: Cell) -> Cell {
        Cell(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    public static func * (lhs: Cell, rhs: Int) -> Cell {
        Cell(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

public struct Piece: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let color: PrismColor
    public let cells: [Cell]
    public var origin: Cell
    public init(id: Int, color: PrismColor, cells: [Cell], origin: Cell) {
        self.id = id; self.color = color; self.cells = cells; self.origin = origin
    }
    public var worldCells: [Cell] { cells.map { $0 + origin } }
    public var width: Int { (cells.map(\.x).max() ?? 0) - (cells.map(\.x).min() ?? 0) + 1 }
    public var height: Int { (cells.map(\.y).max() ?? 0) - (cells.map(\.y).min() ?? 0) + 1 }
    public func translated(by delta: Cell) -> Piece {
        Piece(id: id, color: color, cells: cells, origin: origin + delta)
    }
}

public struct Gate: Codable, Equatable, Hashable, Sendable {
    public let color: PrismColor
    public let side: Direction
    public let start: Int
    public let span: Int
    public init(color: PrismColor, side: Direction, start: Int, span: Int) {
        self.color = color; self.side = side; self.start = start; self.span = span
    }
}

public struct PuzzleMove: Codable, Equatable, Hashable, Sendable {
    public let pieceID: Int
    public let direction: Direction
    public let steps: Int
    public init(pieceID: Int, direction: Direction, steps: Int = 1) {
        self.pieceID = pieceID; self.direction = direction; self.steps = steps
    }
    public var reversed: PuzzleMove {
        PuzzleMove(pieceID: pieceID, direction: direction.opposite, steps: steps)
    }
}

public struct Level: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let region: Int
    public let columns: Int
    public let rows: Int
    public let timeLimit: Int
    public let parMoves: Int
    public let pieces: [Piece]
    public let gates: [Gate]
    public let blocked: [Cell]
    public let solution: [PuzzleMove]
    public init(id: Int, title: String, region: Int = 0, columns: Int = 6, rows: Int = 8,
                timeLimit: Int = 180, parMoves: Int = 12, pieces: [Piece], gates: [Gate],
                blocked: [Cell] = [], solution: [PuzzleMove] = []) {
        self.id = id; self.title = title; self.region = region
        self.columns = columns; self.rows = rows; self.timeLimit = timeLimit
        self.parMoves = parMoves; self.pieces = pieces; self.gates = gates
        self.blocked = blocked; self.solution = solution
    }
    public func contains(_ cell: Cell) -> Bool {
        cell.x >= 0 && cell.y >= 0 && cell.x < columns && cell.y < rows
    }
}

public enum MoveResult: String, Codable, Equatable, Sendable {
    case blocked, moved, exited
}
