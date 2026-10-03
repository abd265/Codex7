#if canImport(CryptoKit)
import XCTest
@testable import DarjaCore

final class ParentPINRulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_985_600)

    func testPINFormatAndSalting() throws {
        for invalid in ["", "123", "12345", "12ab", "١٢٣٤"] {
            XCTAssertNil(ParentPINRules.makeCredential(pin: invalid))
        }
        let first = try XCTUnwrap(ParentPINRules.makeCredential(pin: "8134"))
        let second = try XCTUnwrap(ParentPINRules.makeCredential(pin: "8134"))
        XCTAssertNotEqual(first.salt, second.salt)
        XCTAssertNotEqual(first.digest, second.digest)
        XCTAssertNotEqual(first.digest, "8134")
        XCTAssertTrue(ParentPINRules.verify(pin: "8134", credential: first, at: now).accepted)
        XCTAssertFalse(ParentPINRules.verify(pin: "0000", credential: first, at: now).accepted)
    }

    func testFiveFailuresLockEvenCorrectPINUntilTimeout() throws {
        var credential = try XCTUnwrap(ParentPINRules.makeCredential(pin: "8134"))
        for _ in 0..<5 { credential = ParentPINRules.verify(pin: "0000", credential: credential, at: now).credential }
        XCTAssertEqual(credential.lockedUntil, now.addingTimeInterval(60))
        XCTAssertFalse(ParentPINRules.verify(pin: "8134", credential: credential, at: now.addingTimeInterval(59)).accepted)
        let unlocked = ParentPINRules.verify(pin: "8134", credential: credential, at: now.addingTimeInterval(60))
        XCTAssertTrue(unlocked.accepted)
        XCTAssertNil(unlocked.credential.lockedUntil)
        XCTAssertEqual(unlocked.credential.failedAttempts, 0)
    }

    func testExpiredLockDoesNotLeaveAnOldWaitMessage() throws {
        var credential = try XCTUnwrap(ParentPINRules.makeCredential(pin: "8134"))
        credential.lockedUntil = now
        let result = ParentPINRules.verify(pin: "0000", credential: credential, at: now.addingTimeInterval(1))
        XCTAssertFalse(result.accepted)
        XCTAssertNil(result.credential.lockedUntil)
        XCTAssertEqual(result.credential.failedAttempts, 1)
    }

    func testCredentialAndFamilyProgressSurviveAtomicStateFileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DarjaPINTest-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("learning-state.json")
        var progress = LearnerProgress()
        progress.completedSessions = ["w1-s1"]
        var credential = try XCTUnwrap(ParentPINRules.makeCredential(pin: "8134"))
        credential = ParentPINRules.verify(pin: "0000", credential: credential, at: now).credential
        let state = SavedLearningState(preferences: LearningPreferences(), progress: progress, familyWords: [], parentCredential: credential)
        let encoded = try JSONEncoder().encode(state)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("\"8134\""))
        try encoded.write(to: url, options: .atomic)
        let restored = try JSONDecoder().decode(SavedLearningState.self, from: Data(contentsOf: url))
        XCTAssertEqual(restored.progress.completedSessions, ["w1-s1"])
        XCTAssertFalse(restored.preferences.microphoneEnabled)
        XCTAssertEqual(restored.preferences.avatar, .nadia)
        let savedCredential = try XCTUnwrap(restored.parentCredential)
        XCTAssertEqual(savedCredential.failedAttempts, 1)
        XCTAssertTrue(ParentPINRules.verify(pin: "8134", credential: savedCredential, at: now).accepted)
    }
}
#endif
