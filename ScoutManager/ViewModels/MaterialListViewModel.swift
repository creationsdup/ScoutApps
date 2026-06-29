import Foundation

@MainActor
final class MaterialListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var categories: [ItemCategory] = []
    @Published var locations: [ItemLocation] = []

    @Published var search = ""
    @Published var statusFilter: ItemStatus?
    @Published var categoryFilter: String?
    @Published var locationFilter: String?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ItemService()

    func loadReferentials() async {
        categories = (try? await service.listCategories()) ?? []
        locations = (try? await service.listLocations()) ?? []
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await service.list(
                search: search.isEmpty ? nil : search,
                status: statusFilter,
                categoryId: categoryFilter,
                locationId: locationFilter
            )
        } catch {
            errorMessage = "Impossible de charger le matériel."
            items = []
        }
        isLoading = false
    }

    var activeFilterCount: Int {
        [statusFilter != nil, categoryFilter != nil, locationFilter != nil].filter { $0 }.count
    }

    func clearFilters() {
        statusFilter = nil
        categoryFilter = nil
        locationFilter = nil
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
