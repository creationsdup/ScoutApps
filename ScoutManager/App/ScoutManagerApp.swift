import SwiftUI

@main
struct ScoutManagerApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var router = AppRouter()
    @StateObject private var campStore = CampStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(router)
                .environmentObject(campStore)
                .tint(SGDFColors.primaryBlue)
                .task { await session.restore() }
        }
    }
}
