import SwiftUI
import MessageUI

struct CustomerComposer: UIViewControllerRepresentable {
    var customer: Customer
    var text: String
    var completed: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed: completed) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let view = MFMailComposeViewController(); view.mailComposeDelegate = context.coordinator
        view.setToRecipients([customer.email]); view.setSubject("Your bakery order"); view.setMessageBody(text, isHTML: false)
        return view
    }
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var completed: (Bool) -> Void
        init(completed: @escaping (Bool) -> Void) { self.completed = completed }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { completed(result == .sent && error == nil) }
    }
}
struct CustomerSMSComposer: UIViewControllerRepresentable {
    var customer: Customer
    var text: String
    var completed: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed: completed) }
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let view = MFMessageComposeViewController(); view.messageComposeDelegate = context.coordinator
        view.recipients = [customer.phone]; view.body = text; return view
    }
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var completed: (Bool) -> Void
        init(completed: @escaping (Bool) -> Void) { self.completed = completed }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) { completed(result == .sent) }
    }
}
