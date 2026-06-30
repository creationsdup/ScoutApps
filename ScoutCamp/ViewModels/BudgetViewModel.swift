import Foundation
import ScoutKit

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ExpenseService()

    var totalPlanned: Double { expenses.compactMap(\.amountPlanned).reduce(0, +) }
    var totalReal: Double { expenses.compactMap(\.amountReal).reduce(0, +) }
    /// Écart = réel - prévu. Positif = dépassement (défavorable).
    var ecart: Double { totalReal - totalPlanned }

    func load(campId: String) async {
        isLoading = true; errorMessage = nil
        do { expenses = try await service.list(campId: campId) }
        catch { errorMessage = "Impossible de charger le budget."; expenses = [] }
        isLoading = false
    }

    func delete(_ expense: Expense) async {
        do { try await service.delete(id: expense.id); expenses.removeAll { $0.id == expense.id } }
        catch { errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }

    /// Insère ou met à jour, puis recharge en mémoire.
    func save(_ expense: Expense, isNew: Bool) async throws {
        if isNew {
            let created = try await service.create(expense)
            expenses.append(created)
        } else {
            try await service.update(expense)
            if let i = expenses.firstIndex(where: { $0.id == expense.id }) { expenses[i] = expense }
        }
    }
}
