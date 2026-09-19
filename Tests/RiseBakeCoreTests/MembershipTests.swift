import XCTest
@testable import RiseBakeCore

final class MembershipTests: XCTestCase {
    func testExpiredRevokedAndReplacedSubscriptionsNeverGrantAccess() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let future = now.addingTimeInterval(100)
        XCTAssertTrue(MembershipEntitlement(plan: .monthly, expiration: future, revoked: false, upgraded: false).isActive(at: now))
        for expiry in [now.addingTimeInterval(-1), now, nil] {
            XCTAssertFalse(MembershipEntitlement(plan: .annual, expiration: expiry, revoked: false, upgraded: false).isActive(at: now))
        }
        XCTAssertFalse(MembershipEntitlement(plan: .monthly, expiration: future, revoked: true, upgraded: false).isActive(at: now))
        XCTAssertFalse(MembershipEntitlement(plan: .monthly, expiration: future, revoked: false, upgraded: true).isActive(at: now))
    }
    func testOneTimePurchaseRequiresPermanentUnrevokedEntitlement() {
        let now = Date()
        XCTAssertTrue(MembershipEntitlement(plan: .offline, expiration: nil, revoked: false, upgraded: false).isActive(at: now))
        XCTAssertFalse(MembershipEntitlement(plan: .offline, expiration: nil, revoked: true, upgraded: false).isActive(at: now))
        XCTAssertFalse(MembershipEntitlement(plan: .offline, expiration: now.addingTimeInterval(500), revoked: false, upgraded: false).isActive(at: now))
    }
    func testLiveCommerceRejectsAmbiguousProductsAndMissingLegalPages() throws {
        let config = MembershipConfiguration(enabled: true, monthlyProductID: "monthly", annualProductID: "annual", offlineProductID: "offline", privacyURL: "https://bakery.example/privacy", termsURL: "https://bakery.example/terms")
        try config.validate()
        XCTAssertNil(config.plan(for: "someone.elses.product"))
        XCTAssertEqual(config.plan(for: "annual"), .annual)
        var duplicate = config; duplicate.offlineProductID = config.monthlyProductID
        XCTAssertThrowsError(try duplicate.validate())
        for value in ["", "http://bakery.example/terms", "https://user:password@bakery.example/terms", "javascript:alert(1)"] {
            var bad = config; bad.termsURL = value
            XCTAssertThrowsError(try bad.validate())
        }
    }
}
