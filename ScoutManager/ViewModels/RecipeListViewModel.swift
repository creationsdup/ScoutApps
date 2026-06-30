import Foundation

@MainActor
final class RecipeListViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var branchFilter: Branch?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = RecipeService()

    var filtered: [Recipe] {
        guard let b = branchFilter else { return recipes }
        return recipes.filter { $0.branch == b }
    }

    func load() async {
        isLoading = true; errorMessage = nil
        do { recipes = try await service.list() }
        catch { errorMessage = "Impossible de charger les recettes."; recipes = [] }
        isLoading = false
    }

    func delete(_ recipe: Recipe) async {
        do { try await service.delete(id: recipe.id); recipes.removeAll { $0.id == recipe.id } }
        catch { errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }
}
