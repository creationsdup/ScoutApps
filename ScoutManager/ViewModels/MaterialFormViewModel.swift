import Foundation
import SwiftUI

@MainActor
final class MaterialFormViewModel: ObservableObject {
    @Published var name = ""
    @Published var inventoryCode = ""
    @Published var itemDescription = ""
    @Published var categoryId: String?
    @Published var locationId: String?
    @Published var trackingType: TrackingType = .specifique
    @Published var quantity = 1
    @Published var status: ItemStatus = .disponible
    @Published var condition: ItemCondition = .good
    @Published var branch: Branch?
    @Published var notes = ""

    @Published var categories: [ItemCategory] = []
    @Published var locations: [ItemLocation] = []
    @Published var pickedImageData: Data?
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let service = ItemService()
    private let storage = ImageStorageService()
    private let editingItemId: String?
    private var existingImagePath: String?

    var isEditing: Bool { editingItemId != nil }
    var title: String { isEditing ? "Modifier" : "Nouveau matériel" }

    init(item: Item?) {
        if let item {
            editingItemId = item.id
            existingImagePath = item.imagePath
            name = item.name
            inventoryCode = item.inventoryCode
            itemDescription = item.description ?? ""
            categoryId = item.categoryId
            locationId = item.locationId
            trackingType = item.trackingType
            quantity = item.quantity
            status = item.status
            condition = item.condition
            branch = item.branch
            notes = item.notes ?? ""
        } else {
            editingItemId = nil
        }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !inventoryCode.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    func loadReferentials() async {
        categories = (try? await service.listCategories()) ?? []
        locations = (try? await service.listLocations()) ?? []
    }

    /// Retourne true si la sauvegarde a réussi.
    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let id = editingItemId ?? UUID().uuidString
            var imagePath = existingImagePath
            if let data = pickedImageData {
                imagePath = try await storage.upload(data, path: "items/\(id).jpg")
            }
            let item = Item(
                id: id,
                inventoryCode: inventoryCode,
                name: name,
                description: itemDescription.isEmpty ? nil : itemDescription,
                categoryId: categoryId,
                locationId: locationId,
                trackingType: trackingType,
                quantity: quantity,
                quantityAvailable: quantity,
                status: status,
                condition: condition,
                branch: branch,
                eventId: nil,
                imagePath: imagePath,
                notes: notes.isEmpty ? nil : notes,
                lastCheckedAt: nil
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
