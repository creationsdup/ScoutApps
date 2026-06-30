import SwiftUI
import ScoutKit

@main
struct ScoutCampApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var campStore = CampStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(campStore)
                .tint(SGDFColors.primaryBlue)
                .task { await session.restore() }
        }
    }
}
