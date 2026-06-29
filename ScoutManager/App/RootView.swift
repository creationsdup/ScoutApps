import SwiftUI

/// Aiguillage racine : non connecté → login existant ; connecté → MainTabView.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
