import Foundation

/// Repas planifié d'un camp (table `meals`). Une ligne par (camp, date, créneau).
struct Meal: Codable, Identifiable, Hashable {
    let id: String
    var campId: String
    var date: String        // "yyyy-MM-dd"
    var slot: MealSlot
    var title: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case date, slot, title, notes
    }
}

/// Lien repas <-> recette (table `meal_recipes`). Le branchement UI arrive en Task O.
struct MealRecipe: Codable, Hashable {
    var mealId: String
    var recipeId: String
    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case recipeId = "recipe_id"
    }
}
