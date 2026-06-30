import Foundation
import Supabase

/// Registre de traçabilité d'un camp (table `food_traceability`).
public struct FoodTraceService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    public func list(campId: String) async throws -> [FoodTraceEntry] {
        try await client.from("food_traceability")
            .select().eq("camp_id", value: campId)
            .order("received_date", ascending: false, nullsFirst: false)
            .execute().value
    }

    @discardableResult
    public func create(_ entry: FoodTraceEntry) async throws -> FoodTraceEntry {
        try await client.from("food_traceability").insert(entry).select().single().execute().value
    }

    public func update(_ entry: FoodTraceEntry) async throws {
        try await client.from("food_traceability").update(entry).eq("id", value: entry.id).execute()
    }

    public func delete(id: String) async throws {
        try await client.from("food_traceability").delete().eq("id", value: id).execute()
    }
}
