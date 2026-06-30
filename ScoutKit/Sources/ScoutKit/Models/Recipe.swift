import Foundation

/// Recette de la bibliothèque (table `recipes`). Non liée à un camp.
struct Recipe: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var servingsBase: Int
    var instructions: String?
    var branch: Branch?

    enum CodingKeys: String, CodingKey {
        case id, name
        case servingsBase = "servings_base"
        case instructions, branch
    }
}

/// Ingrédient d'une recette (table `recipe_ingredients`).
struct RecipeIngredient: Codable, Identifiable, Hashable {
    let id: String
    var recipeId: String
    var name: String
    var quantity: Double?
    var unit: String?

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case name, quantity, unit
    }
}
