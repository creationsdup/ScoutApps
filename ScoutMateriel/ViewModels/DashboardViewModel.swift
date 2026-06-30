import Foundation
import ScoutKit

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var snapshot = DashboardSnapshot()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = DashboardService()

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            snapshot = try await service.loadSnapshot()
        } catch {
            errorMessage = "Impossible de charger le tableau de bord. Vérifie la connexion ou la base."
        }
        isLoading = false
    }
}
