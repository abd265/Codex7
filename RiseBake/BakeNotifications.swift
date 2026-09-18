import Foundation
import UserNotifications

@MainActor final class BakeNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BakeNotifications()
    private var generation = 0
    private override init() { super.init(); UNUserNotificationCenter.current().delegate = self }
    func request() async throws -> Bool { try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
    func sync(_ sessions: [BakeSession]) {
        generation += 1; let requestGeneration = generation
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard requestGeneration == generation else { return }
            center.removeAllPendingNotificationRequests()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let pending = sessions.filter { !$0.complete }.flatMap { session in
                session.steps.compactMap { step -> (String, String, Double)? in
                    guard let deadline = step.deadline, deadline > Date().timeIntervalSince1970,
                          let method = session.recipe.method.first(where: { $0.id == step.id }) else { return nil }
                    return (session.id + ":" + step.id, session.recipe.name + " · " + method.title, deadline)
                }
            }.sorted { $0.2 < $1.2 }
            for (id, title, deadline) in pending.prefix(60) {
                let content = UNMutableNotificationContent(); content.title = "Time to check your bake"
                content.body = title; content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline - Date().timeIntervalSince1970), repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger), withCompletionHandler: nil)
            }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .sound]) }
}
