import Foundation
import ScoutKit
import SwiftUI

@MainActor
final class MaterialFormViewModel: ObservableObject {
    @Published var name = ""
    @Published var inventoryCode = ""
    @Published var itemDescription = ""
    @Published var categoryId: String?
    @Published var subcategoryId: String?
    @Published var subcategories: [Subcategory] = []
    @Published var locationId: String?
    @Published var trackingType: TrackingType = .specifique
    @Published var quantity = 1
    @Published var status: ItemStatus = .disponible
    @Published var condition: ItemCondition = .good
    @Published var branch: Branch?
    @Published var notes = ""
    @Published var minimumThreshold = 0   // 0 = pas de seuil
    @Published var unit: ItemUnit = .piece

    @Published var categories: [ItemCategory] = []
    @Published var locations: [ItemLocation] = []
    @Published var pickedImageData: Data?
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let service = ItemService()
    private let storage = ImageStorageService()
    private let editingItemId: String?
    private var existingImagePath: String?
    private var existingQuantityAvailable: Int?

    var isEditing: Bool { editingItemId != nil }
    var title: String { isEditing ? "Modifier" : "Nouveau matériel" }

    init(item: Item?) {
        if let item {
            editingItemId = item.id
            existingImagePath = item.imagePath
            existingQuantityAvailable = item.quantityAvailable
            name = item.name
            inventoryCode = item.inventoryCode
            itemDescription = item.description ?? ""
            categoryId = item.categoryId
            subcategoryId = item.subcategoryId
            locationId = item.locationId
            trackingType = item.trackingType
            quantity = item.quantity
            status = item.status
            condition = item.condition
            branch = item.branch
            notes = item.notes ?? ""
            minimumThreshold = item.minimumThreshold ?? 0
            unit = item.unit ?? .piece
        } else {
            editingItemId = nil
        }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        categoryId != nil && !isSaving
    }

    /// Sous-catégories rattachées à la catégorie sélectionnée.
    var filteredSubcategories: [Subcategory] {
        guard let categoryId else { return [] }
        return subcategories.filter { $0.categoryId == categoryId }
    }

    /// URL publique de l'image déjà enregistrée (édition), pour l'aperçu. nil si aucune.
    var existingImageURL: URL? {
        guard let existingImagePath else { return nil }
        return try? ImageStorageService().publicURL(for: existingImagePath)
    }

    /// Déplier « Plus d'options » à l'ouverture ? (édition avec au moins un champ avancé renseigné)
    var shouldExpandAdvanced: Bool {
        guard isEditing else { return false }
        return !itemDescription.isEmpty
            || locationId != nil
            || branch != nil
            || condition != .good
            || (trackingType == .global && (minimumThreshold > 0 || unit != .piece))
            || !notes.isEmpty
    }

    func loadReferentials() async {
        let cats = try? await service.listCategories()
        let locs = try? await service.listLocations()
        let subs = try? await service.listSubcategories()
        categories = cats ?? []
        locations = locs ?? []
        subcategories = subs ?? []
        if cats == nil && locs == nil {
            errorMessage = "Impossible de charger catégories/localisations."
        }
    }

    /// Retourne true si la sauvegarde a réussi.
    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let id = editingItemId ?? UUID().uuidString
            guard let categoryId else {
                errorMessage = "Choisis une catégorie."
                return false
            }
            // En création, le code est généré automatiquement (PRÉFIXE-NNNN).
            // En édition, on conserve le code existant.
            let code: String
            if isEditing {
                code = inventoryCode
            } else {
                code = try await service.nextInventoryCode(categoryId: categoryId)
            }
            var imagePath = existingImagePath
            if let data = pickedImageData {
                imagePath = try await storage.upload(data, path: "items/\(id).jpg")
            }
            let item = Item(
                id: id,
                inventoryCode: code,
                name: name,
                description: itemDescription.isEmpty ? nil : itemDescription,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                locationId: locationId,
                trackingType: trackingType,
                quantity: quantity,
                quantityAvailable: isEditing ? min(existingQuantityAvailable ?? quantity, quantity) : quantity,
                status: status,
                condition: condition,
                branch: branch,
                eventId: nil,
                imagePath: imagePath,
                notes: notes.isEmpty ? nil : notes,
                lastCheckedAt: nil,
                minimumThreshold: trackingType == .global && minimumThreshold > 0 ? minimumThreshold : nil,
                unit: trackingType == .global ? unit : nil
            )
            if isEditing {
                try await service.update(item)
            } else {
                _ = try await service.create(item)
            }
            return true
        } catch {
            errorMessage = "Échec de l'enregistrement. Réessaie."
            return false
        }
    }
}
