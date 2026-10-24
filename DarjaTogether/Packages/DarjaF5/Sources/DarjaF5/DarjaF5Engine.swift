import Foundation
import MLX
import MLXNN
import MLXRandom

public enum DarjaF5Error: LocalizedError {
    case invalidBundle(String), invalidText(String), invalidAudio(String), unavailable(String)
    public var errorDescription: String? {
        switch self {
        case .invalidBundle(let value), .invalidText(let value), .invalidAudio(let value), .unavailable(let value): return value
        }
    }
}

public struct DarjaF5Options: Sendable {
    public var steps: Int
    public var guidance: Float
    public var speed: Float
    public var seed: UInt64
    public var maximumGeneratedSeconds: Double
    public init(steps: Int = 32, guidance: Float = 2, speed: Float = 1, seed: UInt64 = 42, maximumGeneratedSeconds: Double = 12) {
        self.steps = steps; self.guidance = guidance; self.speed = speed
        self.seed = seed; self.maximumGeneratedSeconds = maximumGeneratedSeconds
    }
}

private struct DarjaBundleConfig: Decodable {
    let formatVersion: Int
    let modelID: String
    let sampleRate: Int
    let dim: Int
    let depth: Int
    let heads: Int
    let dimHead: Int
    let ffMult: Int
    let textDim: Int
    let convLayers: Int
    let vocabSize: Int
    let textMaskPadding: Bool
    let peAttentionHeads: Int
    func validate() throws {
        guard formatVersion == 1, modelID == "touati-kamel/f5tts-algerian-darja",
              sampleRate == 24_000, dim == 1024, depth == 22, heads == 18, dimHead == 64,
              ffMult == 2, textDim == 512, convLayers == 8, vocabSize == 2580,
              !textMaskPadding, peAttentionHeads == 1 else {
            throw DarjaF5Error.invalidBundle("This is not the supported Algerian Darja F5 model bundle.")
        }
    }
}

private final class DarjaNetwork: Module {
    let transformer: DiT
    override init() {
        transformer = DiT(dim: 1024, depth: 22, heads: 18, dimHead: 64,
                          dropout: 0, ffMult: 2, melDim: 100, textNumEmbeds: 2580, textDim: 512, convLayers: 8)
        super.init()
    }
}

private final class LoadedDarjaModel {
    let directory: URL
    let network: DarjaNetwork
    let vocoder: DarjaVocos
    let mel: MelSpec
    let vocabulary: [String: Int32]
    let dtype: DType
    init(directory: URL, forceFloat32: Bool = false) throws {
        self.directory = directory
        let config = try JSONDecoder().decode(DarjaBundleConfig.self, from: Data(contentsOf: directory.appendingPathComponent("config.json")))
        try config.validate()
        // Exported with the original Python tokenizer's exact line slicing semantics.
        // Its source file has a blank line and no final newline, leaving sparse IDs.
        let vocabularyData = try Data(contentsOf: directory.appendingPathComponent("vocab.json"))
        let exportedVocabulary = try JSONDecoder().decode([String: Int32].self, from: vocabularyData)
        guard exportedVocabulary.count == config.vocabSize, exportedVocabulary[" "] == 0,
              exportedVocabulary[""] == 2580,
              exportedVocabulary.values.allSatisfy({ $0 >= 0 && $0 <= 2580 }) else {
            throw DarjaF5Error.invalidBundle("The exported Arabic vocabulary is incompatible with this checkpoint.")
        }
        vocabulary = exportedVocabulary
        let filterbank = try MLX.loadArray(url: directory.appendingPathComponent("mel_filters.npy")).asType(.float32)
        guard filterbank.shape == [100, 513] else { throw DarjaF5Error.invalidBundle("The 24 kHz Vocos mel filterbank is invalid.") }
        mel = MelSpec(filterbank: filterbank)
        network = DarjaNetwork()
        let weights = try MLX.loadArrays(url: directory.appendingPathComponent("model.safetensors"))
        guard let embedding = weights["transformer.text_embed.text_embed.weight"], embedding.shape == [2581, 512],
              let query = weights["transformer.transformer_blocks.0.attn.to_q.weight"], query.shape == [1152, 1024] else {
            throw DarjaF5Error.invalidBundle("The Darja checkpoint has incompatible vocabulary or attention dimensions.")
        }
        guard embedding.dtype == .float16 || embedding.dtype == .float32 else { throw DarjaF5Error.invalidBundle("The Darja model must contain FP16 or FP32 inference weights.") }
        // Hosted macOS runners can validate with CPU inference even without Metal.
        let executionDType: DType = forceFloat32 || Device.defaultDevice().deviceType == .cpu ? .float32 : embedding.dtype
        dtype = executionDType
        try Self.update(network, with: weights.mapValues { $0.asType(executionDType) }, component: "Darja DiT")
        network.train(false)
        MLX.eval(network.parameters())
        vocoder = DarjaVocos()
        let vocoderWeights = try MLX.loadArrays(url: directory.appendingPathComponent("vocos.safetensors"))
        try Self.update(vocoder, with: vocoderWeights.mapValues { $0.asType(.float32) }, component: "Vocos")
        vocoder.train(false)
        MLX.eval(vocoder.parameters())
        MLX.eval(filterbank)
    }
    private static func update(_ module: Module, with weights: [String: MLXArray], component: String) throws {
        var parameters = Dictionary(uniqueKeysWithValues: module.parameters().flattened())
        for (name, weight) in weights {
            guard let expected = parameters[name], expected.shape == weight.shape else {
                throw DarjaF5Error.invalidBundle("\(component) has an unknown or incorrectly shaped tensor: \(name).")
            }
        }
        let missing = parameters.keys.filter { name in
            let leaf = name.split(separator: ".").last.map(String.init) ?? ""
            return ["weight", "bias", "gamma", "beta"].contains(leaf) && weights[name] == nil
        }
        guard missing.isEmpty else {
            throw DarjaF5Error.invalidBundle("\(component) is missing learned weights: \(missing.sorted().prefix(3).joined(separator: ", ")).")
        }
        for (name, weight) in weights { parameters[name] = weight }
        try module.update(parameters: ModuleParameters.unflattened(parameters), verify: [.all])
    }
}

