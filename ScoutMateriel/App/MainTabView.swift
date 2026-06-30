import SwiftUI
import ScoutKit

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    init() {
        let tint = UIColor(SGDFColors.primaryBlue)
        UITabBar.appearance().tintColor = tint
        UINavigationBar.appearance().tintColor = tint
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(AppRouter.Tab.dashboard)
            MaterialListView()
                .tabItem { Label("Matériel", systemImage: "shippingbox") }
                .tag(AppRouter.Tab.material)
            QRScannerView()
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
                .tag(AppRouter.Tab.scan)
            CheckoutListView()
                .tabItem { Label("Sorties", systemImage: "arrow.up.bin") }
                .tag(AppRouter.Tab.sorties)
        }
        .tint(SGDFColors.primaryBlue)
    }
}
