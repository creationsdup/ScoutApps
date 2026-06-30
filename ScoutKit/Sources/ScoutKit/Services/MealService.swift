import Foundation
import Supabase

/// Accès aux repas d'un camp (table `meals`).
struct MealService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func list(campId: String) async throws -> [Meal] {
        try await client.from("meals")
            .select().eq("camp_id", value: campId)
            .order("date").execute().value
    }

    @discardableResult
    func upsert(_ meal: Meal) async throws -> Meal {
        try await client.from("meals")
            .upsert(meal, onConflict: "camp_id,date,slot")
            .select().single().execute().value
    }

    func delete(id: String) async throws {
        try await client.from("meals").delete().eq("id", value: id).execute()
    }
}
