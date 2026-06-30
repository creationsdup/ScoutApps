import Foundation
import Supabase

/// Écritures sur les référentiels de classement (categories / subcategories)
/// + comptage d'items. Les lectures vivent dans `ItemService`
/// (`listCategories` / `listSubcategories`).
public struct CategoryService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Payloads

    private struct CategoryInsert: Encodable { let name: String; let code: String }
    private struct CategoryNameCode: Encodable { let name: String; let code: String }
    private struct NameOnly: Encodable { let name: String }
    private struct SubcategoryInsert: Encodable { let category_id: String; let name: String }

    // MARK: - Catégories

    @discardableResult
    public func createCategory(name: String, code: String) async throws -> ItemCategory {
        try await client.from("categories")
            .insert(CategoryInsert(name: name, code: code))
            .select().single().execute().value
    }

    /// Met à jour le nom toujours ; le code seulement s'il est fourni (non verrouillé).
    public func updateCategory(id: String, name: String, code: String?) async throws {
        if let code {
            try await client.from("categories")
                .update(CategoryNameCode(name: name, code: code))
                .eq("id", value: id).execute()
        } else {
            try await client.from("categories")
                .update(NameOnly(name: name))
                .eq("id", value: id).execute()
        }
    }

    public func deleteCategory(id: String) async throws {
        try await client.from("categories").delete().eq("id", value: id).execute()
    }

    // MARK: - Sous-catégories

    @discardableResult
    public func createSubcategory(categoryId: String, name: String) async throws -> Subcategory {
        try await client.from("subcategories")
            .insert(SubcategoryInsert(category_id: categoryId, name: name))
            .select().single().execute().value
    }

    public func updateSubcategory(id: String, name: String) async throws {
        try await client.from("subcategories")
            .update(NameOnly(name: name))
            .eq("id", value: id).execute()
    }

    public func deleteSubcategory(id: String) async throws {
        try await client.from("subcategories").delete().eq("id", value: id).execute()
    }

    // MARK: - Comptage (règle de verrouillage du code)

    /// Nombre d'items rattachés à une catégorie (sert à verrouiller le code).
    public func itemCount(categoryId: String) async throws -> Int {
        let response = try await client.from("inventory_items")
            .select("id", head: true, count: .exact)
            .eq("category_id", value: categoryId)
            .execute()
        return response.count ?? 0
    }
}
