import SwiftUI

@main
struct ScoutManagerApp: App {
    @StateObject private var appState = AppState()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(SGDFColors.primaryBlue)
        }
    }
}
