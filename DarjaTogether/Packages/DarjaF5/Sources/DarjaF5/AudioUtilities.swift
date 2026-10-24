// Adapted from lucasnewman/vocos-swift (MIT). See THIRD_PARTY_NOTICES.txt.
import AVFoundation
import Foundation

public enum DarjaAudioFile {
    public static func loadReference(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let duration = Double(file.length) / format.sampleRate
        guard duration >= 2, duration <= 12, format.sampleRate > 0,
              let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: format, to: target),
              let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(ceil(duration * 24_000) + 1024)) else {
            throw DarjaF5Error.invalidAudio("Use a clear reference recording between 2 and 12 seconds.")
        }
        try file.read(into: input)
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .endOfStream; return nil }
            supplied = true; state.pointee = .haveData; return input
        }
        guard status != .error, error == nil, output.frameLength >= 48_000, let data = output.floatChannelData?[0] else {
            throw DarjaF5Error.invalidAudio("The reference audio could not be decoded.")
        }
        let samples = Array(UnsafeBufferPointer(start: data, count: Int(output.frameLength)))
        guard samples.allSatisfy(\.isFinite) else { throw DarjaF5Error.invalidAudio("The reference contains invalid samples.") }
        return samples
    }

    public static func saveWAV(samples: [Float], to url: URL) throws {
        guard !samples.isEmpty, samples.allSatisfy(\.isFinite), samples.count < Int(UInt32.max / 2) - 22 else {
            throw DarjaF5Error.invalidAudio("No valid generated audio was available to save.")
        }
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8); append(UInt32(36 + samples.count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(24_000)); append(UInt32(48_000)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8); append(UInt32(samples.count * 2))
        for sample in samples { append(Int16((max(-1, min(1, sample)) * 32767).rounded())) }
        try data.write(to: url, options: .atomic)
    }
}
