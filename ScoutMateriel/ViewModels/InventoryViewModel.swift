import Foundation
import ScoutKit

@MainActor
final class InventoryViewModel: ObservableObject {
    enum Phase { case scope, scanning, summary }

    @Published var phase: Phase = .scope
    @Published var useLocation = true
    @Published var selectedLocationId: String?
    @Published var selectedCategoryId: String?
    @Published var expected: [Item] = []
    @Published var pointedIds: Set<String> = []
    @Published var extras: [Item] = []
    @Published var manualCode = ""
    @Published var categories: [ItemCategory] = []
    @Published var locations: [ItemLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var scanMessage: String?
    @Published var closed = false

    private let itemService = ItemService()

    var present: [Item] { expected.filter { pointedIds.contains($0.id) } }
    var missing: [Item] { expected.filter { !pointedIds.contains($0.id) } }
    var remaining: Int { missing.count }
    var canStart: Bool { useLocation ? selectedLocationId != nil : selectedCategoryId != nil }

    func loadReferentials() async {
        let cats = try? await itemService.listCategories()
        let locs = try? await itemService.listLocations()
        categories = cats ?? []
        locations = locs ?? []
        if cats == nil || locs == nil {
            errorMessage = "Impossible de charger catégories/localisations."
        }
    }

    func start() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let items = useLocation
                ? try await itemService.list(locationId: selectedLocationId)
                : try await itemService.list(categoryId: selectedCategoryId)
            expected = items
            pointedIds = []
            extras = []
            scanMessage = nil
            phase = .scanning
        } catch {
            errorMessage = "Impossible de charger le matériel du périmètre."
        }
    }

    func resolve(_ raw: String) {
        manualCode = ""
        guard let code = TagCode.parse(raw) else {
            scanMessage = "Code invalide. Format attendu : TEN-0001."
            return
        }
        Task {
            do {
                guard let item = try await itemService.item(byCode: code) else {
                    scanMessage = "Code inconnu."
                    return
                }
                if let known = expected.first(where: { $0.id == item.id }) {
                    pointedIds.insert(known.id)
                    scanMessage = "✓ \(known.name)"
                } else {
                    if !extras.contains(where: { $0.id == item.id }) { extras.append(item) }
                    scanMessage = "En trop : \(item.name) (hors périmètre)"
                }
            } catch {
                scanMessage = "Erreur de lecture. Réessaie."
            }
        }
    }

    func toggle(_ item: Item) {
        if pointedIds.contains(item.id) { pointedIds.remove(item.id) }
        else { pointedIds.insert(item.id) }
    }

    func finish() { phase = .summary }

    func close() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await itemService.markChecked(itemIds: present.map(\.id))
            closed = true
        } catch {
            errorMessage = "Impossible d'enregistrer l'inventaire. Réessaie."
        }
    }
}
