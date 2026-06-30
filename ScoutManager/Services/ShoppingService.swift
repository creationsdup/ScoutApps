import Foundation
import Supabase

/// Liste de courses d'un camp (table `shopping_items`) + génération depuis les menus.
struct ShoppingService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func list(campId: String) async throws -> [ShoppingItem] {
        try await client.from("shopping_items")
            .select().eq("camp_id", value: campId)
            .order("checked").order("name").execute().value
    }

    @discardableResult
    func add(_ item: ShoppingItem) async throws -> ShoppingItem {
        try await client.from("shopping_items").insert(item).select().single().execute().value
    }

    func update(_ item: ShoppingItem) async throws {
        try await client.from("shopping_items").update(item).eq("id", value: item.id).execute()
    }

    func delete(id: String) async throws {
        try await client.from("shopping_items").delete().eq("id", value: id).execute()
    }

    /// Régénère les lignes `auto` du camp depuis les menus. Préserve les lignes `manual`.
    /// `participants` : effectif du camp (défaut 1 si non renseigné).
    func regenerateAuto(campId: String, participants: Int) async throws {
        // 1. Récupère les liens repas->recette du camp.
        struct MealIdRow: Decodable { let id: String }
        let meals: [MealIdRow] = try await client.from("meals")
            .select("id").eq("camp_id", value: campId).execute().value
        let mealIds = meals.map(\.id)

        var recipeIdsPerOccurrence: [String] = []   // un élément par (repas×recette)
        if !mealIds.isEmpty {
            struct LinkRow: Decodable { let recipe_id: String }
            let links: [LinkRow] = try await client.from("meal_recipes")
                .select("recipe_id").in("meal_id", values: mealIds).execute().value
            recipeIdsPerOccurrence = links.map(\.recipe_id)
        }

        // 2. Charge recettes (servings_base) + ingrédients pour les recettes utilisées.
        let usedRecipeIds = Array(Set(recipeIdsPerOccurrence))
        var servingsByRecipe: [String: Int] = [:]
        var ingredientsByRecipe: [String: [RecipeIngredient]] = [:]
        if !usedRecipeIds.isEmpty {
            let recipes: [Recipe] = try await client.from("recipes")
                .select().in("id", values: usedRecipeIds).execute().value
            for r in recipes { servingsByRecipe[r.id] = max(1, r.servingsBase) }

            let ingredients: [RecipeIngredient] = try await client.from("recipe_ingredients")
                .select().in("recipe_id", values: usedRecipeIds).execute().value
            for ing in ingredients { ingredientsByRecipe[ing.recipeId, default: []].append(ing) }
        }

        // 3. Agrège par (nom normalisé, unité). Quantité = somme sur occurrences de
        //    ingredient.quantity * ceil(participants / servings_base).
        struct Key: Hashable { let name: String; let unit: String? }
        var agg: [Key: (display: String, unit: String?, qty: Double, anyQty: Bool)] = [:]
        for recipeId in recipeIdsPerOccurrence {
            let servings = servingsByRecipe[recipeId] ?? 1
            let factor = Double(Int(ceil(Double(participants) / Double(servings))))
            for ing in ingredientsByRecipe[recipeId] ?? [] {
                let key = Key(name: ing.name.lowercased(), unit: ing.unit)
                var entry = agg[key] ?? (display: ing.name, unit: ing.unit, qty: 0, anyQty: false)
                if let q = ing.quantity { entry.qty += q * factor; entry.anyQty = true }
                agg[key] = entry
            }
        }

        // 4. Remplace les lignes auto : delete puis insert.
        try await client.from("shopping_items")
            .delete().eq("camp_id", value: campId).eq("source", value: ShoppingSource.auto.rawValue)
            .execute()
        let rows = agg.values.map { v in
            ShoppingItem(id: UUID().uuidString, campId: campId,
                         name: v.display, quantity: v.anyQty ? v.qty : nil,
                         unit: v.unit, checked: false, source: .auto)
        }
        if !rows.isEmpty {
            try await client.from("shopping_items").insert(rows).execute()
        }
    }
}
