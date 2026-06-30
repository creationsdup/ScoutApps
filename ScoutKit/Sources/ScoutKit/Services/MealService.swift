import Foundation
import Supabase

/// Accès aux repas d'un camp (table `meals`).
public struct MealService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    public func list(campId: String) async throws -> [Meal] {
        try await client.from("meals")
            .select().eq("camp_id", value: campId)
            .order("date").execute().value
    }

    @discardableResult
    public func upsert(_ meal: Meal) async throws -> Meal {
        try await client.from("meals")
            .upsert(meal, onConflict: "camp_id,date,slot")
            .select().single().execute().value
    }

    public func delete(id: String) async throws {
        try await client.from("meals").delete().eq("id", value: id).execute()
    }
}
