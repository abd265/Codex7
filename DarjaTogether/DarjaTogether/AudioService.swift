import Foundation
import Combine
import AVFoundation
import CryptoKit
import UIKit

/// Audio stays on this device. Device Arabic speech is an approximation, not a Darja tutor.
@MainActor
final class AudioService: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published private(set) var isRecording = false
    @Published private(set) var isPlayingRecording = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var status = "Family voices are best for Darja. Device Arabic speech is an approximation."
    @Published private(set) var voiceLabel = "Device Arabic voice · not authentic Darja"

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtteranceID: ObjectIdentifier?
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingLimit: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var recordingKey: String?
    private var recordingStartedAt: Date?
    private var recordingPendingURL: URL?
    private var actionGeneration = 0
    private let recordingsDirectory: URL

    override init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testMode = arguments.contains("--uitesting") || arguments.contains { $0.hasPrefix("--screenshot-") }
        recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(testMode ? "DarjaTogether-UI-Tests" : "DarjaTogether", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        super.init()
        synthesizer.delegate = self
        // An interrupted app process can leave an unfinished clip; never retain it as a voice example.
        if let leftovers = try? FileManager.default.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil) {
            for url in leftovers where url.lastPathComponent.hasPrefix("pending-") && url.pathExtension == "m4a" {
                try? FileManager.default.removeItem(at: url)
            }
        }
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard typeValue == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in
                self?.stopAll()
                self?.status = "Audio paused. Tap a sound when you are ready."
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopAll() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in
                self?.stopAll()
                self?.status = "Your headphones disconnected. Tap to play again."
            }
        })
    }

    deinit {
        recordingLimit?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func sourceLabel(for word: DarjaWord) -> String {
        hasRecording(wordId: "family-" + word.id) ? "Family voice · recorded on this device" : "Device Arabic voice · not authentic Darja"
    }

    func speak(_ word: DarjaWord, helperLanguage: HelperLanguage = .english) {
        // Never use a child's practice recording as a pronunciation example.
        let familyKey = "family-" + word.id
        if hasRecording(wordId: familyKey) {
            voiceLabel = "Family voice · recorded on this device"
            playRecording(wordId: familyKey)
        } else {
            speakArabic(word.arabic)
        }
    }

    func speakArabic(_ text: String) {
        stopAll()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ar") }
        guard let voice = voices.first(where: { $0.language == "ar-DZ" }) ?? voices.first else {
            status = "No Arabic voice is installed. Use a family recording, or add an Arabic voice in iPhone Accessibility settings."
            return
        }
        voiceLabel = "Device Arabic voice · not authentic Darja"
        status = "This device voice may say Darja differently. Listen to a family voice when you can."
        speak(text, voice: voice)
    }

    func speakHelper(_ text: String, language: HelperLanguage) {
        stopAll()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let voice = AVSpeechSynthesisVoice(language: language.speechCode) else {
            status = "This helper voice is unavailable on the device. You can still read the words."
            return
        }
        voiceLabel = language.displayName + " device voice"
        status = "Listening in " + language.displayName + "."
        speak(text, voice: voice)
    }

    private func speak(_ text: String, voice: AVSpeechSynthesisVoice) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.78
            utterance.preUtteranceDelay = 0.1
            currentUtteranceID = ObjectIdentifier(utterance)
            isSpeaking = true
            synthesizer.speak(utterance)
        } catch {
            status = "Sound could not start. Please try again."
            currentUtteranceID = nil
            isSpeaking = false
            deactivateSession()
        }
    }

    /// The caller must first check the parent's microphone setting. Keys are explicit:
    /// `practice-<word.id>` for child attempts; `family-<word.id>` for family examples.
    func startRecording(wordId: String) async {
        guard wordId.hasPrefix("practice-") || wordId.hasPrefix("family-") else {
            status = "Choose a family example or a practice recording first."
            return
        }
        guard !isRecording, !isRequestingPermission else { return }
        stopAll()
        let generation = actionGeneration
        isRequestingPermission = true
        let permission: Bool
        switch AVAudioApplication.shared.recordPermission {
        case .granted: permission = true
        case .denied: permission = false
        case .undetermined:
            permission = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in continuation.resume(returning: granted) }
            }
        @unknown default: permission = false
        }
        isRequestingPermission = false
        guard actionGeneration == generation else { return }
        guard permission else {
            status = "Microphone access is off. A parent can enable it in iPhone Settings. All other activities still work."
            return
        }
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
            var folder = recordingsDirectory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let pendingURL = recordingsDirectory.appendingPathComponent("pending-" + UUID().uuidString + ".m4a")
            let newRecorder = try AVAudioRecorder(url: pendingURL, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            newRecorder.delegate = self
            guard newRecorder.prepareToRecord(), newRecorder.record(forDuration: 30) else {
                try? FileManager.default.removeItem(at: pendingURL)
                status = "Recording could not start. Check the microphone and available storage."
                deactivateSession()
                return
            }
            recorder = newRecorder
            recordingKey = wordId
            recordingPendingURL = pendingURL
            recordingStartedAt = Date()
            isRecording = true
            status = wordId.hasPrefix("family-") ? "Recording a family example. Tap stop when finished (30 seconds maximum)." : "Your turn! Recording on this device only (30 seconds maximum)."
            recordingLimit = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.stopRecording()
            }
        } catch {
            status = "Recording could not start. Please check microphone access and free storage."
            cleanupRecording(discard: true)
            deactivateSession()
        }
    }

    func stopRecording() {
        guard recorder != nil else { return }
        recordingLimit?.cancel()
        recordingLimit = nil
        let enoughAudio = recordingStartedAt.map { Date().timeIntervalSince($0) >= 0.3 } ?? false
        recorder?.delegate = nil
        recorder?.stop()
        finishRecording(successfully: enoughAudio)
    }

    func playRecording(wordId: String) {
        stopAll()
        guard let url = recordingURL(wordId: wordId) else {
            status = "There is no recording yet."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            guard audioPlayer.prepareToPlay(), audioPlayer.play() else {
                status = "This recording could not play. You can make a new recording."
                deactivateSession()
                return
            }
            player = audioPlayer
            isPlayingRecording = true
            voiceLabel = wordId.hasPrefix("family-") ? "Family voice · recorded on this device" : "Your practice · recorded on this device"
            status = wordId.hasPrefix("family-") ? "Listening to your family example." : "Listening to your practice. Try it together with your family!"
        } catch {
            status = "This recording could not play. You can make a new recording."
            deactivateSession()
        }
    }

    func hasRecording(wordId: String) -> Bool { recordingURL(wordId: wordId) != nil }

    func recordingURL(wordId: String) -> URL? {
        let url = fileURL(for: wordId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func deleteRecording(wordId: String) -> Bool {
        stopAll()
        guard let url = recordingURL(wordId: wordId) else { return true }
        do {
            try FileManager.default.removeItem(at: url)
            status = "Recording deleted from this device."
            objectWillChange.send()
            return true
        } catch {
            status = "The recording could not be deleted. Please try again."
            return false
        }
    }

    func stopAll() {
        actionGeneration += 1
        if recorder != nil { stopRecording() }
        currentUtteranceID = nil
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        isSpeaking = false
        isPlayingRecording = false
        deactivateSession()
    }

    private func finishRecording(successfully: Bool) {
        guard let pendingURL = recordingPendingURL, let key = recordingKey else {
            cleanupRecording(discard: true)
            deactivateSession()
            return
        }
        if successfully {
            do {
                let data = try Data(contentsOf: pendingURL)
                guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                try data.write(to: fileURL(for: key), options: [.atomic, .completeFileProtectionUnlessOpen])
                status = key.hasPrefix("family-") ? "Family example saved on this device." : "Your practice is saved on this device. No scores—just practise!"
            } catch { status = "This recording could not be saved. Any older recording is still available." }
        } else {
            status = "That recording was too short or was interrupted. Try again when you are ready."
        }
        cleanupRecording(discard: true)
        deactivateSession()
    }

    private func cleanupRecording(discard: Bool) {
        recordingLimit?.cancel()
        recordingLimit = nil
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        if discard, let url = recordingPendingURL { try? FileManager.default.removeItem(at: url) }
        recordingPendingURL = nil
        recordingKey = nil
        recordingStartedAt = nil
        isRecording = false
    }

    private func fileURL(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return recordingsDirectory.appendingPathComponent(hash + ".m4a")
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

extension AudioService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.currentUtteranceID == utteranceID else { return }
            self.currentUtteranceID = nil
            self.isSpeaking = false
            if !self.isRecording && !self.isPlayingRecording { self.deactivateSession() }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.currentUtteranceID == utteranceID else { return }
            self.currentUtteranceID = nil
            self.isSpeaking = false
            if !self.isRecording && !self.isPlayingRecording { self.deactivateSession() }
        }
    }
}

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayerID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == finishedPlayerID else { return }
            self.isPlayingRecording = false
            self.player = nil
            self.deactivateSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let failedPlayerID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == failedPlayerID else { return }
            self.isPlayingRecording = false
            self.player = nil
            self.status = "This recording could not play. You can record it again."
            self.deactivateSession()
        }
    }
}

extension AudioService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let finishedRecorderID = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == finishedRecorderID else { return }
            self.finishRecording(successfully: flag)
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let failedRecorderID = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == failedRecorderID else { return }
            self.finishRecording(successfully: false)
        }
    }
}
