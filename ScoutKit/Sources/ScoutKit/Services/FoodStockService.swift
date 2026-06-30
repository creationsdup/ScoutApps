import Foundation
import Supabase

/// Réserve alimentaire d'un camp (table `food_stock`).
struct FoodStockService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func list(campId: String) async throws -> [FoodStockItem] {
        try await client.from("food_stock")
            .select().eq("camp_id", value: campId)
            .order("expiry_date", ascending: true, nullsFirst: false)
            .execute().value
    }

    @discardableResult
    func create(_ item: FoodStockItem) async throws -> FoodStockItem {
        try await client.from("food_stock").insert(item).select().single().execute().value
    }

    func update(_ item: FoodStockItem) async throws {
        try await client.from("food_stock").update(item).eq("id", value: item.id).execute()
    }

    func delete(id: String) async throws {
        try await client.from("food_stock").delete().eq("id", value: id).execute()
    }
}
