import Foundation
import XCTest
@testable import PrismCore

final class ChallengeProgressTests: XCTestCase {
    func testVersionTwoProgressMigratesWithoutChangingOriginalVoyage() throws {
        // This is the schema shipped before Challenge Voyage, including a completed campaign.
        let legacy = Data("""
        {
          "highestUnlocked": 36,
          "coins": 1845,
          "stars": {"1": 3, "12": 2, "36": 3},
          "bestMoves": {"1": 9, "12": 22, "36": 17},
          "completedDailyKeys": ["2026-09-25", "2026-09-26"],
          "stats": {"totalWins": 41, "totalMoves": 763, "dailyWins": 2,
                    "currentDailyStreak": 2, "bestDailyStreak": 2}
        }
        """.utf8)
        let migrated = try JSONDecoder().decode(PrismCore.Progress.self, from: legacy)
        XCTAssertEqual(migrated.highestUnlocked, 36)
        XCTAssertEqual(migrated.coins, 1845)
        XCTAssertEqual(migrated.stars, [1: 3, 12: 2, 36: 3])
        XCTAssertEqual(migrated.bestMoves, [1: 9, 12: 22, 36: 17])
        XCTAssertEqual(migrated.completedDailyKeys, ["2026-09-25", "2026-09-26"])
        XCTAssertEqual(migrated.stats.totalWins, 41)
        XCTAssertEqual(migrated.stats.totalMoves, 763)
        XCTAssertEqual(migrated.stats.dailyWins, 2)
        XCTAssertEqual(migrated.stats.currentDailyStreak, 2)
        XCTAssertEqual(migrated.stats.bestDailyStreak, 2)
        XCTAssertEqual(migrated.challengeHighestUnlocked, 1)
        XCTAssertEqual(migrated.challengeCompletedCount, 0)
        XCTAssertEqual(migrated.challengeTotalStars, 0)
        XCTAssertTrue(migrated.challengeStars.isEmpty)
        XCTAssertTrue(migrated.challengeBestMoves.isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(PrismCore.Progress.self,
                                               from: JSONEncoder().encode(migrated)), migrated)
    }

    func testChallengeCompletionUsesItsOwnUnlocksAndScores() {
        let level = ChallengeCatalog.levels[0]
        var progress = PrismCore.Progress(highestUnlocked: 7, coins: 240,
                                          stars: [1: 3, 6: 2], bestMoves: [1: 4, 6: 20])
        let reward = progress.recordCompletion(level: level, moves: level.parMoves)
        XCTAssertEqual(reward.stars, 3)
        XCTAssertEqual(reward.coins, 80)
        XCTAssertTrue(reward.isFirstCompletion)
        XCTAssertEqual(reward.newlyUnlockedLevel, 102)
        XCTAssertEqual(progress.coins, 320)
        XCTAssertEqual(progress.highestUnlocked, 7)
        XCTAssertEqual(progress.stars, [1: 3, 6: 2])
        XCTAssertEqual(progress.bestMoves, [1: 4, 6: 20])
        XCTAssertEqual(progress.challengeHighestUnlocked, 2)
        XCTAssertEqual(progress.challengeStars, [101: 3])
        XCTAssertEqual(progress.challengeBestMoves, [101: level.parMoves])
        XCTAssertEqual(progress.challengeCompletedCount, 1)
        XCTAssertEqual(progress.challengeTotalStars, 3)
        XCTAssertEqual(progress.stats.totalWins, 1)
        XCTAssertEqual(progress.stats.totalMoves, level.parMoves)
    }

    func testChallengeReplayOnlyRewardsImprovedStars() {
        let level = ChallengeCatalog.levels[0]
        var progress = PrismCore.Progress()
        let slowMoves = level.parMoves * 3 + 10
        let first = progress.recordCompletion(level: level, moves: slowMoves)
        XCTAssertEqual(first.stars, 1)
        XCTAssertEqual(first.coins, 60)
        let replay = progress.recordCompletion(level: level, moves: slowMoves)
        XCTAssertFalse(replay.isFirstCompletion)
        XCTAssertEqual(replay.coins, 0)
        XCTAssertNil(replay.newlyUnlockedLevel)
        let improvement = progress.recordCompletion(level: level, moves: level.parMoves)
        XCTAssertEqual(improvement.coins, 20)
        XCTAssertFalse(improvement.isFirstCompletion)
        XCTAssertEqual(progress.challengeStars[101], 3)
        XCTAssertEqual(progress.challengeBestMoves[101], level.parMoves)
        let worse = progress.recordCompletion(level: level, moves: slowMoves + 1)
        XCTAssertEqual(worse.coins, 0)
        XCTAssertEqual(progress.challengeStars[101], 3)
        XCTAssertEqual(progress.challengeBestMoves[101], level.parMoves)
        XCTAssertEqual(progress.coins, 200)
        XCTAssertEqual(progress.challengeCompletedCount, 1)
    }

