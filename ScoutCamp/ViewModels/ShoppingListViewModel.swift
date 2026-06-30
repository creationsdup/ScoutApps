import Foundation
import ScoutKit

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = []
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private let service = ShoppingService()

    func load(campId: String) async {
        isLoading = true; errorMessage = nil
        do { items = try await service.list(campId: campId) }
        catch { errorMessage = "Impossible de charger la liste."; items = [] }
        isLoading = false
    }

    func generate(camp: Camp) async {
        isGenerating = true; errorMessage = nil
        do {
            try await service.regenerateAuto(campId: camp.id)
            await load(campId: camp.id)
        } catch {
            errorMessage = "Génération impossible : \(error.localizedDescription)"
        }
        isGenerating = false
    }

    func addManual(campId: String, name: String, quantity: Double?, unit: String?) async {
        do {
            let item = ShoppingItem(id: UUID().uuidString, campId: campId,
                                    name: name, quantity: quantity, unit: unit,
                                    checked: false, source: .manual)
            let saved = try await service.add(item)
            items.append(saved)
        } catch { errorMessage = "Ajout impossible : \(error.localizedDescription)" }
    }

    func toggle(_ item: ShoppingItem) async {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].checked.toggle()
        do { try await service.update(items[i]) }
        catch { items[i].checked.toggle(); errorMessage = "Mise à jour impossible." } // rollback UI
    }

    func delete(_ item: ShoppingItem) async {
        do { try await service.delete(id: item.id); items.removeAll { $0.id == item.id } }
        catch { errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }
}
