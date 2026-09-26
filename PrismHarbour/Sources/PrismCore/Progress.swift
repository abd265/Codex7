import Foundation

public struct PlayStats: Codable, Equatable, Sendable {
    public var totalWins: Int = 0
    public var totalMoves: Int = 0
    public var dailyWins: Int = 0
    public var currentDailyStreak: Int = 0
    public var bestDailyStreak: Int = 0
    public init() {}
}

public struct CompletionReward: Equatable, Sendable {
    public let stars: Int
    public let coins: Int
    public let isFirstCompletion: Bool
    public let newlyUnlockedLevel: Int?
}

public struct Progress: Codable, Equatable, Sendable {
    public var highestUnlocked: Int
    public var coins: Int
    public var stars: [Int: Int]
    public var bestMoves: [Int: Int]
    public var completedDailyKeys: [String]
    public var stats: PlayStats
    public init(highestUnlocked: Int = 1, coins: Int = 120, stars: [Int: Int] = [:],
                bestMoves: [Int: Int] = [:], completedDailyKeys: [String] = [], stats: PlayStats = PlayStats()) {
        self.highestUnlocked = highestUnlocked; self.coins = coins; self.stars = stars
        self.bestMoves = bestMoves; self.completedDailyKeys = completedDailyKeys; self.stats = stats
    }

    public static func starsEarned(moves: Int, parMoves: Int) -> Int {
        if moves <= max(1, parMoves) { return 3 }
        if moves <= max(2, parMoves + max(2, parMoves / 2)) { return 2 }
        return 1
    }

    @discardableResult
    public mutating func recordCompletion(level: Level, moves: Int, dailyKey: String? = nil) -> CompletionReward {
        let earned = Self.starsEarned(moves: moves, parMoves: level.parMoves)
        stats.totalWins += 1
        stats.totalMoves += max(0, moves)
        if let key = dailyKey {
            let first = !completedDailyKeys.contains(key)
            if first {
                completedDailyKeys.append(key)
                completedDailyKeys.sort()
                stats.dailyWins += 1
                recalculateDailyStreak()
            }
            let award = first ? 75 : 0
            coins += award
            return CompletionReward(stars: earned, coins: award, isFirstCompletion: first, newlyUnlockedLevel: nil)
        }
        let previousStars = stars[level.id] ?? 0
        let first = previousStars == 0
        stars[level.id] = max(previousStars, earned)
        bestMoves[level.id] = min(bestMoves[level.id] ?? Int.max, max(0, moves))
        let priorUnlock = highestUnlocked
        highestUnlocked = max(highestUnlocked, min(LevelCatalog.campaignCount, level.id + 1))
        let award = (first ? 25 : 0) + max(0, earned - previousStars) * 10
        coins += award
        return CompletionReward(stars: earned, coins: award, isFirstCompletion: first,
                                newlyUnlockedLevel: highestUnlocked > priorUnlock ? highestUnlocked : nil)
    }

    /// A challenge changes at midnight in the player's current time zone.
    public static func dailyKey(for date: Date = Date()) -> String {
        dayFormatter().string(from: date)
    }

    /// Expires the displayed streak after a missed day without modifying saved progress.
    public func currentDailyStreak(for date: Date = Date()) -> Int {
        let formatter = Self.dayFormatter()
        guard let latestKey = completedDailyKeys.max(), let latest = formatter.date(from: latestKey) else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let elapsed = calendar.dateComponents([.day], from: latest, to: calendar.startOfDay(for: date)).day ?? 2
        return (0...1).contains(elapsed) ? stats.currentDailyStreak : 0
    }

    private static func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private mutating func recalculateDailyStreak() {
        let formatter = Self.dayFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let dates = Set(completedDailyKeys).compactMap { formatter.date(from: $0) }.sorted()
        var run = 0
        var best = 0
        var previous: Date?
        for date in dates {
            if let prior = previous, calendar.dateComponents([.day], from: prior, to: date).day == 1 {
                run += 1
            } else { run = 1 }
            best = max(best, run)
            previous = date
        }
        stats.currentDailyStreak = run
        stats.bestDailyStreak = max(stats.bestDailyStreak, best)
    }

    private enum CodingKeys: String, CodingKey {
        case highestUnlocked, coins, stars, bestMoves, completedDailyKeys, stats
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        highestUnlocked = try values.decodeIfPresent(Int.self, forKey: .highestUnlocked) ?? 1
        coins = try values.decodeIfPresent(Int.self, forKey: .coins) ?? 120
        stars = try values.decodeIfPresent([Int: Int].self, forKey: .stars) ?? [:]
        bestMoves = try values.decodeIfPresent([Int: Int].self, forKey: .bestMoves) ?? [:]
        completedDailyKeys = try values.decodeIfPresent([String].self, forKey: .completedDailyKeys) ?? []
        stats = try values.decodeIfPresent(PlayStats.self, forKey: .stats) ?? PlayStats()
    }
}
