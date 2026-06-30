import Foundation

/// Recette de la bibliothèque (table `recipes`). Non liée à un camp.
public struct Recipe: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var servingsBase: Int
    public var instructions: String?
    public var branch: Branch?

    public init(
        id: String,
        name: String,
        servingsBase: Int,
        instructions: String? = nil,
        branch: Branch? = nil
    ) {
        self.id = id
        self.name = name
        self.servingsBase = servingsBase
        self.instructions = instructions
        self.branch = branch
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case servingsBase = "servings_base"
        case instructions, branch
    }
}

/// Ingrédient d'une recette (table `recipe_ingredients`).
public struct RecipeIngredient: Codable, Identifiable, Hashable {
    public let id: String
    public var recipeId: String
    public var name: String
    public var quantity: Double?
    public var unit: String?

    public init(
        id: String,
        recipeId: String,
        name: String,
        quantity: Double? = nil,
        unit: String? = nil
    ) {
        self.id = id
        self.recipeId = recipeId
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case name, quantity, unit
    }
}
