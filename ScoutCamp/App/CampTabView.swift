import SwiftUI
import ScoutKit

/// Shell de ScoutCamp : 2 onglets (Intendance / Programme). Le sélecteur de camp est
/// embarqué dans chaque vue d'accueil (via CampStore), comportement inchangé.
struct CampTabView: View {
    init() {
        let tint = UIColor(SGDFColors.primaryBlue)
        UITabBar.appearance().tintColor = tint
        UINavigationBar.appearance().tintColor = tint
    }

    var body: some View {
        TabView {
            IntendanceHomeView()
                .tabItem { Label("Intendance", systemImage: "fork.knife") }
            ProgramHomeView()
                .tabItem { Label("Programme", systemImage: "tent") }
        }
        .tint(SGDFColors.primaryBlue)
    }
}
