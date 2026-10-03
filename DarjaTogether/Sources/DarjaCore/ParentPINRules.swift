import Foundation

#if canImport(CryptoKit)
import CryptoKit

/// A local child-access gate, not a replacement for the device passcode.
enum ParentPINRules {
    static func makeCredential(pin: String, salt: String = UUID().uuidString) -> ParentCredential? {
        guard pin.count == 4, pin.unicodeScalars.allSatisfy({ (48...57).contains(Int($0.value)) }) else { return nil }
        return ParentCredential(salt: salt, digest: digest(pin: pin, salt: salt))
    }

    static func verify(pin: String, credential: ParentCredential, at now: Date) -> (accepted: Bool, credential: ParentCredential) {
        var next = credential
        if let until = next.lockedUntil {
            if until > now { return (false, next) }
            next.lockedUntil = nil
            next.failedAttempts = 0
        }
        if digest(pin: pin, salt: next.salt) == next.digest {
            next.failedAttempts = 0
            next.lockedUntil = nil
            return (true, next)
        }
        next.failedAttempts += 1
        if next.failedAttempts >= 5 {
            next.lockedUntil = now.addingTimeInterval(60)
            next.failedAttempts = 0
        }
        return (false, next)
    }

    private static func digest(pin: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + ":" + pin).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