    func testFinalChallengeDoesNotUnlockANonexistentLevelOrOriginalCampaign() {
        var progress = PrismCore.Progress(highestUnlocked: 36,
                                          challengeHighestUnlocked: ChallengeCatalog.count)
        let level = ChallengeCatalog.levels.last!
        let reward = progress.recordCompletion(level: level, moves: level.parMoves)
        XCTAssertEqual(progress.challengeHighestUnlocked, 20)
        XCTAssertNil(reward.newlyUnlockedLevel)
        XCTAssertEqual(progress.highestUnlocked, 36)
        XCTAssertTrue(progress.stars.isEmpty)
    }

    func testOriginalCampaignCompletionDoesNotAlterChallengeProgress() {
        var progress = PrismCore.Progress(challengeHighestUnlocked: 4,
                                          challengeStars: [101: 3, 102: 2, 103: 1],
                                          challengeBestMoves: [101: 12, 102: 20, 103: 30])
        let level = LevelCatalog.campaign[0]
        let reward = progress.recordCompletion(level: level, moves: level.parMoves)
        XCTAssertEqual(reward.coins, 55)
        XCTAssertEqual(reward.newlyUnlockedLevel, 2)
        XCTAssertEqual(progress.challengeHighestUnlocked, 4)
        XCTAssertEqual(progress.challengeStars, [101: 3, 102: 2, 103: 1])
        XCTAssertEqual(progress.challengeBestMoves, [101: 12, 102: 20, 103: 30])
    }

    func testDailyCompletionDoesNotUnlockEitherVoyage() {
        var progress = PrismCore.Progress(highestUnlocked: 36, challengeHighestUnlocked: 8)
        let level = ChallengeCatalog.levels[0]
        let reward = progress.recordCompletion(level: level, moves: level.parMoves, dailyKey: "2026-09-26")
        XCTAssertEqual(reward.coins, 75)
        XCTAssertNil(reward.newlyUnlockedLevel)
        XCTAssertEqual(progress.highestUnlocked, 36)
        XCTAssertEqual(progress.challengeHighestUnlocked, 8)
        XCTAssertTrue(progress.challengeStars.isEmpty)
        XCTAssertTrue(progress.stars.isEmpty)
        XCTAssertEqual(progress.stats.dailyWins, 1)
    }

    func testChallengeCountersExcludeUnrelatedIDs() {
        let progress = PrismCore.Progress(challengeStars: [1: 3, 101: 3, 102: 2, 120: 1, 10000: 3])
        XCTAssertEqual(progress.challengeCompletedCount, 3)
        XCTAssertEqual(progress.challengeTotalStars, 6)
    }

    func testBothVoyagesAndDailyProgressRoundTripTogether() throws {
        var progress = PrismCore.Progress()
        let campaign = LevelCatalog.campaign[0]
        let challenge = ChallengeCatalog.levels[0]
        progress.recordCompletion(level: campaign, moves: campaign.parMoves)
        progress.recordCompletion(level: challenge, moves: challenge.parMoves)
        progress.recordCompletion(level: campaign, moves: campaign.parMoves, dailyKey: "2026-09-26")
        let saved = try JSONEncoder().encode(progress)
        let restored = try JSONDecoder().decode(PrismCore.Progress.self, from: saved)
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.highestUnlocked, 2)
        XCTAssertEqual(restored.challengeHighestUnlocked, 2)
        XCTAssertEqual(restored.stars[1], 3)
        XCTAssertEqual(restored.challengeStars[101], 3)
        XCTAssertEqual(restored.coins, 330)
    }
}
