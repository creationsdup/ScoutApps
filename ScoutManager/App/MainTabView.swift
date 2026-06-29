import SwiftUI

/// Navigation principale : 5 onglets, identité bleu SGDF dominante.
/// Les écrans réels remplaceront les ComingSoonView dans les plans suivants.
struct MainTabView: View {
    init() {
        // TabBar et NavBar ancrées sur le bleu SGDF (identité dominante).
        let tint = UIColor(SGDFColors.primaryBlue)
        UITabBar.appearance().tintColor = tint
        UINavigationBar.appearance().tintColor = tint
    }

    var body: some View {
        TabView {
            ComingSoonView(title: "Dashboard")
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            ComingSoonView(title: "Matériel")
                .tabItem { Label("Matériel", systemImage: "shippingbox") }
            ComingSoonView(title: "Scan")
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
            ComingSoonView(title: "Intendance")
                .tabItem { Label("Intendance", systemImage: "fork.knife") }
            ComingSoonView(title: "Camp")
                .tabItem { Label("Camp", systemImage: "tent") }
        }
        .tint(SGDFColors.primaryBlue)
    }
}
