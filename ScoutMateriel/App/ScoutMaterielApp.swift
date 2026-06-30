import SwiftUI
import ScoutKit

@main
struct ScoutMaterielApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var router = AppRouter()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(router)
                .tint(SGDFColors.primaryBlue)
                .task { await session.restore() }
        }
    }
}
