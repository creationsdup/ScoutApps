import SwiftUI
import ScoutKit

/// Racine de ScoutCamp : login ↔ shell camp (Intendance / Programme).
struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    var body: some View {
        Group {
            if session.isAuthenticated {
                CampTabView()
            } else {
                LoginView()
            }
        }
    }
}
