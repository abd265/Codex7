import Foundation
import SwiftUI
import AVFoundation
import UIKit
#if canImport(PrismCore)
import PrismCore
#endif

struct HarbourSettings: Codable {
    var sound = true
    var haptics = true
    var symbols = true
    var relaxed = false
}

struct VoyageSession: Codable {
    var id = UUID()
    var game: GameState
    var remaining: Double
    var relaxed: Bool
    var dailyKey: String?
    var history: [GameState] = []
}

/// Ephemeral presentation data; never encoded into a saved voyage.
struct HarbourMoveEvent: Identifiable, Equatable {
    let id = UUID()
    let piece: Piece
    let direction: Direction
    let result: MoveResult
    let target: Piece?
    let createdAt: Date
    let combo: Int
}

private struct HarbourSave: Codable {
    var version = 1
    var progress = Progress()
    var settings = HarbourSettings()
    var session: VoyageSession?
}

@MainActor
final class HarbourStore: ObservableObject {
    @Published var progress = Progress()
    @Published var settings = HarbourSettings()
    @Published var session: VoyageSession?
    @Published var playing = false
    @Published var paused = false
    @Published var reward: CompletionReward?
    @Published var hintMove: PuzzleMove?
    @Published var findingHint = false
    @Published var toast: String?
    @Published var selectedPiece: Int?
    @Published var showHelp = false
    @Published var showSettings = false
    @Published var homeTab = 0
    @Published private(set) var moveEvent: HarbourMoveEvent?
    @Published private(set) var comboCount = 0
    private var lastTick = Date()
    private var lastSave = Date()
    private var soundPlayers: [AVAudioPlayer] = []
    private var soundCategoryConfigured = false
    private var lastDockAt: Date?
    private var celebrationSoundTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private let saveURL: URL
    private let screenshotMode: Bool

    var currentLevel: Level { session?.game.level ?? LevelCatalog.campaign[0] }
    var isDaily: Bool { session?.dailyKey != nil }
    var expired: Bool { session.map { !$0.relaxed && $0.remaining <= 0 && !$0.game.isComplete } ?? false }
    var completedCount: Int { progress.stars.count }
    var totalStars: Int { progress.stars.values.reduce(0,+) }
    var nextLevel: Level { LevelCatalog.campaign[min(max(1, progress.highestUnlocked), LevelCatalog.campaign.count)-1] }
    var dailyCompleted: Bool { progress.completedDailyKeys.contains(Progress.dailyKey(for: Date())) }

    init() {
        let args = ProcessInfo.processInfo.arguments
        screenshotMode = args.contains("--ui-testing") || args.contains(where: { $0.hasPrefix("--screenshot-") })
        let directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("PrismHarbour",isDirectory:true)
        saveURL = directory.appendingPathComponent("voyage.json")
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            if !screenshotMode, FileManager.default.fileExists(atPath:saveURL.path) {
                let saved = try JSONDecoder().decode(HarbourSave.self,from:Data(contentsOf:saveURL))
                progress = saved.progress; settings = saved.settings; session = saved.session
            }
        } catch {
            let backup = directory.appendingPathComponent("voyage-recovery-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at:saveURL,to:backup)
            toast = "Your previous save was kept as a recovery copy."
        }
        if args.contains("--screenshot-play") {
            start(LevelCatalog.campaign[min(11,LevelCatalog.campaign.count-1)])
        }
        if args.contains("--screenshot-library") { homeTab = 1 }
    }

    func save() {
        guard !screenshotMode else { return }
        do {
            let data = try JSONEncoder().encode(HarbourSave(progress:progress,settings:settings,session:session))
            try data.write(to:saveURL,options:.atomic)
        } catch { toast = "Couldn’t save this voyage. Please check your device’s storage." }
        lastSave = Date()
    }

    func start(_ level: Level, daily: Bool = false) {
        resetMoveFeedback()
        session = VoyageSession(game:GameState(level:level),remaining:Double(level.timeLimit),relaxed:daily ? false : settings.relaxed,dailyKey:daily ? Progress.dailyKey(for:Date()) : nil)
        reward = nil; hintMove = nil; selectedPiece = nil; paused = false; playing = true; lastTick = Date(); save()
    }

    func continueVoyage() {
        if let session, !session.game.isComplete, session.remaining > 0 || session.relaxed {
            resetMoveFeedback()
            playing = true; paused = false; reward = nil; lastTick = Date()
        } else { start(nextLevel) }
    }

    func retry() {
        guard let old = session else { return }
        resetMoveFeedback()
        let level = old.game.level
        session = VoyageSession(game:GameState(level:level),remaining:Double(level.timeLimit),relaxed:old.relaxed,dailyKey:old.dailyKey)
        reward = nil; hintMove = nil; selectedPiece = nil; paused = false; lastTick = Date(); save()
    }

    func leaveGame() { resetMoveFeedback(); playing = false; paused = false; reward = nil; hintMove = nil; save() }
    func setPaused(_ value: Bool) { paused = value; lastTick = Date(); save() }
    func suspend() { if playing && reward == nil && !expired { paused = true }; save() }

    func tick() {
        let now = Date(); defer { lastTick = now }
        guard playing, !paused, reward == nil, !expired, !screenshotMode, var active = session, !active.relaxed, !active.game.isComplete else { return }
        active.remaining = max(0,active.remaining-now.timeIntervalSince(lastTick))
        session = active
        if active.remaining == 0 { feedback(.warning); save() }
        else if now.timeIntervalSince(lastSave) >= 5 { save() }
    }

