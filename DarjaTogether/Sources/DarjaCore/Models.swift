import Foundation

struct Curriculum: Codable {
    let version: Int
    let dialect: String
    let description: String
    let stages: [LearningStage]
    let words: [DarjaWord]
    let weeks: [WeekUnit]
    let stories: [DarjaStory]
    let pronunciationTips: [PronunciationTip]
    let parentGuidance: [String]
    let sources: [CurriculumSource]
}

struct LearningStage: Codable, Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let emoji: String
    let weeks: [Int]
}

struct DarjaWord: Codable, Identifiable, Hashable {
    let id: String
    var arabic: String
    var transliteration: String
    var english: String
    var french: String
    var emoji: String
    var category: String
    var note: String

    func meaning(in language: HelperLanguage) -> String {
        language == .french && !french.isEmpty ? french : english
    }

    var isFamilyWord: Bool { id.hasPrefix("family-") }
}

struct WeekUnit: Codable, Identifiable {
    let id: Int
    let stageId: Int
    let title: String
    let goal: String
    let wordIds: [String]
    let reviewWordIds: [String]
    let phrase: String
    let phraseTransliteration: String
    let phraseEnglish: String
    let phraseFrench: String
    let familyActivity: String
    let scriptFocus: String
    let sessions: [LessonSession]
    let storyId: String?
}

struct LessonSession: Codable, Identifiable {
    let id: String
    let title: String
    let kind: String
    let instructions: String
    let wordIds: [String]

    var skills: [Skill] {
        switch kind.lowercased() {
        case "listen", "listening", "listen-and-find": return [.listening, .vocabulary]
        case "speak", "speaking", "say", "echo": return [.speaking, .listening]
        case "read", "reading", "story": return [.reading, .vocabulary]
        case "write", "writing", "trace", "script": return [.writing, .reading]
        case "conversation", "chat", "roleplay", "role-play", "family": return [.conversation, .speaking]
        default: return [.vocabulary]
        }
    }
}

struct DarjaStory: Codable, Identifiable {
    let id: String
    let title: String
    let emoji: String
    let week: Int
    let lines: [StoryLine]
    let question: String
    let answer: String
}

struct StoryLine: Codable, Hashable {
    let arabic: String
    let transliteration: String
    let english: String
    let french: String
    let emoji: String

    func meaning(in language: HelperLanguage) -> String {
        language == .french ? french : english
    }
}

struct PronunciationTip: Codable, Identifiable {
    let symbol: String
    let explanation: String
    let exampleWordId: String
    var id: String { symbol }
}

struct CurriculumSource: Codable, Identifiable {
    let title: String
    let url: String
    let note: String
    var id: String { url }
}

enum HelperLanguage: String, Codable, CaseIterable, Identifiable {
    case english, french
    var id: String { rawValue }
    var displayName: String { self == .english ? "English" : "Français" }
    var speechCode: String { self == .english ? "en-US" : "fr-FR" }
}

enum LearnerAvatar: String, Codable, CaseIterable, Identifiable {
    case nadia, yacine, fennec
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .nadia: return "👧🏽"
        case .yacine: return "👦🏽"
        case .fennec: return "🦊"
        }
    }
}

enum Skill: String, Codable, CaseIterable, Identifiable {
    case listening, speaking, vocabulary, reading, writing, conversation
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .listening: return "👂"
        case .speaking: return "🗣️"
        case .vocabulary: return "🎒"
        case .reading: return "📖"
        case .writing: return "✏️"
        case .conversation: return "💬"
        }
    }
}

struct LearningPreferences: Codable, Equatable {
    var learnerName = "Explorer"
    var didOnboard = false
    var helperLanguage: HelperLanguage = .english
    var showTransliteration = true
    var showArabic = true
    var dailyMinutes = 8
    var microphoneEnabled = false
    var avatar: LearnerAvatar = .nadia
}

struct WordReviewState: Codable {
    var dueDate: Date
    var intervalDays: Int
    var successfulReviews: Int
    var lastReviewed: Date?
}

struct LearnerProgress: Codable {
    var completedSessions: Set<String> = []
    var skillCounts: [String: Int] = Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0.rawValue, 0) })
    var bookmarkedWordIDs: Set<String> = []
    var stars = 0
    var reviewStates: [String: WordReviewState] = [:]
    var dailyMinutes: [String: Int] = [:]
    var lastActivity: Date?
}

struct LearningBadge: Identifiable {
    let id: String
    let title: String
    let description: String
    let emoji: String
}

struct ParentCredential: Codable {
    let salt: String
    let digest: String
    var failedAttempts = 0
    var lockedUntil: Date?
}

struct SavedLearningState: Codable {
    var version = 1
    var preferences: LearningPreferences
    var progress: LearnerProgress
    var familyWords: [DarjaWord]
    var parentCredential: ParentCredential?
}
