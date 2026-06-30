import Foundation

/// Repas planifié d'un camp (table `meals`). Une ligne par (camp, date, créneau).
public struct Meal: Codable, Identifiable, Hashable {
    public let id: String
    public var campId: String
    public var date: String        // "yyyy-MM-dd"
    public var slot: MealSlot
    public var title: String?
    public var notes: String?

    public init(
        id: String,
        campId: String,
        date: String,
        slot: MealSlot,
        title: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.campId = campId
        self.date = date
        self.slot = slot
        self.title = title
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case date, slot, title, notes
    }
}

/// Lien repas <-> recette (table `meal_recipes`). Le branchement UI arrive en Task O.
public struct MealRecipe: Codable, Hashable {
    public var mealId: String
    public var recipeId: String

    public init(mealId: String, recipeId: String) {
        self.mealId = mealId
        self.recipeId = recipeId
    }

    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case recipeId = "recipe_id"
    }
}
