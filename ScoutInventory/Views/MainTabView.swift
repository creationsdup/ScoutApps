import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ScanView()
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }

            MaterialListView()
                .tabItem { Label("Matériel", systemImage: "shippingbox") }

            EventsListView()
                .tabItem { Label("Évènements", systemImage: "calendar") }
        }
    }
}
