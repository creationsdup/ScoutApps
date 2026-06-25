import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                ScanView()
            } else {
                LoginView()
            }
        }
    }
}
