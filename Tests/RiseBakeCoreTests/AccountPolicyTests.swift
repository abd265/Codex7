import XCTest
@testable import RiseBakeCore

final class AccountPolicyTests: XCTestCase {
    func testVerifiedFactorCannotBeBypassedByPasswordOrUnknownAssurance() {
        XCTAssertEqual(AccountPolicy.access(emailConfirmed: true, hasVerifiedFactor: true, assurance: "aal1"), .secondFactor)
        XCTAssertEqual(AccountPolicy.access(emailConfirmed: true, hasVerifiedFactor: true, assurance: nil), .secondFactor)
        XCTAssertEqual(AccountPolicy.access(emailConfirmed: true, hasVerifiedFactor: false, assurance: "unrecognized"), .secondFactor)
        XCTAssertEqual(AccountPolicy.access(emailConfirmed: true, hasVerifiedFactor: true, assurance: "aal2"), .allowed)
        XCTAssertEqual(AccountPolicy.access(emailConfirmed: true, hasVerifiedFactor: false, assurance: "aal1"), .allowed)
        XCTAssertEqual(AccountPolicy.access(emailConfirmed: false, hasVerifiedFactor: true, assurance: "aal2"), .confirmEmail)
    }
    func testWorkspacesSeparateAccountsFromLegacyRecords() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = AccountPolicy.folder(root: root, accountID: UUID())
        let b = AccountPolicy.folder(root: root, accountID: UUID())
        XCTAssertNotEqual(a, b); XCTAssertNotEqual(a, root)
        XCTAssertEqual(AccountPolicy.folder(root: root, accountID: nil), root)
        for (folder, content) in [(root, "legacy"), (a, "baker-a"), (b, "baker-b")] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(content.utf8).write(to: folder.appendingPathComponent("bakery.json"))
        }
        try FileManager.default.removeItem(at: a)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("bakery.json")), "legacy")
        XCTAssertEqual(try String(contentsOf: b.appendingPathComponent("bakery.json")), "baker-b")
    }
    func testNewAccountNeverInheritsCustomerDataOrBranding() throws {
        var seed = try JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: Bundle.module.url(forResource: "catalog", withExtension: "json")!))
        seed.settings.profile = BakeryProfile(email: "private@example.com")
        let clean = AccountPolicy.cleanBakery(from: seed)
        XCTAssertTrue(clean.orders.isEmpty); XCTAssertTrue(clean.customers.isEmpty)
        XCTAssertTrue(clean.recurring.isEmpty); XCTAssertTrue(clean.bakeSessions.isEmpty)
        XCTAssertTrue(clean.tasks.isEmpty); XCTAssertTrue(clean.cart.isEmpty)
        XCTAssertNil(clean.settings.profile); XCTAssertEqual(clean.settings.bakery, "My bakery")
        XCTAssertEqual(clean.products, seed.products); XCTAssertEqual(clean.recipes, seed.recipes)
        try clean.validate()
    }
    func testCredentialsAndCodesRejectMalformedInput() throws {
        XCTAssertTrue(AccountPolicy.validEmail("baker+orders@example.com"))
        for email in ["a@", "a b@example.com", "a@example", "a@example.com\n"] { XCTAssertFalse(AccountPolicy.validEmail(email)) }
        XCTAssertTrue(AccountPolicy.validCode("012345"))
        for code in ["12345", "1234567", "１２３４５６", "123 45", "١٢٣٤٥٦"] { XCTAssertFalse(AccountPolicy.validCode(code)) }
        XCTAssertThrowsError(try AccountPolicy.validateNewPassword("short", confirmation: "short"))
        XCTAssertThrowsError(try AccountPolicy.validateNewPassword("twelve words here", confirmation: "not the same"))
        try AccountPolicy.validateNewPassword("a lovely day to bake", confirmation: "a lovely day to bake")
    }
    func testConfigurationRejectsSecretsAndUnsafeHosts() throws {
        var config = AccountConfiguration(enabled: true, projectURL: "https://example.supabase.co", publishableKey: "sb_publishable_example_public_value", googleEnabled: true, appleEnabled: false, privacyURL: "https://example.com/privacy", termsURL: "https://example.com/terms")
        try config.validate()
        for key in ["sb_secret_never_bundle", "eyJ.service_role.jwt", ""] { var bad = config; bad.publishableKey = key; XCTAssertThrowsError(try bad.validate()) }
        for url in ["http://example.supabase.co", "https://example.supabase.co.evil.com", "https://user:pass@example.supabase.co", "https://example.supabase.co/path", "https://example.supabase.co?x=y"] { var bad = config; bad.projectURL = url; XCTAssertThrowsError(try bad.validate()) }
        config.privacyURL = "javascript:alert(1)"; XCTAssertThrowsError(try config.validate())
    }
}
