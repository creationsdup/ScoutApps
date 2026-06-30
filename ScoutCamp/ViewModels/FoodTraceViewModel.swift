import Foundation
import ScoutKit

@MainActor
final class FoodTraceViewModel: ObservableObject {
    @Published var entries: [FoodTraceEntry] = []
    @Published var meals: [Meal] = []          // pour le lien repas optionnel
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = FoodTraceService()
    private let mealService = MealService()
    private let storage = ImageStorageService()

    func load(campId: String) async {
        isLoading = true; errorMessage = nil
        do {
            entries = try await service.list(campId: campId)
            meals = (try? await mealService.list(campId: campId)) ?? []
        } catch { errorMessage = "Impossible de charger le registre."; entries = [] }
        isLoading = false
    }

    func delete(_ entry: FoodTraceEntry) async {
        do { try await service.delete(id: entry.id); entries.removeAll { $0.id == entry.id } }
        catch { errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }

    /// Crée/maj une entrée ; téléverse la photo (si fournie) avant l'écrasement du chemin.
    func save(_ entry: FoodTraceEntry, isNew: Bool, photoData: Data?) async throws {
        var toSave = entry
        if let data = photoData {
            toSave.photoPath = try await storage.upload(data, path: "trace/\(entry.id).jpg")
        }
        if isNew {
            let created = try await service.create(toSave)
            entries.insert(created, at: 0)
        } else {
            try await service.update(toSave)
            if let i = entries.firstIndex(where: { $0.id == toSave.id }) { entries[i] = toSave }
        }
    }

    func mealLabel(_ id: String?) -> String? {
        guard let id, let m = meals.first(where: { $0.id == id }) else { return nil }
        return "\(m.date) · \(m.slot.label)" + (m.title.map { " · \($0)" } ?? "")
    }
}
