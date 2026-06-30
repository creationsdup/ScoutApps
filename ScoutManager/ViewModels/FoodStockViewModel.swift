import Foundation

@MainActor
final class FoodStockViewModel: ObservableObject {
    @Published var items: [FoodStockItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = FoodStockService()
    func expiryStatus(_ item: FoodStockItem) -> ExpiryStatus {
        guard let s = item.expiryDate, let date = SGDFDate.day(from: s) else { return .none }
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let day = cal.startOfDay(for: date)
        guard let diff = cal.dateComponents([.day], from: today, to: day).day else { return .none }
        if diff < 0 { return .expired }
        if diff <= 7 { return .soon }
        return .ok
    }

    func load(campId: String) async {
        isLoading = true; errorMessage = nil
        do { items = try await service.list(campId: campId) }
        catch { errorMessage = "Impossible de charger le stock."; items = [] }
        isLoading = false
    }

    func delete(_ item: FoodStockItem) async {
        do { try await service.delete(id: item.id); items.removeAll { $0.id == item.id } }
        catch { errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }

    func save(_ item: FoodStockItem, isNew: Bool) async throws {
        if isNew {
            let created = try await service.create(item)
            items.append(created)
        } else {
            try await service.update(item)
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
        }
    }
}
