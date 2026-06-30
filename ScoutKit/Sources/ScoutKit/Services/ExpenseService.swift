import Foundation
import Supabase

/// Dépenses d'un camp (table `expenses`).
struct ExpenseService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func list(campId: String) async throws -> [Expense] {
        try await client.from("expenses")
            .select().eq("camp_id", value: campId)
            .order("created_at").execute().value
    }

    @discardableResult
    func create(_ expense: Expense) async throws -> Expense {
        try await client.from("expenses").insert(expense).select().single().execute().value
    }

    func update(_ expense: Expense) async throws {
        try await client.from("expenses").update(expense).eq("id", value: expense.id).execute()
    }

    func delete(id: String) async throws {
        try await client.from("expenses").delete().eq("id", value: id).execute()
    }
}
