import DarjaF5
import Foundation
import MLX
import Darwin

@main
struct DarjaF5Smoke {
    static func main() async {
        do {
            let arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
            if arguments.help {
                print("DarjaF5Smoke --model-dir DIR --reference-wav FILE --reference-text TEXT --text TEXT --output FILE [--steps 32] [--cpu]\nDarjaF5Smoke --model-dir DIR --parity-dir DIR [--cpu]")
                return
            }
            if arguments.cpu { Device.setDefault(device: .cpu) }
            let directory = URL(fileURLWithPath: try arguments.required("--model-dir"), isDirectory: true)
            if let fixtures = arguments.values["--parity-dir"] {
                let engine = DarjaF5Engine()
                let metrics = try await engine.checkParity(modelDirectory: directory, fixtureDirectory: URL(fileURLWithPath: fixtures, isDirectory: true))
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(metrics), as: UTF8.self))
                await engine.unload()
                guard metrics.allSatisfy(\.passed) else { throw CLIError("Native inference differs from the upstream PyTorch fixtures.") }
                return
            }
            let reference = URL(fileURLWithPath: try arguments.required("--reference-wav"))
            let output = URL(fileURLWithPath: try arguments.required("--output"))
            let referenceText = try arguments.required("--reference-text")
            let text = try arguments.required("--text")
            let stepsString = arguments.values["--steps"] ?? "32"
            guard let steps = Int(stepsString) else { throw CLIError("The --steps argument must be an integer.") }
            let engine = DarjaF5Engine()
            let started = Date()
            print("Loading local Algerian Darja model; device=\(arguments.cpu ? "CPU" : "GPU"), steps=\(steps)")
            let samples = try await engine.generate(
                text: text, modelDirectory: directory, referenceAudioURL: reference,
                referenceText: referenceText, options: DarjaF5Options(steps: steps)
            ) { fraction in
                print(String(format: "Generation %.0f%%", fraction * 100))
            }
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try DarjaAudioFile.saveWAV(samples: samples, to: output)
            await engine.unload()
            print(String(format: "Saved PCM16 mono 24000 Hz: %.3f seconds of audio in %.3f seconds.", Double(samples.count) / 24_000, Date().timeIntervalSince(started)))
            print(output.path)
        } catch {
            let message = "DarjaF5Smoke failed: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }
}

private struct CLIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private struct Arguments {
    var values: [String: String] = [:]
    var cpu = false
    var help = false
    init(_ arguments: [String]) throws {
        let valueFlags: Set<String> = ["--model-dir", "--reference-wav", "--reference-text", "--text", "--output", "--steps", "--parity-dir"]
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            if flag == "--help" || flag == "-h" { help = true; index += 1; continue }
            if flag == "--cpu" { cpu = true; index += 1; continue }
            guard valueFlags.contains(flag), index + 1 < arguments.count, values[flag] == nil else {
                throw CLIError("Unknown, repeated, or incomplete argument: \(flag)")
            }
            values[flag] = arguments[index + 1]
            index += 2
        }
    }
    func required(_ flag: String) throws -> String {
        guard let value = values[flag], !value.isEmpty else { throw CLIError("Missing \(flag).") }
        return value
    }
}
