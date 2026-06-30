import Foundation
import ScoutKit

@MainActor
final class CampMaterialViewModel: ObservableObject {
    @Published var items: [Item] = []          // chargement du camp
    @Published var available: [Item] = []      // items disponibles (pour l'ajout)
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = CampMaterialService()
    private let itemService = ItemService()

    func load(campId: String) async {
        isLoading = true; errorMessage = nil
        do { items = try await service.items(campId: campId) }
        catch { errorMessage = "Impossible de charger le matériel du camp."; items = [] }
        isLoading = false
    }

    func loadAvailable() async {
        available = (try? await itemService.list(status: .disponible)) ?? []
    }

    func add(campId: String, itemIds: Set<String>) async {
        do {
            for id in itemIds { try await service.assign(campId: campId, itemId: id) }
            await load(campId: campId)
        } catch { errorMessage = "Ajout impossible : \(error.localizedDescription)" }
    }

    func remove(campId: String, item: Item) async {
        do { try await service.remove(campId: campId, itemId: item.id); items.removeAll { $0.id == item.id } }
        catch { errorMessage = "Retour impossible : \(error.localizedDescription)" }
    }

    func returnAll(campId: String) async {
        do { try await service.returnAll(campId: campId); items = [] }
        catch { errorMessage = "Retour impossible : \(error.localizedDescription)" }
    }
}
