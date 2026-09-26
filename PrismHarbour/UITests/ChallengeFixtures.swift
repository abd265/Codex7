// Generated from the shipped first challenge; native UI tests perform real drag gestures.
enum ChallengeFixtures {
    static let firstTitle = "Make a Little Space"
    static let pieces: [Int: (width: Int, height: Int, cellX: Int, cellY: Int)] = [
        1: (2, 2, 0, 0),
        2: (2, 2, 0, 0),
        3: (2, 2, 0, 0),
        4: (1, 3, 0, 0),
        5: (2, 2, 0, 0),
        6: (2, 2, 0, 0),
        7: (1, 3, 0, 0),
        8: (1, 2, 0, 0),
        9: (2, 1, 0, 0),
        10: (2, 1, 0, 0),
    ]
    static let solution: [(pieceID: Int, dx: Int, dy: Int, steps: Int)] = [
        (5, -1, 0, 1),
        (5, 0, -1, 1),
        (9, 1, 0, 4),
        (7, 0, 1, 2),
        (9, 0, 1, 1),
        (3, 0, 1, 3),
        (8, 1, 0, 2),
        (8, 0, -1, 4),
        (6, 0, 1, 3),
        (2, 1, 0, 3),
        (2, 0, -1, 1),
        (10, 0, -1, 3),
        (4, 0, -1, 5),
        (1, -1, 0, 2),
        (5, -1, 0, 2),
        (5, 0, 1, 2),
        (3, -1, 0, 4),
        (3, 0, -1, 7),
        (6, -1, 0, 3),
        (6, 0, -1, 4),
    ]
}
