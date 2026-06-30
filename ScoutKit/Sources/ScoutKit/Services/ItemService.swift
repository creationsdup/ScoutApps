import Foundation
import Supabase

/// Accès au matériel (table inventory_items) + référentiels categories/locations.
public struct ItemService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Archive update payload

    private struct ArchivePayload: Encodable {
        let status: String
    }

    // MARK: - Items

    /// Liste filtrée. Exclut l'archivé par défaut.
    public func list(search: String? = nil,
              status: ItemStatus? = nil,
              categoryId: String? = nil,
              locationId: String? = nil,
              includeArchived: Bool = false) async throws -> [Item] {
        var query = client.from("inventory_items").select()
        if !includeArchived { query = query.neq("status", value: ItemStatus.archive.rawValue) }
        if let status { query = query.eq("status", value: status.rawValue) }
        if let categoryId { query = query.eq("category_id", value: categoryId) }
        if let locationId { query = query.eq("location_id", value: locationId) }
        if let search, !search.isEmpty { query = query.ilike("name", value: "%\(search)%") }
        return try await query.order("inventory_code").execute().value
    }

    public func get(id: String) async throws -> Item? {
        let rows: [Item] = try await client.from("inventory_items")
            .select().eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    @discardableResult
    public func create(_ item: Item) async throws -> Item {
        try await client.from("inventory_items")
            .insert(item).select().single().execute().value
    }

    public func update(_ item: Item) async throws {
        try await client.from("inventory_items")
            .update(item).eq("id", value: item.id).execute()
    }

    public func archive(id: String) async throws {
        let payload = ArchivePayload(status: ItemStatus.archive.rawValue)
        try await client.from("inventory_items")
            .update(payload).eq("id", value: id).execute()
    }

    // MARK: - Referentials

    public func listCategories() async throws -> [ItemCategory] {
        try await client.from("categories").select().order("name").execute().value
    }

    public func listLocations() async throws -> [ItemLocation] {
        try await client.from("locations").select().order("name").execute().value
    }
}
