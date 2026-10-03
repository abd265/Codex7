import Foundation
import Combine

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var curriculum: Curriculum?
    @Published private(set) var loadError: String?
    @Published private(set) var storageError: String?
    @Published var preferences = LearningPreferences() {
        didSet { if !isLoading { save() } }
    }
    @Published private(set) var progress = LearnerProgress()
    @Published private(set) var familyWords: [DarjaWord] = []
    @Published private(set) var parentPINLockedUntil: Date?

    private var parentCredential: ParentCredential?
    private var isLoading = true
    private var canSaveState = true
    private let stateURL: URL
    private let calendar = Calendar.current

    init(bundle: Bundle = .main, stateURL: URL? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("--uitesting")
        let isScreenshot = arguments.contains { $0.hasPrefix("--screenshot-") }
        self.stateURL = stateURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(isUITesting || isScreenshot ? "DarjaTogether-UI-Tests" : "DarjaTogether", isDirectory: true)
            .appendingPathComponent("learning-state.json")
        loadCurriculum(bundle: bundle)
        if stateURL != nil || (!isUITesting && !isScreenshot) || arguments.contains("--preserve-progress") { loadState() }
        if isScreenshot { preferences.didOnboard = true }
        isLoading = false
    }

    var allWords: [DarjaWord] { (curriculum?.words ?? []) + familyWords }
    var currentWeek: WeekUnit? {
        let weeks = (curriculum?.weeks ?? []).sorted { $0.id < $1.id }
        return weeks.first { week in week.sessions.contains { !progress.completedSessions.contains($0.id) } } ?? weeks.last
    }
    var totalStars: Int { progress.stars }
    var completedSessionCount: Int { progress.completedSessions.count }
    var todayMinutes: Int { dailyMinutes(on: Date()) }
    var hasParentPIN: Bool { parentCredential != nil }
    var bookmarkedWords: [DarjaWord] { allWords.filter { progress.bookmarkedWordIDs.contains($0.id) } }
    var dueWords: [DarjaWord] {
        let now = Date()
        return allWords.filter { word in
            guard let review = progress.reviewStates[word.id] else { return false }
            return review.dueDate <= now
        }.sorted {
            (progress.reviewStates[$0.id]?.dueDate ?? .distantFuture) < (progress.reviewStates[$1.id]?.dueDate ?? .distantFuture)
        }
    }
    var earnedBadges: [LearningBadge] {
        var result: [LearningBadge] = []
        if completedSessionCount >= 1 {
            result.append(.init(id: "first-step", title: "First step", description: "You finished your first activity.", emoji: "🌱"))
        }
        if completedSessionCount >= 5 {
            result.append(.init(id: "five-activities", title: "Little explorer", description: "Five activities completed.", emoji: "🧭"))
        }
        if progress.reviewStates.values.filter({ $0.successfulReviews > 0 }).count >= 10 {
            result.append(.init(id: "ten-words", title: "Word collector", description: "You practised remembering ten words.", emoji: "🎒"))
        }
        if progress.skillCounts.values.filter({ $0 > 0 }).count == Skill.allCases.count {
            result.append(.init(id: "six-skills", title: "All-round explorer", description: "You tried all six skills.", emoji: "🌈"))
        }
        if !familyWords.isEmpty {
            result.append(.init(id: "family-word", title: "Family connection", description: "Your family added a special word.", emoji: "🏡"))
        }
        if completedSessionCount >= 30 {
            result.append(.init(id: "thirty-activities", title: "Darja adventurer", description: "Thirty activities completed. Keep exploring!", emoji: "⭐️"))
        }
        return result
    }

    func word(id: String) -> DarjaWord? { allWords.first { $0.id == id } }
    func words(ids: [String]) -> [DarjaWord] {
        let lookup = Dictionary(allWords.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { lookup[$0] }
    }
    func story(id: String) -> DarjaStory? { curriculum?.stories.first { $0.id == id } }
    func sessions(for week: WeekUnit) -> [LessonSession] { week.sessions }
    func isBookmarked(_ word: DarjaWord) -> Bool { progress.bookmarkedWordIDs.contains(word.id) }
    func isBookmarked(_ wordID: String) -> Bool { progress.bookmarkedWordIDs.contains(wordID) }
    func isSessionComplete(_ session: LessonSession) -> Bool { progress.completedSessions.contains(session.id) }
    func skillCount(_ skill: Skill) -> Int { progress.skillCounts[skill.rawValue, default: 0] }
    func dailyMinutes(on date: Date) -> Int { progress.dailyMinutes[dayKey(for: date), default: 0] }

    func recordPractice(skill: Skill, minutes: Int = 1) {
        let now = Date()
        progress.skillCounts[skill.rawValue, default: 0] += 1
        progress.dailyMinutes[dayKey(for: now), default: 0] += max(0, min(minutes, 30))
        progress.lastActivity = now
        save()
    }

    /// Completions count participation, never a pronunciation or proficiency score.
    func completeSession(_ session: LessonSession, weekId: Int, skills: [Skill]? = nil, minutes: Int = 2) {
        guard let week = curriculum?.weeks.first(where: { $0.id == weekId }),
              week.sessions.contains(where: { $0.id == session.id }) else { return }
        let now = Date()
        let firstCompletion = progress.completedSessions.insert(session.id).inserted
        if firstCompletion { progress.stars += 3 }
        for skill in Set(skills ?? session.skills) {
            progress.skillCounts[skill.rawValue, default: 0] += 1
        }
        progress.dailyMinutes[dayKey(for: now), default: 0] += max(0, min(minutes, 30))
        progress.lastActivity = now
        for wordID in session.wordIds where word(id: wordID) != nil && progress.reviewStates[wordID] == nil {
            progress.reviewStates[wordID] = WordReviewState(dueDate: now, intervalDays: 0, successfulReviews: 0, lastReviewed: nil)
        }
        save()
    }

    /// Child self-report drives a gentle 1, 3, 7, 14, 30-day review schedule.
    func reviewWord(_ word: DarjaWord, remembered: Bool) {
        guard self.word(id: word.id) != nil else { return }
        let now = Date()
        let result = LearningRules.nextReview(previous: progress.reviewStates[word.id], remembered: remembered, at: now, calendar: calendar)
        if result.earnsStar { progress.stars += 1 }
        progress.reviewStates[word.id] = result.state
        progress.lastActivity = now
        save()
    }

    func reviewWord(_ wordID: String, remembered: Bool) {
        guard let item = word(id: wordID) else { return }
        reviewWord(item, remembered: remembered)
    }

    func toggleBookmark(_ word: DarjaWord) {
        if progress.bookmarkedWordIDs.contains(word.id) { progress.bookmarkedWordIDs.remove(word.id) }
        else { progress.bookmarkedWordIDs.insert(word.id) }
        save()
    }

    func toggleBookmark(_ wordID: String) {
        guard let item = word(id: wordID) else { return }
        toggleBookmark(item)
    }

    @discardableResult
    func addFamilyWord(arabic: String, transliteration: String, english: String, french: String = "", emoji: String = "🏡") -> DarjaWord? {
        let arabicText = arabic.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !arabicText.isEmpty, !meaning.isEmpty else { return nil }
        let word = DarjaWord(id: "family-" + UUID().uuidString.lowercased(), arabic: String(arabicText.prefix(120)),
                             transliteration: String(transliteration.prefix(160)), english: String(meaning.prefix(160)),
                             french: String(french.prefix(160)), emoji: emoji.isEmpty ? "🏡" : String(emoji.prefix(4)),
                             category: "Our family", note: "A word or expression from your family. Regional wording can vary.")
        familyWords.append(word)
        save()
        return word
    }

    func deleteFamilyWord(_ word: DarjaWord) {
        guard familyWords.contains(where: { $0.id == word.id }) else { return }
        familyWords.removeAll { $0.id == word.id }
        progress.bookmarkedWordIDs.remove(word.id)
        progress.reviewStates.removeValue(forKey: word.id)
        save()
    }

    func deleteFamilyWord(_ wordID: String) {
        guard let item = familyWords.first(where: { $0.id == wordID }) else { return }
        deleteFamilyWord(item)
    }

    /// Clears learning history while keeping preferences, family words and the parent PIN.
    func resetProgress() {
        progress = LearnerProgress()
        save()
    }

    @discardableResult
    func setParentPIN(_ pin: String) -> Bool {
        guard let credential = ParentPINRules.makeCredential(pin: pin) else { return false }
        parentCredential = credential
        parentPINLockedUntil = nil
        save()
        return true
    }

    func verifyParentPIN(_ pin: String) -> Bool {
        guard let credential = parentCredential else { return false }
        let result = ParentPINRules.verify(pin: pin, credential: credential, at: Date())
        parentPINLockedUntil = result.credential.lockedUntil
        parentCredential = result.credential
        save()
        return result.accepted
    }

    private func dayKey(for date: Date) -> String {
        LearningRules.dayKey(for: date, calendar: calendar)
    }

    private func loadCurriculum(bundle: Bundle) {
        guard let url = bundle.url(forResource: "curriculum", withExtension: "json") else {
            loadError = "The lesson library is missing. Please reinstall this build of Darja Together."
            return
        }
        do {
            let content = try JSONDecoder().decode(Curriculum.self, from: Data(contentsOf: url))
            guard content.version == 1, !content.weeks.isEmpty, !content.words.isEmpty,
                  Set(content.words.map(\.id)).count == content.words.count else {
                loadError = "The lesson library could not be read. Please update this build."
                return
            }
            curriculum = content
        } catch {
            loadError = "The lesson library could not be read. Please update this build."
        }
    }

    private func loadState() {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return }
        do {
            let state = try JSONDecoder().decode(SavedLearningState.self, from: Data(contentsOf: stateURL))
            guard state.version == 1 else {
                canSaveState = false
                storageError = "Saved progress comes from a newer app version. Update the app to use it."
                return
            }
            preferences = state.preferences
            progress = state.progress
            familyWords = state.familyWords
            parentCredential = state.parentCredential
            parentPINLockedUntil = state.parentCredential?.lockedUntil
        } catch {
            // Preserve the unreadable original before allowing a new state to be saved.
            let recoveryURL = stateURL.deletingPathExtension().appendingPathExtension("recovery-\(Int(Date().timeIntervalSince1970)).json")
            do { try FileManager.default.copyItem(at: stateURL, to: recoveryURL) }
            catch { canSaveState = false; storageError = "Saved progress could not be read or backed up. Changes will not be saved until the app is restarted."; return }
            storageError = "Saved progress could not be read. A recovery copy is kept on this device."
        }
    }

    private func save() {
        guard !isLoading, canSaveState else { return }
        let state = SavedLearningState(preferences: preferences, progress: progress, familyWords: familyWords, parentCredential: parentCredential)
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(state).write(to: stateURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            if storageError?.contains("recovery copy") != true { storageError = nil }
        } catch {
            storageError = "Progress could not be saved on this device. Free some storage and try again."
        }
    }
}
