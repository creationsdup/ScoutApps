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

    private struct StockPayload: Encodable {
        let quantity: Int
        let quantity_available: Int
    }

    private struct LastCheckedPayload: Encodable { let last_checked_at: String }

    // MARK: - Items

    /// Liste filtrée. Exclut l'archivé par défaut.
    public func list(search: String? = nil,
              status: ItemStatus? = nil,
              categoryId: String? = nil,
              subcategoryId: String? = nil,
              locationId: String? = nil,
              includeArchived: Bool = false) async throws -> [Item] {
        var query = client.from("inventory_items").select()
        if !includeArchived { query = query.neq("status", value: ItemStatus.archive.rawValue) }
        if let status { query = query.eq("status", value: status.rawValue) }
        if let categoryId { query = query.eq("category_id", value: categoryId) }
        if let subcategoryId { query = query.eq("subcategory_id", value: subcategoryId) }
        if let locationId { query = query.eq("location_id", value: locationId) }
        if let search, !search.isEmpty { query = query.ilike("name", value: "%\(search)%") }
        return try await query.order("inventory_code").execute().value
    }

    public func get(id: String) async throws -> Item? {
        let rows: [Item] = try await client.from("inventory_items")
            .select().eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    /// Recherche un matériel par son code inventaire (= code scanné). Insensible à la casse via match exact uppercase.
    public func item(byCode code: String) async throws -> Item? {
        let rows: [Item] = try await client.from("inventory_items")
            .select().eq("inventory_code", value: code).limit(1).execute().value
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

    /// Ajuste le stock total d'un matériel global. Le disponible suit le même delta,
    /// borné à [0, total]. Enregistre un mouvement d'ajustement. Le statut est inchangé.
    @discardableResult
    public func adjustStock(itemId: String, delta: Int, note: String?) async throws -> Item {
        guard let item = try await get(id: itemId) else {
            throw NSError(domain: "ScoutManager", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Matériel introuvable."])
        }
        let newTotal = max(0, item.quantity + delta)
        let currentAvailable = item.quantityAvailable ?? item.quantity
        let newAvailable = min(max(0, currentAvailable + delta), newTotal)
        try await client.from("inventory_items")
            .update(StockPayload(quantity: newTotal, quantity_available: newAvailable))
            .eq("id", value: itemId)
            .execute()
        try await MovementService().recordAdjustment(itemId: itemId, quantity: delta, note: note)
        var updated = item
        updated.quantity = newTotal
        updated.quantityAvailable = newAvailable
        return updated
    }

    /// Marque une liste d'objets comme inventoriés (last_checked_at = maintenant).
    /// No-op si la liste est vide. Écrit une colonne existante additive.
    public func markChecked(itemIds: [String]) async throws {
        guard !itemIds.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("inventory_items")
            .update(LastCheckedPayload(last_checked_at: now))
            .`in`("id", values: itemIds)
            .execute()
    }

    // MARK: - Referentials

    public func listCategories() async throws -> [ItemCategory] {
        try await client.from("categories").select().order("name").execute().value
    }

    public func listLocations() async throws -> [ItemLocation] {
        try await client.from("locations").select().order("name").execute().value
    }

    public func listSubcategories() async throws -> [Subcategory] {
        try await client.from("subcategories").select().order("name").execute().value
    }

    /// Génère le prochain code inventaire pour une catégorie (RPC atomique). Ex. "TEN-0001".
    public func nextInventoryCode(categoryId: String) async throws -> String {
        try await client.rpc("next_inventory_code",
                             params: ["p_category_id": categoryId]).execute().value
    }
}
