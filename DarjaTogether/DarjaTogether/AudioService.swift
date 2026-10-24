import Foundation
import Combine
import AVFoundation
import CryptoKit
import UIKit
import DarjaF5

/// Family recordings and Algerian F5 speech are processed and played on this device.
@MainActor
final class AudioService: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published private(set) var isRecording = false
    @Published private(set) var isPlayingRecording = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var status = "Family voices are best for Darja. Device Arabic speech is an approximation."
    @Published private(set) var voiceLabel = "Device Arabic voice · not authentic Darja"
    @Published private(set) var isGeneratingSpeech = false
    @Published private(set) var synthesisProgress: Double = 0
    @Published private(set) var modelDiagnostic = ""
    private static var voicePreferenceKey: String {
        ProcessInfo.processInfo.arguments.contains("--uitesting") ? "uiTestingUseAlgerianF5Voice" : "useAlgerianF5Voice"
    }
    @Published var useDarjaModel = UserDefaults.standard.object(forKey: AudioService.voicePreferenceKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(useDarjaModel, forKey: Self.voicePreferenceKey)
            stopAll()
            status = useDarjaModel ? "Algerian Darja speech is generated on this device." : "Approximate device Arabic voice selected."
        }
    }

    var nativeModelInstalled: Bool { DarjaVoiceSupport.modelDirectory != nil }
    var arabicSourceLabel: String { useDarjaModel ? "Algerian Darja model · offline" : "Device Arabic voice · not authentic Darja" }
    private let darjaEngine = DarjaF5Engine()
    private var synthesisTask: Task<Void, Never>?
    private var isGeneratedPlayback = false

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
        if arguments.contains("--uitesting") && !arguments.contains("--preserve-progress") { useDarjaModel = true }
        voiceLabel = arabicSourceLabel
        status = "Tap to hear Algerian Darja. The first phrase takes a moment to prepare."
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
            Task { @MainActor [weak self] in
                self?.stopAll()
                if let engine = self?.darjaEngine { await engine.unload() }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.stopAll()
                self.status = "Voice paused to free memory. Tap again when ready."
                await self.darjaEngine.unload()
            }
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
        synthesisTask?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func sourceLabel(for word: DarjaWord) -> String {
        hasRecording(wordId: "family-" + word.id) ? "Family voice · recorded on this device" : arabicSourceLabel
    }

    func speak(_ word: DarjaWord, helperLanguage: HelperLanguage = .english) {
        // Never use a child's practice recording as a pronunciation example.
        let familyKey = "family-" + word.id
        if hasRecording(wordId: familyKey) {
            voiceLabel = "Family voice · recorded on this device"
            playRecording(wordId: familyKey)
        } else {
            // These two curriculum meanings share an unvocalized spelling.
            // Keep their displayed text and use their taught vowels for synthesis.
            let pronunciation: String
            switch word.id {
            case "white": pronunciation = "بْيَضْ"
            case "eggs": pronunciation = "بِيضْ"
            default: pronunciation = word.arabic
            }
            speakArabic(pronunciation)
        }
    }

    func speakArabic(_ text: String) {
        stopAll()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if useDarjaModel {
            speakDarja(DarjaVoiceSupport.spokenText(text))
            return
        }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ar") }
        guard let voice = voices.first(where: { $0.language == "ar-DZ" }) ?? voices.first else {
            status = "No Arabic voice is installed. Use a family recording, or add an Arabic voice in iPhone Accessibility settings."
            return
        }
        voiceLabel = "Device Arabic voice · not authentic Darja"
        status = "This device voice may say Darja differently. Listen to a family voice when you can."
        speak(text, voice: voice)
    }

    private func speakDarja(_ text: String) {
        voiceLabel = arabicSourceLabel
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting") || arguments.contains(where: { $0.hasPrefix("--screenshot-") }) {
            status = "Speech generation is disabled during screen automation; the native voice has a separate synthesis test."
            return
        }
        guard let directory = DarjaVoiceSupport.modelDirectory else {
            status = "The Algerian voice files are missing. Ask a parent to install the complete app build."
            modelDiagnostic = "SpeechModel bundle is incomplete."
            return
        }
        let cached = DarjaVoiceSupport.cachedURL(for: text)
        if FileManager.default.fileExists(atPath: cached.path) {
            playGeneratedAudio(cached)
            return
        }
        let generation = actionGeneration
        isGeneratingSpeech = true
        synthesisProgress = 0
        status = "Preparing your Algerian voice…"
        modelDiagnostic = ""
        synthesisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let reference = try String(contentsOf: directory.appendingPathComponent("reference.txt"), encoding: .utf8)
                let samples = try await self.darjaEngine.generate(
                    text: text, modelDirectory: directory,
                    referenceAudioURL: directory.appendingPathComponent("reference.wav"),
                    referenceText: reference,
                    progress: { [weak self] progress in
                        Task { @MainActor [weak self] in
                            guard let self, self.actionGeneration == generation else { return }
                            self.synthesisProgress = progress
                            self.status = "Preparing your Algerian voice… \(Int(progress * 100))%"
                        }
                    })
                try Task.checkCancellation()
                guard self.actionGeneration == generation else { return }
                let url = try DarjaVoiceSupport.save(samples: samples, for: text)
                self.isGeneratingSpeech = false
                self.synthesisTask = nil
                self.playGeneratedAudio(url)
            } catch {
                guard self.actionGeneration == generation else { return }
                self.isGeneratingSpeech = false
                self.synthesisTask = nil
                if error is CancellationError { return }
                self.modelDiagnostic = error.localizedDescription
                self.status = "The Algerian voice could not start. Try again, or ask a parent to check Voice settings."
            }
        }
    }

    private func playGeneratedAudio(_ url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            guard audioPlayer.prepareToPlay(), audioPlayer.play() else { throw CocoaError(.fileReadCorruptFile) }
            player = audioPlayer
            isGeneratedPlayback = true
            isSpeaking = true
            voiceLabel = arabicSourceLabel
            status = "Listening to the Algerian model voice. Your family can help check pronunciation."
        } catch {
            isGeneratedPlayback = false
            isSpeaking = false
            status = "This generated phrase could not play. Try clearing the voice cache in Parent space."
            deactivateSession()
        }
    }

    func clearGeneratedVoiceCache() {
        stopAll()
        do { try DarjaVoiceSupport.clearCache(); status = "Generated speech cache cleared. Family recordings are kept." }
        catch { status = "The speech cache could not be cleared. Please try again." }
    }

    func stopListening() {
        stopAll()
        status = "Voice stopped. Tap a sound when you are ready."
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
        synthesisTask?.cancel()
        synthesisTask = nil
        isGeneratingSpeech = false
        synthesisProgress = 0
        isGeneratedPlayback = false
        if recorder != nil {
            // Leaving a screen or being interrupted must not replace a good
            // family example with an unfinished take. The explicit Stop button saves.
            recorder?.delegate = nil
            recorder?.stop()
            finishRecording(successfully: false)
        }
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
            self.isSpeaking = false
            self.isGeneratedPlayback = false
            self.player = nil
            self.deactivateSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let failedPlayerID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == failedPlayerID else { return }
            self.isPlayingRecording = false
            self.isSpeaking = false
            self.isGeneratedPlayback = false
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
