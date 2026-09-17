import XCTest
@testable import RiseBakeCore

final class RiseBakeCoreTests: XCTestCase {
    func seed() throws -> BakeryState {
        try JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: Bundle.module.url(forResource: "seed", withExtension: "json")!))
    }
    func testLatestSeedAndRoundTrip() throws {
        let s = try seed(); try s.validate()
        XCTAssertEqual(s.orders.count, 35); XCTAssertEqual(s.products.count, 6); XCTAssertEqual(s.recurring.count, 4)
        XCTAssertEqual(s, try JSONDecoder().decode(BakeryState.self, from: JSONEncoder().encode(s)))
    }
    func testDuplicateLineCapacityCannotBeBypassed() throws {
        let s = try seed()
        XCTAssertThrowsError(try s.checkCapacity([OrderLine(product: "p0", qty: 30, price: 1200), OrderLine(product: "p0", qty: 30, price: 1200)], day: "2025-06-01"))
    }
    func testQuoteDoesNotReserveOrEnterProductionUntilDeposit() throws {
        var s = try seed()
        let id = try s.createOrder(customer: "c0", lines: [OrderLine(product: "p2", qty: 1, price: 12000)], date: "2025-06-01", time: "10:00", type: "Custom", quote: true)
        XCTAssertFalse(s.order(id)!.reserves); XCTAssertTrue(s.batches("2025-06-01").isEmpty)
        try s.approveQuote(id); XCTAssertEqual(s.order(id)?.status, "Awaiting deposit")
        XCTAssertTrue(s.order(id)!.reserves); XCTAssertTrue(s.batches("2025-06-01").isEmpty)
        try s.recordPayment(id, full: false)
        XCTAssertEqual(s.order(id)?.paid, 6000); XCTAssertEqual(s.batches("2025-06-01").count, 1)
    }
    func testDepositsRemainAgreedAfterSettingsChange() throws {
        var s = try seed(); let old = s.order("1042")!.deposit
        s.settings.cakeDeposit = 100; try s.recordPayment("1042", full: false)
        XCTAssertEqual(s.order("1042")!.deposit, old); XCTAssertEqual(s.order("1042")!.paid, 6000)
    }
    func testUnpaidPickupRequiresExplicitChoice() throws {
        var s = try seed()
        let id = try s.createOrder(customer: "c0", lines: [OrderLine(product: "p2", qty: 1, price: 12000)], date: "2025-06-01", time: "10:00", payment: "deposit")
        try s.advance(id); try s.advance(id)
        XCTAssertThrowsError(try s.advance(id))
        try s.advance(id, allowUnpaid: true); XCTAssertEqual(s.order(id)?.status, "Picked up")
        XCTAssertEqual(s.order(id)?.balance, 6000)
    }
    func testCancelReleasesCapacityPreservesPayments() throws {
        var s = try seed()
        let id = try s.createOrder(customer: "c0", lines: [OrderLine(product: "p0", qty: 48, price: 1200)], date: "2025-06-01", time: "10:00", payment: "full")
        XCTAssertThrowsError(try s.checkCapacity([OrderLine(product: "p0", qty: 1, price: 1200)], day: "2025-06-01"))
        try s.cancel(id)
        XCTAssertEqual(s.order(id)?.paid, 57600)
        XCTAssertNoThrow(try s.checkCapacity([OrderLine(product: "p0", qty: 48, price: 1200)], day: "2025-06-01"))
    }
    func testProductPriceChangeDoesNotRewriteOrders() throws {
        var s = try seed(); let original = s.order("1041")!.total
        var p = s.product("p0")!; p.price = 9900; try s.saveProduct(p)
        XCTAssertEqual(s.order("1041")!.total, original)
    }
    func testRecurringFailureIsAtomic() throws {
        var s = try seed(); let original = s
        let p = RecurringPlan(id: "test", customer: "c0", product: "p0", qty: 100, start: "2025-06-01", time: "10:00", paused: false, exceptions: [:])
        XCTAssertThrowsError(try s.addRecurring(p)); XCTAssertEqual(s, original)
    }
    func testRecurringCreatesFourWeeksAndSkipSurvivesPause() throws {
        var s = try seed()
        try s.addRecurring(RecurringPlan(id: "test", customer: "c0", product: "p0", qty: 2, start: "2025-06-01", time: "10:00", paused: false, exceptions: [:]))
        let os = s.orders.filter { $0.series == "test" }; XCTAssertEqual(os.count, 4)
        XCTAssertEqual(os.map(\.date), ["2025-06-01", "2025-06-08", "2025-06-15", "2025-06-22"])
        try s.skipOccurrence(os[1].id); try s.advance(os[0].id); try s.pauseRecurring("test")
        XCTAssertEqual(s.order(os[0].id)?.status, "In production")
        try s.pauseRecurring("test"); XCTAssertEqual(s.order(os[1].id)?.status, "Skipped")
        try s.skipOccurrence(os[1].id); XCTAssertEqual(s.order(os[1].id)?.status, "Confirmed")
    }
    func testSingleWeekEditDoesNotRewriteSeriesAndResetsBatch() throws {
        var s = try seed()
        try s.addRecurring(RecurringPlan(id: "test", customer: "c0", product: "p0", qty: 2, start: "2025-06-01", time: "10:00", paused: false, exceptions: [:]))
        let o = s.orders.first { $0.series == "test" }!
        let b = s.batches(o.date)[0]; s.toggleBatch(b)
        XCTAssertTrue(s.tasks[b.taskKey("Mix")]!)
        try s.editOccurrence(o.id, quantity: 3, time: "11:00")
        XCTAssertEqual(s.recurring.first { $0.id == "test" }?.qty, 2)
        XCTAssertNil(s.tasks[s.batches(o.date)[0].taskKey("Mix")])
        XCTAssertEqual(s.order(o.id)?.lines.first?.qty, 3)
    }
    func testPaidOrderCannotBeReducedBelowPayment() throws {
        var s = try seed()
        let id = try s.createOrder(customer: "c0", lines: [OrderLine(product: "p0", qty: 3, price: 1200)], date: "2025-06-01", time: "10:00", payment: "full")
        var o = s.order(id)!; o.lines[0].qty = 1
        XCTAssertThrowsError(try s.editOrder(o)); XCTAssertEqual(s.order(id)?.total, 3600)
    }
    func testCheckoutClearsBasketOnlyAfterSuccessfulOrder() throws {
        var s = try seed(); s.cart = ["p0": 100]
        XCTAssertThrowsError(try s.checkout(customer: "c0", date: "2025-06-01", time: "10:00", notes: "")); XCTAssertEqual(s.cart["p0"], 100)
        s.cart = ["p0": 2]
        let id = try s.checkout(customer: "c0", date: "2025-06-01", time: "10:00", notes: "")
        XCTAssertTrue(s.cart.isEmpty); XCTAssertEqual(s.order(id)?.paid, 2400)
    }
    func testInvalidBackupRejected() throws {
        var s = try seed(); s.orders[0].paid = -1
        XCTAssertThrowsError(try s.validate())
        s = try seed(); s.orders[0].lines[0].qty = Int.max
        XCTAssertThrowsError(try s.validate())
        s = try seed(); s.orders.append(s.orders[0]); XCTAssertThrowsError(try s.validate())
    }
    func testDatesAndFormulaSafeCSV() throws {
        XCTAssertFalse(Clock.validDay("2025-02-30")); XCTAssertFalse(Clock.validTime("24:00"))
        var s = try seed(); s.customers[0].name = "=HYPERLINK(\"bad\")"
        XCTAssertTrue(s.ordersCSV().contains("'=HYPERLINK"))
    }
}
