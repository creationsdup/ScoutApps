import Foundation
import Supabase

/// Accès à la bibliothèque de recettes (recipes + recipe_ingredients) et au lien
/// repas↔recettes (meal_recipes).
public struct RecipeService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: Recipes
    public func list() async throws -> [Recipe] {
        try await client.from("recipes").select().order("name").execute().value
    }

    public func get(id: String) async throws -> Recipe? {
        let rows: [Recipe] = try await client.from("recipes")
            .select().eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    @discardableResult
    public func create(_ recipe: Recipe) async throws -> Recipe {
        try await client.from("recipes").insert(recipe).select().single().execute().value
    }

    public func update(_ recipe: Recipe) async throws {
        try await client.from("recipes").update(recipe).eq("id", value: recipe.id).execute()
    }

    public func delete(id: String) async throws {
        try await client.from("recipes").delete().eq("id", value: id).execute()
    }

    // MARK: Ingredients
    public func ingredients(recipeId: String) async throws -> [RecipeIngredient] {
        try await client.from("recipe_ingredients")
            .select().eq("recipe_id", value: recipeId)
            .order("created_at").execute().value
    }

    /// Remplace tous les ingrédients d'une recette par la liste fournie.
    public func replaceIngredients(recipeId: String, with items: [RecipeIngredient]) async throws {
        try await client.from("recipe_ingredients").delete().eq("recipe_id", value: recipeId).execute()
        if !items.isEmpty {
            try await client.from("recipe_ingredients").insert(items).execute()
        }
    }

    // MARK: Meal <-> recipes link (table meal_recipes)
    public func recipeIds(mealId: String) async throws -> [String] {
        struct Row: Decodable { let recipe_id: String }
        let rows: [Row] = try await client.from("meal_recipes")
            .select("recipe_id").eq("meal_id", value: mealId).execute().value
        return rows.map(\.recipe_id)
    }

    /// Remplace les recettes liées à un repas par l'ensemble fourni.
    public func setRecipes(mealId: String, recipeIds: [String]) async throws {
        struct Link: Encodable { let meal_id: String; let recipe_id: String }
        try await client.from("meal_recipes").delete().eq("meal_id", value: mealId).execute()
        if !recipeIds.isEmpty {
            let links = recipeIds.map { Link(meal_id: mealId, recipe_id: $0) }
            try await client.from("meal_recipes").insert(links).execute()
        }
    }
}
