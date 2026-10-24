import Foundation
import CryptoKit

/// Disk cache for audio produced entirely on this device. No recording or text is uploaded.
enum DarjaVoiceSupport {
    static let cacheVersion = "f5-darja-0589d128-fp16-v1"
    static let maximumCacheBytes = 256 * 1024 * 1024

    static var modelDirectory: URL? {
        guard let root = Bundle.main.resourceURL else { return nil }
        let directory = root.appendingPathComponent("SpeechModel", isDirectory: true)
        let required = ["model.safetensors", "vocos.safetensors", "vocab.json", "mel_filters.npy", "config.json", "reference.wav", "reference.txt"]
        return required.allSatisfy { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) } ? directory : nil
    }

    static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DarjaTogether-Speech", isDirectory: true)
    }

    static func spokenText(_ text: String) -> String {
        // Story speaker labels are shown on the page but should not be read aloud.
        if let colon = text.firstIndex(of: ":"), text.distance(from: text.startIndex, to: colon) <= 24 {
            return String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cachedURL(for text: String) -> URL {
        let hash = SHA256.hash(data: Data((cacheVersion + "\n" + text).utf8))
            .map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(hash + ".wav")
    }

    static func save(samples: [Float], for text: String) throws -> URL {
        guard !samples.isEmpty, samples.count <= 24_000 * 40, samples.allSatisfy(\.isFinite) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        let destination = cachedURL(for: text)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        var data = Data()
        func word(_ value: UInt16) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        func dword(_ value: UInt32) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: "RIFF".utf8); dword(36 + byteCount); data.append(contentsOf: "WAVEfmt ".utf8)
        dword(16); word(1); word(1); dword(24_000); dword(48_000); word(2); word(16)
        data.append(contentsOf: "data".utf8); dword(byteCount)
        for value in samples {
            let pcm = Int16((min(1, max(-1, value)) * 32767).rounded())
            word(UInt16(bitPattern: pcm))
        }
        try data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])
        trimCache(keeping: destination)
        return destination
    }

    static func clearCache() throws {
        // Only generated WAVs in our explicitly owned cache directory are removed.
        guard FileManager.default.fileExists(atPath: cacheDirectory.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) where url.pathExtension == "wav" {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func trimCache(keeping: URL) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: Array(keys))) ?? []
        let entries = files.filter { $0.pathExtension == "wav" }.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var size = entries.reduce(0) { $0 + $1.1 }
        for entry in entries where size > maximumCacheBytes && entry.0 != keeping {
            if (try? FileManager.default.removeItem(at: entry.0)) != nil { size -= entry.1 }
        }
    }
}
