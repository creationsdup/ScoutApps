import Foundation

/// Ligne d'ingrédient éditable dans le formulaire.
struct IngredientDraft: Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    var quantityStr: String = ""   // proxy String pour Double?
    var unit: String = ""
}

@MainActor
final class RecipeFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var servingsBase: Int = 1
    @Published var instructions: String = ""
    @Published var branch: Branch? = nil
    @Published var drafts: [IngredientDraft] = []
    @Published var errorMessage: String?
    @Published var isSaving = false

    private let service = RecipeService()
    private let existingRecipe: Recipe?

    var title: String { existingRecipe == nil ? "Nouvelle recette" : "Modifier" }

    init(recipe: Recipe?) {
        self.existingRecipe = recipe
        if let r = recipe {
            name = r.name
            servingsBase = r.servingsBase
            instructions = r.instructions ?? ""
            branch = r.branch
        }
    }

    /// Charge les ingrédients existants (mode édition).
    func load() async {
        guard let r = existingRecipe else { return }
        do {
            let ings = try await service.ingredients(recipeId: r.id)
            drafts = ings.map { ing in
                var d = IngredientDraft()
                d.id = ing.id
                d.name = ing.name
                d.quantityStr = ing.quantity.map { formatQty($0) } ?? ""
                d.unit = ing.unit ?? ""
                return d
            }
        } catch {
            errorMessage = "Impossible de charger les ingrédients."
        }
    }

    func addIngredient() {
        drafts.append(IngredientDraft())
    }

    func removeIngredient(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    /// Enregistre la recette et ses ingrédients. Propage l'erreur à l'appelant.
    func save() async throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Le nom de la recette est obligatoire."
            throw ValidationError.emptyName
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let recipeId = existingRecipe?.id ?? UUID().uuidString
        let recipe = Recipe(
            id: recipeId,
            name: name.trimmingCharacters(in: .whitespaces),
            servingsBase: servingsBase,
            instructions: instructions.isEmpty ? nil : instructions,
            branch: branch
        )

        if existingRecipe == nil {
            try await service.create(recipe)
        } else {
            try await service.update(recipe)
        }

        // Convertit les drafts en ingrédients (ignore les lignes sans nom)
        let ingredients: [RecipeIngredient] = drafts
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { d in
                RecipeIngredient(
                    id: d.id,
                    recipeId: recipeId,
                    name: d.name.trimmingCharacters(in: .whitespaces),
                    quantity: Double(d.quantityStr),
                    unit: d.unit.isEmpty ? nil : d.unit
                )
            }
        try await service.replaceIngredients(recipeId: recipeId, with: ingredients)
    }

    private func formatQty(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }

    enum ValidationError: Error { case emptyName }
}
