import SwiftUI

@main
struct ScoutManagerApp: App {
    @StateObject private var session = SessionStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(SGDFColors.primaryBlue)
                .task { await session.restore() }
        }
    }
}
