import Foundation

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    @Published var ingredients: [RecipeIngredient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = RecipeService()

    func load(recipeId: String) async {
        isLoading = true; errorMessage = nil
        do { ingredients = try await service.ingredients(recipeId: recipeId) }
        catch { errorMessage = "Impossible de charger les ingrédients." }
        isLoading = false
    }

    /// Récupère une recette par son id (via la liste complète).
    func get(id: String) async -> Recipe? {
        try? await service.list().first(where: { $0.id == id })
    }
}
