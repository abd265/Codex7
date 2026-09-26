import SwiftUI

@main
struct PrismHarbourApp: App {
    @StateObject private var store = HarbourStore()
    var body: some Scene {
        WindowGroup {
            HarbourRootView().environmentObject(store).preferredColorScheme(.dark)
                .tint(HarbourTheme.lavender)
        }
    }
}
