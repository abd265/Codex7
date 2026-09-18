import UIKit
import PDFKit

/// Vector text, original logo proportions and repeated table headings on long orders.
enum ReceiptPDF {
    static func make(_ receipt: BakeryReceipt) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let ink = UIColor(red: 0.08, green: 0.19, blue: 0.17, alpha: 1)
        let teal = UIColor(red: 0.025, green: 0.43, blue: 0.38, alpha: 1)
        let muted = UIColor(white: 0.37, alpha: 1)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "\(receipt.title) RB-\(receipt.orderID)", kCGPDFContextAuthor as String: receipt.bakery]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        return renderer.pdfData { context in
            var y: CGFloat = 42
            var number = 0
            func attributes(_ size: CGFloat, _ bold: Bool = false, _ color: UIColor? = nil, _ alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
                let style = NSMutableParagraphStyle(); style.alignment = alignment; style.lineBreakMode = .byWordWrapping; style.lineSpacing = 3
                return [.font: UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular), .foregroundColor: color ?? ink, .paragraphStyle: style]
            }
            func height(_ text: String, width: CGFloat, size: CGFloat, bold: Bool = false) -> CGFloat {
                ceil((text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes(size, bold), context: nil).height)
            }
            @discardableResult func draw(_ text: String, x: CGFloat = 40, top: CGFloat, width: CGFloat = 532, size: CGFloat = 11, bold: Bool = false, color: UIColor? = nil, align: NSTextAlignment = .left) -> CGFloat {
                let h = height(text, width: width, size: size, bold: bold)
                (text as NSString).draw(in: CGRect(x: x, y: top, width: width, height: h + 2), withAttributes: attributes(size, bold, color, align))
                return h
            }
            func rule(_ top: CGFloat) { UIColor(white: 0.87, alpha: 1).setFill(); UIRectFill(CGRect(x: 40, y: top, width: 532, height: 0.6)) }
            func beginPage() {
                context.beginPage(); number += 1; y = 42
                teal.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 612, height: 7))
                rule(744)
                draw("\(receipt.bakery) • #RB-\(receipt.orderID)", top: 754, width: 440, size: 8, color: muted)
                draw("Page \(number)", x: 502, top: 754, width: 70, size: 8, color: muted, align: .right)
                if number > 1 {
                    y += draw("\(receipt.title) #RB-\(receipt.orderID) · continued", top: y, size: 14, bold: true) + 20
                }
            }
            func ensure(_ needed: CGFloat) { if y + needed > 720 { beginPage() } }
            func tableHeading() {
                UIColor(red: 0.92, green: 0.96, blue: 0.94, alpha: 1).setFill()
                UIRectFill(CGRect(x: 40, y: y, width: 532, height: 30))
                draw("ITEM", x: 50, top: y + 8, width: 250, size: 9, bold: true, color: teal)
                draw("QTY", x: 312, top: y + 8, width: 40, size: 9, bold: true, color: teal, align: .right)
                draw("UNIT", x: 360, top: y + 8, width: 85, size: 9, bold: true, color: teal, align: .right)
                draw("AMOUNT", x: 453, top: y + 8, width: 109, size: 9, bold: true, color: teal, align: .right)
                y += 30
            }
            beginPage()
            let logo = receipt.profile.logoData.flatMap { UIImage(data: $0) }
            let nameWidth: CGFloat = logo == nil ? 532 : 380
            y += draw(receipt.bakery, top: y, width: nameWidth, size: 26, bold: true, color: teal) + 10
            for line in receipt.profile.contactLines { y += draw(line, top: y, width: nameWidth, size: 10, color: muted) + 3 }
            if let logo {
                let box = CGRect(x: 452, y: 42, width: 120, height: 100)
                let scale = min(box.width / logo.size.width, box.height / logo.size.height)
                let size = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
                logo.draw(in: CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height))
                y = max(y, box.maxY)
            }
            y += 18; rule(y); y += 20
            y += draw(receipt.title, top: y, size: 24, bold: true) + 6
            y += draw("#RB-\(receipt.orderID) · \(receipt.paymentStatus)", top: y, size: 11, bold: true, color: teal) + 18
            y += draw("CUSTOMER", top: y, size: 8, bold: true, color: muted) + 5
            y += draw(receipt.customer, top: y, size: 13, bold: true) + 10
            y += draw("Ordered: \(receipt.created)    |    Pickup: \(receipt.pickup)", top: y, size: 10, color: muted) + 5
            y += draw("Order status: \(receipt.status)", top: y, size: 10, color: muted) + 20
            ensure(65); tableHeading()
            for line in receipt.lines {
                let rowHeight = max(16, height(line.name, width: 250, size: 11)) + 22
                if y + rowHeight > 720 { beginPage(); tableHeading() }
                draw(line.name, x: 50, top: y + 10, width: 250, size: 11)
                draw(String(line.quantity), x: 312, top: y + 10, width: 40, size: 11, align: .right)
                draw(money(line.unitPrice), x: 360, top: y + 10, width: 85, size: 11, align: .right)
                draw(money(line.amount), x: 453, top: y + 10, width: 109, size: 11, bold: true, align: .right)
                y += rowHeight; rule(y)
            }
            y += 22; ensure(128)
            for (label, amount) in [("Total (CAD)", receipt.total), ("Payments recorded", receipt.paid), ("Balance due", receipt.balance)] {
                let isBalance = label == "Balance due"
                if isBalance { UIColor(red: 0.92, green: 0.96, blue: 0.94, alpha: 1).setFill(); UIRectFill(CGRect(x: 302, y: y - 6, width: 270, height: 32)) }
                draw(label, x: 312, top: y, width: 150, size: 11, bold: isBalance)
                draw(money(amount), x: 462, top: y, width: 100, size: 11, bold: true, color: isBalance ? teal : ink, align: .right)
                y += 32
            }
            y += 16
            if !receipt.profile.footer.isEmpty {
                let h = height(receipt.profile.footer, width: 532, size: 11)
                ensure(h + 22); rule(y); y += 16
                y += draw(receipt.profile.footer, top: y, size: 11, color: muted)
            }
        }
    }

    static func save(_ receipt: BakeryReceipt) throws -> URL {
        // Each export is immutable, so sharing another receipt cannot replace this file.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RiseBake-receipts/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeID = receipt.orderID.filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(60)
        let url = folder.appendingPathComponent("\(receipt.title.replacingOccurrences(of: " ", with: "-"))-RB-\(safeID).pdf")
        let data = make(receipt)
        guard PDFDocument(data: data) != nil else { throw BakeryError("The receipt could not be generated. Please try again.") }
        try data.write(to: url, options: .atomic)
        return url
    }
}