public struct DarjaParityMetric: Codable, Sendable {
    public let component: String
    public let shape: [Int]
    public let maximumAbsoluteError: Double
    public let rootMeanSquaredError: Double
    public let passed: Bool
}

/// Local converted Algerian F5 only. No downloads, substitute voices, or remote speech requests.
public actor DarjaF5Engine {
    public static let sampleRate = 24_000
    private var loaded: LoadedDarjaModel?
    public init() {}
    public func unload() {
        loaded = nil
        if Device.defaultDevice().deviceType == .gpu { GPU.clearCache() }
    }

    /// Compare native operations against independently generated upstream PyTorch fixtures.
    /// This checks implementation parity, not pronunciation quality or suitability of a voice.
    public func checkParity(modelDirectory: URL, fixtureDirectory: URL) async throws -> [DarjaParityMetric] {
        try Task.checkCancellation()
        let model = try LoadedDarjaModel(directory: modelDirectory, forceFloat32: true)
        func load(_ name: String) throws -> MLXArray {
            try MLX.loadArray(url: fixtureDirectory.appendingPathComponent(name + ".npy"))
        }
        let state = try load("x").asType(.float32)
        let conditioning = try load("conditioning").asType(.float32)
        let tokens = try load("text").asType(.int32)
        let time = try load("time").asType(.float32)
        let audio = try load("reference_samples").asType(.float32)
        guard state.shape == [1, 32, 100], conditioning.shape == state.shape,
              tokens.ndim == 2, tokens.shape[0] == 1, tokens.shape[1] <= 800,
              time.shape == [1], audio.ndim == 1, (48_000...288_000).contains(audio.shape[0]) else {
            throw DarjaF5Error.invalidBundle("The numerical parity fixtures have unexpected dimensions.")
        }
        let predicted = model.network.transformer(x: state, cond: conditioning, text: tokens, time: time, dropAudioCond: false, dropText: false)
        let mel = model.mel(x: audio)
        MLX.eval(predicted, mel)
        var metrics = [
            try Self.compare("DiT forward", actual: predicted, expected: load("expected_forward"), absoluteTolerance: 0.02, rmsTolerance: 0.002),
            try Self.compare("Reference mel", actual: mel, expected: load("expected_mel"), absoluteTolerance: 0.002, rmsTolerance: 0.0003)
        ]
        try Task.checkCancellation()
        if FileManager.default.fileExists(atPath: fixtureDirectory.appendingPathComponent("vocos_mel.npy").path) {
            let features = try load("vocos_mel").asType(.float32)
            guard features.ndim == 3, features.shape[0] == 1, features.shape[2] == 100, (2...1200).contains(features.shape[1]) else {
                throw DarjaF5Error.invalidBundle("The Vocos parity fixture has unexpected dimensions.")
            }
            let audio = try model.vocoder.decode(features)
            metrics.append(try Self.compare("Vocos waveform", actual: MLXArray(audio), expected: load("expected_vocos"), absoluteTolerance: 0.002, rmsTolerance: 0.0002))
        }
        return metrics
    }

    private nonisolated static func compare(_ component: String, actual: MLXArray, expected: MLXArray, absoluteTolerance: Double, rmsTolerance: Double) throws -> DarjaParityMetric {
        guard actual.shape == expected.shape else {
            throw DarjaF5Error.invalidAudio("\(component) shape differs from the upstream fixture: \(actual.shape) versus \(expected.shape).")
        }
        let actualValues = actual.asType(.float32).asArray(Float.self)
        let expectedValues = expected.asType(.float32).asArray(Float.self)
        guard !actualValues.isEmpty, actualValues.allSatisfy(\.isFinite), expectedValues.allSatisfy(\.isFinite) else {
            throw DarjaF5Error.invalidAudio("\(component) contains non-finite values.")
        }
        var maximum = 0.0, squaredSum = 0.0
        for (actual, expected) in zip(actualValues, expectedValues) {
            let error = abs(Double(actual) - Double(expected))
            maximum = max(maximum, error); squaredSum += error * error
        }
        let rms = sqrt(squaredSum / Double(actualValues.count))
        return DarjaParityMetric(component: component, shape: actual.shape, maximumAbsoluteError: maximum,
                                 rootMeanSquaredError: rms, passed: maximum <= absoluteTolerance && rms <= rmsTolerance)
    }

    public func generate(
        text: String, modelDirectory: URL, referenceAudioURL: URL, referenceText: String,
        options: DarjaF5Options = DarjaF5Options(), progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [Float] {
        #if !arch(arm64)
        throw DarjaF5Error.unavailable("Native Darja generation requires an Apple Silicon device.")
        #else
        try Task.checkCancellation()
        let target = Self.normalize(text)
        let reference = Self.normalize(referenceText)
        guard !target.isEmpty, target.unicodeScalars.count <= 240, !reference.isEmpty, reference.unicodeScalars.count <= 800 else {
            throw DarjaF5Error.invalidText("Use a short phrase of up to 240 characters and a reference transcript.")
        }
        guard (4...64).contains(options.steps), options.guidance.isFinite, (0...5).contains(options.guidance),
              options.speed.isFinite, (0.6...1.6).contains(options.speed),
              options.maximumGeneratedSeconds.isFinite, (1...20).contains(options.maximumGeneratedSeconds) else {
            throw DarjaF5Error.invalidText("The speech generation settings are outside the supported limits.")
        }
        let previousCacheLimit = Device.defaultDevice().deviceType == .gpu ? GPU.cacheLimit : nil
        if previousCacheLimit != nil { GPU.set(cacheLimit: 64 * 1024 * 1024) }
        defer {
            if let previousCacheLimit { GPU.clearCache(); GPU.set(cacheLimit: previousCacheLimit) }
        }
        progress?(0)
        let model: LoadedDarjaModel
        if let previous = loaded, previous.directory.standardizedFileURL == modelDirectory.standardizedFileURL {
            model = previous
        } else {
            loaded = nil
            if previousCacheLimit != nil { GPU.clearCache() }
            model = try LoadedDarjaModel(directory: modelDirectory)
            loaded = model
        }
        try Task.checkCancellation()
        progress?(0.08)
        // Swift Character groups Arabic combining marks; Python F5 indexes Unicode scalars.
        let symbols = (reference + " " + target).unicodeScalars.map { String($0) }
        let unknown = Set(symbols.filter { model.vocabulary[$0] == nil })
        guard unknown.isEmpty else {
            throw DarjaF5Error.invalidText("The Arabic model does not know these characters: \(unknown.sorted().joined()).")
        }
        let ids = symbols.map { model.vocabulary[$0]! }
        let tokenArray = MLXArray(ids).expandedDimensions(axis: 0)
        var referenceSamples = try DarjaAudioFile.loadReference(url: referenceAudioURL)
        let rms = sqrt(referenceSamples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(referenceSamples.count))
        guard rms > 0.0001 else { throw DarjaF5Error.invalidAudio("The reference recording is silent.") }
        let gain = rms < 0.1 ? 0.1 / rms : 1
        if gain != 1 { referenceSamples = referenceSamples.map { $0 * Float(gain) } }
        let referenceMel = model.mel(x: MLXArray(referenceSamples)).asType(model.dtype)
        MLX.eval(referenceMel)
        let referenceFrames = referenceMel.shape[1]
        // Reference text is fully vocalized, while lesson words often omit marks.
        // Count base letters consistently; keep isolated teaching words near one second.
        let referenceUnits = max(1, Self.durationUnits(reference))
        let targetUnits = max(1, Self.durationUnits(target))
        let estimatedFrames = Double(referenceFrames) * Double(targetUnits) / Double(referenceUnits) / Double(options.speed)
        let generatedFrames = max(95, Int(estimatedFrames.rounded(.up)))
        guard Double(generatedFrames * 256) / 24_000 <= options.maximumGeneratedSeconds else {
            throw DarjaF5Error.invalidText("This phrase would be too long. Split it into shorter sentences.")
        }
        let frameCount = max(referenceFrames + generatedFrames, ids.count + 1)
        guard frameCount <= 3000 else { throw DarjaF5Error.invalidText("This phrase exceeds the on-device memory limit.") }
        let conditioning = MLX.padded(referenceMel, widths: [.init((0, 0)), .init((0, frameCount - referenceFrames)), .init((0, 0))])
        MLXRandom.seed(options.seed)
        var state = MLXRandom.normal([1, frameCount, 100]).asType(model.dtype)
        MLX.eval(state, conditioning)
        let timePoints: [Float] = (0...options.steps).map { step in
            let linear = Float(step) / Float(options.steps)
            return linear - (cos(Float.pi * 0.5 * linear) - 1 + linear)
        }
        for step in 0..<options.steps {
            try Task.checkCancellation()
            let time = MLXArray(timePoints[step]).asType(model.dtype)
            let conditioned = model.network.transformer(x: state, cond: conditioning, text: tokenArray, time: time, dropAudioCond: false, dropText: false)
            var velocity = conditioned
            if options.guidance > 0 {
                let unconditioned = model.network.transformer(x: state, cond: conditioning, text: tokenArray, time: time, dropAudioCond: true, dropText: true)
                velocity = conditioned + (conditioned - unconditioned) * options.guidance
            }
            state = (state + velocity * (timePoints[step + 1] - timePoints[step])).asType(model.dtype)
            // Bound live intermediates: evaluate and discard each ODE step, not an entire trajectory.
            MLX.eval(state)
            progress?(0.12 + 0.76 * Double(step + 1) / Double(options.steps))
        }
        try Task.checkCancellation()
        let targetMel = state[0..., referenceFrames..<frameCount, 0...].asType(.float32)
        var samples = try model.vocoder.decode(targetMel)
        try Task.checkCancellation()
        if gain != 1 { samples = samples.map { $0 / Float(gain) } }
        guard samples.count >= 2400, samples.allSatisfy(\.isFinite) else {
            throw DarjaF5Error.invalidAudio("The Darja model produced invalid audio. No substitute voice was used.")
        }
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 1e-5 else { throw DarjaF5Error.invalidAudio("The Darja model produced silence.") }
        if peak > 0.98 { samples = samples.map { $0 * (0.98 / peak) } }
        progress?(1)
        return samples
        #endif
    }

    public nonisolated static func normalize(_ value: String) -> String {
        var text = value
        let substitutions: [(String, String)] = [
            (#"\[\s*(?:French|FR)\s*:\s*(.*?)\]"#, "$1"),
            (#"\[.*?\]|<.*?>|\(.*?\)"#, ""),
            (#"[*#@~_\^&%$+=/\\|{}\[\]\"«»]"#, "")
        ]
        for (pattern, replacement) in substitutions {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
            }
        }
        for (source, replacement) in [("ـ", ""), ("إ", "ا"), ("أ", "ا"), ("آ", "ا"), ("ى", "ي"), ("پ", "ب"), ("\u{0060}", "")] {
            text = text.replacingOccurrences(of: source, with: replacement)
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private nonisolated static func durationUnits(_ value: String) -> Int {
        value.unicodeScalars.filter { scalar in
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark: return false
            default: return CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
            }
        }.count
    }
}
