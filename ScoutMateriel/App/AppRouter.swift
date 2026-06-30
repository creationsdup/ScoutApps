import SwiftUI
import ScoutKit

/// Sélection d'onglet partagée, pour que les raccourcis du Dashboard changent d'onglet.
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable { case dashboard, material, scan }
    @Published var selectedTab: Tab = .dashboard
}
