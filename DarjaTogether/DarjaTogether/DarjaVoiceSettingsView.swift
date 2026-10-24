import SwiftUI

struct DarjaVoiceSettingsView: View {
    @EnvironmentObject private var audio: AudioService

    var body: some View {
        Form {
            Section("Algerian pronunciation") {
                Toggle("Use the offline Algerian voice", isOn: $audio.useDarjaModel)
                    .accessibilityIdentifier("useOfflineDarjaVoice")
                LabeledContent("Voice files", value: audio.nativeModelInstalled ? "Installed" : "Missing")
                Text("This voice uses an Algerian-trained speech model on your device. It covers words, stories and conversation prompts. Family word recordings always take priority.")
                    .font(.footnote)
                Text("The first phrase can take a while. Played phrases are saved locally for faster listening next time. Stop playback before leaving the app.")
                    .font(.caption).foregroundStyle(DarjaTheme.muted)
                Button("Try the Algerian voice") { audio.speakArabic("سلام، واش راكي؟ اليوم نتعلمو الدارجة مع بعضانا.") }
                    .disabled(!audio.useDarjaModel || !audio.nativeModelInstalled)
                SpeechActivityBanner()
                Text(audio.status).font(.caption).foregroundStyle(DarjaTheme.muted)
            }
            Section("Voice and pronunciation") {
                Text("The voice is AI-generated. Listen together and use a family recording if a word sounds wrong. The supplied example voice comes from the Arabic model author; it is not a recording of your child or a family member.")
                    .font(.footnote)
                Text("Turning the Algerian voice off explicitly selects the device’s approximate Arabic speech. The app does not switch to that voice when model generation fails.")
                    .font(.footnote)
            }
            Section("On this device") {
                Button("Clear generated speech cache") { audio.clearGeneratedVoiceCache() }
                Text("Only generated phrases are removed. Family recordings and learning progress are kept. No audio or lesson text is uploaded.")
                    .font(.caption).foregroundStyle(DarjaTheme.muted)
            }
            Section("Model credits") {
                Text("Algerian F5-TTS by Kamel Touati, based on Arabic F5-TTS by Ibrahim Salah, with Vocos audio decoding. Converted inference weights are included in this app.")
                    .font(.footnote)
                Text("Provided for personal, educational, noncommercial use. Upstream model notices are included in the source package.")
                    .font(.caption).foregroundStyle(DarjaTheme.muted)
                if !audio.modelDiagnostic.isEmpty {
                    Text(audio.modelDiagnostic).font(.caption).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Algerian voice")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { audio.stopAll() }
    }
}

struct SpeechActivityBanner: View {
    @EnvironmentObject private var audio: AudioService

    var body: some View {
        if audio.isGeneratingSpeech {
            VStack(spacing: 8) {
                ProgressView(value: audio.synthesisProgress)
                HStack {
                    Text("Preparing your Algerian voice…").font(.caption)
                    Spacer()
                    Button("Stop") { audio.stopListening() }
                }
            }
            .tint(DarjaTheme.teal)
            .accessibilityIdentifier("speechGeneration")
        } else if audio.isSpeaking || audio.isPlayingRecording {
            Button { audio.stopListening() } label: { Label("Stop listening", systemImage: "stop.circle") }
        }
    }
}
