import Foundation
import ScoutKit

struct MaterialSubcategoryGroup: Identifiable {
    let id: String        // id de sous-catégorie, ou "none"
    let name: String
    let items: [Item]
}

struct MaterialCategoryGroup: Identifiable {
    let id: String        // id de catégorie, ou "none"
    let name: String
    let subgroups: [MaterialSubcategoryGroup]
}

@MainActor
final class MaterialListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var categories: [ItemCategory] = []
    @Published var locations: [ItemLocation] = []
    @Published var subcategories: [Subcategory] = []

    @Published var search = ""
    @Published var statusFilter: ItemStatus?
    @Published var categoryFilter: String?
    @Published var subcategoryFilter: String?
    @Published var locationFilter: String?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ItemService()

    func loadReferentials() async {
        categories = (try? await service.listCategories()) ?? []
        locations = (try? await service.listLocations()) ?? []
        subcategories = (try? await service.listSubcategories()) ?? []
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await service.list(
                search: search.isEmpty ? nil : search,
                status: statusFilter,
                categoryId: categoryFilter,
                subcategoryId: subcategoryFilter,
                locationId: locationFilter
            )
        } catch {
            errorMessage = "Impossible de charger le matériel."
            items = []
        }
        isLoading = false
    }

    var activeFilterCount: Int {
        [statusFilter != nil, categoryFilter != nil, subcategoryFilter != nil, locationFilter != nil].filter { $0 }.count
    }

    func clearFilters() {
        statusFilter = nil
        categoryFilter = nil
        subcategoryFilter = nil
        locationFilter = nil
    }

    /// Sous-catégories de la catégorie filtrée (vide si aucune catégorie choisie).
    var filteredSubcategories: [Subcategory] {
        guard let categoryFilter else { return [] }
        return subcategories.filter { $0.categoryId == categoryFilter }
    }

    /// `items` (déjà filtrés côté serveur) regroupés par catégorie puis sous-catégorie.
    var groups: [MaterialCategoryGroup] {
        let catName: (String?) -> String = { id in
            guard let id else { return "Sans catégorie" }
            return self.categories.first { $0.id == id }?.name ?? "Sans catégorie"
        }
        let subName: (String?) -> String = { id in
            guard let id else { return "Sans sous-catégorie" }
            return self.subcategories.first { $0.id == id }?.name ?? "Sans sous-catégorie"
        }
        let byCategory = Dictionary(grouping: items) { $0.categoryId ?? "none" }
        return byCategory.keys.sorted { catName($0 == "none" ? nil : $0) < catName($1 == "none" ? nil : $1) }
            .map { catKey in
                let catItems = byCategory[catKey] ?? []
                let bySub = Dictionary(grouping: catItems) { $0.subcategoryId ?? "none" }
                let subgroups = bySub.keys
                    .sorted { subName($0 == "none" ? nil : $0) < subName($1 == "none" ? nil : $1) }
                    .map { subKey in
                        MaterialSubcategoryGroup(
                            id: subKey,
                            name: subName(subKey == "none" ? nil : subKey),
                            items: (bySub[subKey] ?? []).sorted { $0.inventoryCode < $1.inventoryCode }
                        )
                    }
                return MaterialCategoryGroup(
                    id: catKey,
                    name: catName(catKey == "none" ? nil : catKey),
                    subgroups: subgroups
                )
            }
    }

    func categoryName(_ id: String?) -> String? {
        guard let id else { return nil }
        return categories.first { $0.id == id }?.name
    }
    func locationName(_ id: String?) -> String? {
        guard let id else { return nil }
        return locations.first { $0.id == id }?.name
    }
}
