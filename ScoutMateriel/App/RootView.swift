import SwiftUI
import ScoutKit

struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
