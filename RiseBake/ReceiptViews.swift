import SwiftUI
import PDFKit

struct ReceiptView: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var order: Order
    @State private var url: URL?
    @State private var error: String?
    @State private var printing = false
    private var receipt: BakeryReceipt { store.state.receiptDocument(order) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        if receipt.profile.logoData != nil { BakeryLogoView(data: receipt.profile.logoData, size: 80) }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(receipt.bakery).font(.title2.bold()).foregroundStyle(Color.bakeTeal)
                            ForEach(Array(receipt.profile.contactLines.enumerated()), id: \.offset) { _, line in Text(line).font(.subheadline).foregroundStyle(.secondary) }
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(receipt.title).font(.title.bold())
                        Text("#RB-\(receipt.orderID) · \(receipt.paymentStatus)").font(.subheadline.weight(.semibold)).foregroundStyle(Color.bakeTeal)
                        Text(receipt.customer).font(.headline)
                        Text("Ordered: \(receipt.created)")
                        Text("Pickup: \(receipt.pickup)")
                        Text("Order status: \(receipt.status)")
                    }
                    Divider()
                    ForEach(Array(receipt.lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top) { VStack(alignment: .leading, spacing: 4) { Text(line.name).fontWeight(.medium); Text("\(line.quantity) × \(money(line.unitPrice))").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Text(money(line.amount)).fontWeight(.semibold).monospacedDigit() }
                    }
                    Divider()
                    VStack(spacing: 12) {
                        LabeledContent("Total (CAD)", value: money(receipt.total)).fontWeight(.semibold)
                        LabeledContent("Payments recorded", value: money(receipt.paid))
                        LabeledContent("Balance due", value: money(receipt.balance)).font(.headline).foregroundStyle(Color.bakeTeal)
                    }.monospacedDigit()
                    if !receipt.profile.footer.isEmpty { Divider(); Text(receipt.profile.footer).font(.subheadline).foregroundStyle(.secondary) }
                    if let url {
                        NavigationLink { ReceiptPDFPreview(url: url).navigationTitle("PDF preview").navigationBarTitleDisplayMode(.inline) } label: { Label("Preview PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }.buttonStyle(.bordered).accessibilityIdentifier("receipt.preview")
                        ShareLink(item: url) { Label("Share PDF", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).accessibilityIdentifier("receipt.share")
                        Button { printing = true } label: { Label("Print receipt", systemImage: "printer").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    } else if error == nil { ProgressView("Preparing PDF…") }
                    if let error { Text(error).foregroundStyle(.red); Button("Try again", action: prepare) }
                }.padding(24).textSelection(.enabled)
            }.background(Color(uiColor: .systemBackground)).navigationTitle(receipt.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .task { prepare() }
                .sheet(isPresented: $printing) { if let url { ReceiptPrintSheet(url: url, error: $error) } }
        }
    }
    private func prepare() { do { error = nil; url = try ReceiptPDF.save(receipt) } catch { self.error = error.localizedDescription } }
}

struct ReceiptPDFPreview: UIViewRepresentable {
    var url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous; view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url); return view
    }
    func updateUIView(_ view: PDFView, context: Context) { if view.document?.documentURL != url { view.document = PDFDocument(url: url) } }
}

struct ReceiptPrintSheet: UIViewControllerRepresentable {
    var url: URL
    @Binding var error: String?
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> PrintHost {
        let controller = PrintHost(); controller.url = url
        controller.finished = { message in if let message { error = message }; dismiss() }
        return controller
    }
    func updateUIViewController(_ controller: PrintHost, context: Context) {}
    static func dismantleUIViewController(_ controller: PrintHost, coordinator: ()) { UIPrintInteractionController.shared.dismiss(animated: false) }
    final class PrintHost: UIViewController {
        var url: URL!
        var finished: ((String?) -> Void)?
        private var presented = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !presented else { return }; presented = true
            guard UIPrintInteractionController.isPrintingAvailable else { finished?("Printing is unavailable on this device. You can still share the PDF."); return }
            let printer = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil); info.jobName = url.deletingPathExtension().lastPathComponent; info.outputType = .general
            printer.printInfo = info; printer.printingItem = url
            let completion: (UIPrintInteractionController, Bool, Error?) -> Void = { [weak self] _, _, error in self?.finished?(error?.localizedDescription) }
            let shown: Bool
            if UIDevice.current.userInterfaceIdiom == .pad { shown = printer.present(from: CGRect(x: view.bounds.midX, y: 20, width: 1, height: 1), in: view, animated: true, completionHandler: completion) }
            else { shown = printer.present(animated: true, completionHandler: completion) }
            if !shown { finished?("The print dialog could not open. Try sharing the PDF instead.") }
        }
    }
}
