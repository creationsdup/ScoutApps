import Foundation

@MainActor
final class MealPlanViewModel: ObservableObject {
    @Published var meals: [Meal] = []          // tous les repas du camp
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = MealService()
    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Jours du camp ["yyyy-MM-dd", …] de startDate à endDate inclus. Vide si dates manquantes.
    func days(of camp: Camp) -> [String] {
        guard let s = camp.startDate, let e = camp.endDate,
              let start = Self.df.date(from: s), let end = Self.df.date(from: e),
              start <= end else { return [] }
        var result: [String] = []
        var d = start
        let cal = Calendar(identifier: .gregorian)
        while d <= end {
            result.append(Self.df.string(from: d))
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return result
    }

    func meal(date: String, slot: MealSlot) -> Meal? {
        meals.first { $0.date == date && $0.slot == slot }
    }

    func load(campId: String) async {
        isLoading = true; errorMessage = nil
        do { meals = try await service.list(campId: campId) }
        catch { errorMessage = "Impossible de charger les menus."; meals = [] }
        isLoading = false
    }

    /// Crée/met à jour le repas d'une case. Retourne le repas sauvé. Erreur propagée à l'appelant.
    @discardableResult
    func save(campId: String, date: String, slot: MealSlot,
              existingId: String?, title: String, notes: String) async throws -> Meal {
        let meal = Meal(id: existingId ?? UUID().uuidString,
                        campId: campId, date: date, slot: slot,
                        title: title.isEmpty ? nil : title,
                        notes: notes.isEmpty ? nil : notes)
        let saved = try await service.upsert(meal)
        if let i = meals.firstIndex(where: { $0.date == date && $0.slot == slot }) {
            meals[i] = saved
        } else {
            meals.append(saved)
        }
        return saved
    }
}