    func move(pieceID: Int, direction: Direction, steps: Int) {
        guard playing, !paused, reward == nil, !expired, var active = session else { return }
        let previous = active.game
        guard let piece = previous.pieces.first(where: { $0.id == pieceID }) else { return }
        let result = active.game.move(pieceID:pieceID,direction:direction,steps:max(1,steps))
        let now = Date()
        if result == .exited {
            comboCount = lastDockAt.map { now.timeIntervalSince($0) < 5 ? comboCount + 1 : 1 } ?? 1
            lastDockAt = now
        }
        // Each UUID starts exactly one visual response, even for repeated blocked swipes.
        moveEvent = HarbourMoveEvent(piece:piece,direction:direction,result:result,
                                     target:active.game.pieces.first(where: { $0.id == pieceID }),
                                     createdAt:now,combo:comboCount)
        guard result != .blocked else {
            if settings.haptics { UIImpactFeedbackGenerator(style:.rigid).impactOccurred(intensity:0.35) }
            sound("block")
            return
        }
        active.history.append(previous)
        if active.history.count > 100 { active.history.removeFirst() }
        session = active; hintMove = nil
        if result == .exited { selectedPiece = nil; feedback(.success); sound("dock") }
        else { selectedPiece = pieceID; impact(); sound("move") }
        if active.game.isComplete {
            reward = progress.recordCompletion(level:active.game.level,moves:active.game.moves,dailyKey:active.dailyKey)
            let completedSessionID = active.id
            celebrationSoundTask?.cancel()
            celebrationSoundTask = Task {
                // Let the final dock chime finish its attack before the victory flourish.
                try? await Task.sleep(nanoseconds:350_000_000)
                guard !Task.isCancelled, playing, session?.id == completedSessionID, reward != nil else { return }
                sound("win")
            }
        }
        save()
    }

    func undo() {
        guard !paused, !expired, reward == nil, var active = session, let previous = active.history.popLast() else { return }
        resetMoveFeedback()
        active.game = previous; session = active; hintMove = nil; selectedPiece = nil; impact(); save()
    }

    func addTime() {
        guard var active = session, !active.relaxed, reward == nil else { return }
        guard progress.coins >= 30 else { announce("You need 30 pearls. Earn more by clearing new levels."); return }
        progress.coins -= 30; active.remaining += 30; session = active; paused = false; lastTick = Date(); impact(); save()
        announce("30 seconds of calm seas added.")
    }

    func requestHint() {
        guard !paused, !expired, reward == nil, !findingHint, let state = session?.game else { return }
        guard progress.coins >= 15 else { announce("Hints cost 15 pearls. You can always undo or restart for free."); return }
        findingHint = true
        let sessionID = session?.id
        Task {
            let move = await Task.detached(priority:.userInitiated) { state.hint(maxVisited:12000) }.value
            findingHint = false
            guard playing, !paused, session?.id == sessionID, session?.game == state, !expired, reward == nil else { return }
            if let move {
                guard progress.coins >= 15 else { announce("You need 15 pearls for a hint."); return }
                hintMove = move; selectedPiece = move.pieceID; progress.coins -= 15; save()
                announce("Move the glowing prism \(String(describing:move.direction)).")
            } else { announce("No route found from here. Undo a move or restart for free.") }
        }
    }

    func announce(_ message:String) {
        toastTask?.cancel(); toast = message
        toastTask = Task { try? await Task.sleep(nanoseconds:3_500_000_000); if !Task.isCancelled { toast = nil } }
    }
    func resetProgress() {
        resetMoveFeedback()
        progress = Progress(); session = nil; reward = nil; playing = false; save(); announce("A fresh voyage awaits.")
    }
    func impact() { if settings.haptics { UIImpactFeedbackGenerator(style:.soft).impactOccurred() } }
    func feedback(_ type:UINotificationFeedbackGenerator.FeedbackType) { if settings.haptics { UINotificationFeedbackGenerator().notificationOccurred(type) } }
    private func resetMoveFeedback() {
        moveEvent = nil; comboCount = 0; lastDockAt = nil
        celebrationSoundTask?.cancel(); celebrationSoundTask = nil
        soundPlayers.forEach { $0.stop() }
        soundPlayers.removeAll()
    }

    func sound(_ name:String) {
        guard settings.sound, let url = Bundle.main.url(forResource:name,withExtension:"wav") else { return }
        if !soundCategoryConfigured {
            do {
                // Ambient respects the iPhone silent switch and mixes with the player's music.
                try AVAudioSession.sharedInstance().setCategory(.ambient,mode:.default,options:.mixWithOthers)
                soundCategoryConfigured = true
            } catch { return }
        }
        // Short, independent voices preserve the tail of a dock while another piece moves.
        // Interrupted sounds are never resumed; a fresh interaction creates a fresh voice.
        soundPlayers.removeAll { !$0.isPlaying }
        if soundPlayers.count >= 8 { soundPlayers.removeFirst().stop() }
        guard let player = try? AVAudioPlayer(contentsOf:url) else { return }
        player.volume = name == "move" ? 0.25 : name == "block" ? 0.22 : 0.42
        player.prepareToPlay()
        if player.play() { soundPlayers.append(player) }
    }
}
