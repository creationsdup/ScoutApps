import Foundation
import ScoutKit

/// Statistiques agrégées du matériel pour le tableau de bord.
struct DashboardStats: Equatable {
    var total = 0
    var available = 0
    var checkedOut = 0
    var toRepair = 0
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var stats = DashboardStats()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ItemService()

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let items = try await service.list(includeArchived: false)
            stats = DashboardStats(
                total: items.count,
                available: items.filter { $0.status == .disponible }.count,
                checkedOut: items.filter { $0.status == .sorti }.count,
                toRepair: items.filter { $0.status == .aReparer }.count
            )
        } catch {
            errorMessage = "Impossible de charger le matériel. Vérifie la connexion ou la base."
        }
        isLoading = false
    }
}
