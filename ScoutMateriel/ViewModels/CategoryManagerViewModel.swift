import Foundation
import ScoutKit

@MainActor
final class CategoryManagerViewModel: ObservableObject {
    @Published var categories: [ItemCategory] = []
    @Published var allSubcategories: [Subcategory] = []
    @Published var itemCounts: [String: Int] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let itemService = ItemService()
    private let service = CategoryService()

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let cats = try await itemService.listCategories()
            let subs = try await itemService.listSubcategories()
            var counts: [String: Int] = [:]
            for cat in cats {
                counts[cat.id] = (try? await service.itemCount(categoryId: cat.id)) ?? 0
            }
            categories = cats
            allSubcategories = subs
            itemCounts = counts
        } catch {
            errorMessage = "Impossible de charger les catégories."
        }
        isLoading = false
    }

    func subcategories(of categoryId: String) -> [Subcategory] {
        allSubcategories.filter { $0.categoryId == categoryId }
    }

    /// Le code est modifiable tant qu'aucun item n'utilise la catégorie.
    func canEditCode(_ categoryId: String) -> Bool {
        (itemCounts[categoryId] ?? 0) == 0
    }

    // MARK: - Actions catégorie

    func createCategory(name: String, code: String) async -> Bool {
        do {
            _ = try await service.createCategory(name: name, code: code)
            await load()
            return true
        } catch {
            errorMessage = "Création impossible. Code peut-être déjà utilisé."
            return false
        }
    }

    func renameCategory(id: String, name: String, code: String?) async -> Bool {
        do {
            try await service.updateCategory(id: id, name: name, code: code)
            await load()
            return true
        } catch {
            errorMessage = "Modification impossible. Code peut-être déjà utilisé."
            return false
        }
    }

    func deleteCategory(id: String) async {
        do {
            try await service.deleteCategory(id: id)
            await load()
        } catch {
            errorMessage = "Suppression impossible. Réessaie."
        }
    }

    // MARK: - Actions sous-catégorie

    func createSubcategory(categoryId: String, name: String) async -> Bool {
        do {
            _ = try await service.createSubcategory(categoryId: categoryId, name: name)
            await load()
            return true
        } catch {
            errorMessage = "Création de la sous-catégorie impossible."
            return false
        }
    }

    func renameSubcategory(id: String, name: String) async -> Bool {
        do {
            try await service.updateSubcategory(id: id, name: name)
            await load()
            return true
        } catch {
            errorMessage = "Modification de la sous-catégorie impossible."
            return false
        }
    }

    func deleteSubcategory(id: String) async {
        do {
            try await service.deleteSubcategory(id: id)
            await load()
        } catch {
            errorMessage = "Suppression de la sous-catégorie impossible."
        }
    }
}
