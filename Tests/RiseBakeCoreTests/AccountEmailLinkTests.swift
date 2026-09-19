import XCTest
@testable import RiseBakeCore

final class AccountEmailLinkTests: XCTestCase {
    func testOnlyExactNativePKCECallbackIsAccepted() {
        let code = "b2233402-cc22-4c4c-8058-abc123"
        XCTAssertEqual(AccountEmailLink.authorizationCode(from: URL(string: "riseandbake://auth/callback?code=\(code)")!), code)
        for url in [
            "https://auth/callback?code=abc", "riseandbake://evil/callback?code=abc",
            "riseandbake://auth/callback/extra?code=abc", "riseandbake://auth:123/callback?code=abc",
            "riseandbake://user@auth/callback?code=abc", "riseandbake://auth/callback?code=",
            "riseandbake://auth/callback?code=abc&code=def", "riseandbake://auth/callback?code=abc&type=recovery",
            "riseandbake://auth/callback#access_token=secret&refresh_token=secret",
            "riseandbake://auth/callback?code=abc#access_token=secret",
            "riseandbake://auth/callback?error=expired&error_description=untrusted",
            "riseandbake://auth/callback?code=abc%0A", "riseandbake://auth/callback?code=abc%20def",
            "riseandbake://auth/callback?code=" + String(repeating: "a", count: 513)
        ] { XCTAssertNil(AccountEmailLink.authorizationCode(from: URL(string: url)!), url) }
    }
    func testPendingPurposeSurvivesRelaunchButExpiresAndRejectsFutureState() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let pending = PendingAccountEmail(email: "baker@example.com", purpose: .recovery, requestedAt: now)
        let restored = try JSONDecoder().decode(PendingAccountEmail.self, from: JSONEncoder().encode(pending))
        XCTAssertEqual(restored, pending)
        XCTAssertTrue(restored.isCurrent(at: now.addingTimeInterval(600)))
        XCTAssertFalse(restored.isCurrent(at: now.addingTimeInterval(3601)))
        XCTAssertFalse(restored.isCurrent(at: now.addingTimeInterval(-31)))
        XCTAssertFalse(PendingAccountEmail(email: "invalid", purpose: .signup, requestedAt: now).isCurrent(at: now))
    }
    func testOlderConfigurationKeepsCodeDeliveryAndNewConfigurationStillRequiresPublicURLs() throws {
        let old = Data(#"{"enabled":false,"projectURL":"","publishableKey":"","googleEnabled":false,"appleEnabled":false,"privacyURL":"","termsURL":""}"#.utf8)
        var config = try JSONDecoder().decode(AccountConfiguration.self, from: old)
        XCTAssertNil(config.emailLinkDelivery); XCTAssertNil(config.privateTesting)
        config.enabled = true; config.privateTesting = true; config.emailLinkDelivery = true
        config.projectURL = "https://example.supabase.co"; config.publishableKey = "sb_publishable_example_public_value"
        XCTAssertThrowsError(try config.validate(), "Private testing must retain URL/key/disclosure validation")
    }
}
