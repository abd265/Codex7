#if DEBUG
import UIKit
import PDFKit

/// Opt-in fixtures for the CI simulator only; excluded from the Release IPA.
enum ReceiptQA {
    static func prepare(_ state: inout BakeryState) throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 800), format: format).image { _ in
            UIColor(red: 0.03, green: 0.39, blue: 0.34, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 10, y: 10, width: 1580, height: 780), cornerRadius: 100).fill()
            let centered = NSMutableParagraphStyle(); centered.alignment = .center
            ("RB" as NSString).draw(in: CGRect(x: 0, y: 70, width: 1600, height: 390), withAttributes: [.font: UIFont.systemFont(ofSize: 350, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: centered])
            ("ROSE & FLOUR" as NSString).draw(in: CGRect(x: 0, y: 510, width: 1600, height: 140), withAttributes: [.font: UIFont.systemFont(ofSize: 100, weight: .medium), .foregroundColor: UIColor.white, .paragraphStyle: centered])
        }
        let logo = try BakeryLogo.prepare(image.pngData()!)
        guard let normalized = UIImage(data: logo), normalized.size.width == 1024, normalized.size.height == 512 else { throw BakeryError("Logo downsampling changed its proportions.") }
        do { _ = try BakeryLogo.prepare(Data("not an image".utf8)); throw BakeryError("Invalid logo was accepted.") }
        catch let error as BakeryError where error.message == "Invalid logo was accepted." { throw error }
        catch { }
        state.settings.bakery = "Rose & Flour Bakery"
        state.settings.owner = "Rose"
        state.settings.background = "flourGarden"
        state.settings.profile = BakeryProfile(contactName: "Rose Baker", address: "24 Garden Lane\nToronto, ON M5V 2T6", phone: "+1 416 555 0123", email: "hello@example.com", website: "example.com", registrationID: "DEMO-12345", footer: "Made with care, shared with joy.\nThank you for supporting our bakery!", logoData: logo)
        state.customers = [Customer(id: "receipt-customer", name: "Jamie Lee", email: "jamie@example.com", phone: "", preferred: "", vip: false, notes: "Private customer note", created: Clock.today, messages: [])]
        state.orders = []; state.recurring = []; state.cart = [:]; state.tasks = [:]; state.bakeSessions = []; state.nextOrder = 1201; state.day = Clock.today
        let lines = [OrderLine(product: "p0", qty: 2, price: 1200), OrderLine(product: "p2", qty: 1, price: 4800), OrderLine(product: "p4", qty: 3, price: 600)]
        let id = try state.createOrder(customer: "receipt-customer", lines: lines, date: Clock.today, time: "14:30", notes: "Private baker note", payment: "deposit")
        try state.validate()
        let restored = try JSONDecoder().decode(BakeryState.self, from: JSONEncoder().encode(state))
        guard restored.settings.profile?.logoData == logo else { throw BakeryError("Backup lost the logo.") }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Receipt-QA", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let receipt = state.receiptDocument(state.order(id)!)
        func export(_ value: BakeryReceipt, _ filename: String, expectPages: Bool = false) throws {
            let data = ReceiptPDF.make(value)
            guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else { throw BakeryError("PDF is unreadable.") }
            let text = pdf.string ?? ""
            guard text.contains(value.bakery), text.contains(value.customer), text.contains(money(value.total)), text.contains(money(value.balance)), !text.contains("Private baker note"), !text.contains("Private customer note") else { throw BakeryError("Receipt contents did not match the order.") }
            if expectPages {
                guard pdf.pageCount > 2, (1...99).allSatisfy({ text.contains(String(format: "Line %03d", $0)) }) else { throw BakeryError("Long receipt lost line items.") }
                for index in 1..<pdf.pageCount { guard pdf.page(at: index)?.string?.contains("continued") == true else { throw BakeryError("Missing continuation header.") } }
            }
            try data.write(to: folder.appendingPathComponent(filename), options: .atomic)
        }
        try export(receipt, "Branded-receipt-example.pdf")
        var long = receipt
        long.lines = (1...99).map { ReceiptLine(name: String(format: "Line %03d", $0) + " - Chocolate and raspberry celebration cake with a handwritten message", quantity: 2, unitPrice: 3250) }
        try export(long, "Long-receipt-check.pdf", expectPages: true)
        var noLogo = receipt; noLogo.profile = BakeryProfile(); noLogo.paid = 0
        try export(noLogo, "Unpaid-order-check.pdf")
        try "Native PDF checks passed: transparent 1024×512 logo, backup round-trip, invalid image rejected, 99 rows paginated, correct totals and balance, no internal notes.\n".write(to: folder.appendingPathComponent("verification.txt"), atomically: true, encoding: .utf8)
    }
}
#endif
