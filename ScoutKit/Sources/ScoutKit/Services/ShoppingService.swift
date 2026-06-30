import Foundation
import Supabase

/// Liste de courses d'un camp (table `shopping_items`) + génération depuis les menus.
public struct ShoppingService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    public func list(campId: String) async throws -> [ShoppingItem] {
        try await client.from("shopping_items")
            .select().eq("camp_id", value: campId)
            .order("checked").order("name").execute().value
    }

    @discardableResult
    public func add(_ item: ShoppingItem) async throws -> ShoppingItem {
        try await client.from("shopping_items").insert(item).select().single().execute().value
    }

    public func update(_ item: ShoppingItem) async throws {
        try await client.from("shopping_items").update(item).eq("id", value: item.id).execute()
    }

    public func delete(id: String) async throws {
        try await client.from("shopping_items").delete().eq("id", value: id).execute()
    }

    /// Régénère les lignes `auto` du camp depuis les menus, préserve les lignes `manual`.
    ///
    /// Délègue à la fonction Postgres transactionnelle `regenerate_shopping_auto`
    /// (cf. migration `20260630_scoutmanager_shopping_rpc.sql`) : l'agrégation
    /// (occurrences repas×recette × ceil(participants / servings_base), groupées
    /// par nom/unité) et le couple delete/insert s'exécutent dans une seule
    /// transaction côté serveur — atomique (plus de perte de lignes si l'insert
    /// échoue après le delete). L'effectif est lu depuis `camps.participants_count`.
    /// La RLS s'applique (`security invoker`) : un viewer reçoit une erreur.
    public func regenerateAuto(campId: String) async throws {
        try await client
            .rpc("regenerate_shopping_auto", params: ["p_camp_id": campId])
            .execute()
    }
}
