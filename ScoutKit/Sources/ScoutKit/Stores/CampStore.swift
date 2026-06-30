import Foundation
import SwiftUI

/// État global du camp sélectionné, partagé par Intendance et Programme.
/// L'id sélectionné est persisté (UserDefaults) pour survivre au relancement.
@MainActor
public final class CampStore: ObservableObject {
    @Published public var camps: [Camp] = []
    @Published public var selectedCampID: String? {
        didSet { UserDefaults.standard.set(selectedCampID, forKey: Self.key) }
    }
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private static let key = "selectedCampID"
    private let service = CampService()

    public init() {
        selectedCampID = UserDefaults.standard.string(forKey: Self.key)
    }

    public var selectedCamp: Camp? { camps.first { $0.id == selectedCampID } }

    public func load() async {
        isLoading = true
        errorMessage = nil
        do {
            camps = try await service.list()
            // Si la sélection persistée n'existe plus, retombe sur le premier camp.
            if selectedCamp == nil { selectedCampID = camps.first?.id }
        } catch {
            errorMessage = "Impossible de charger les camps."
        }
        isLoading = false
    }

    /// Crée un camp et le sélectionne. Erreur propagée à l'appelant (à afficher).
    public func create(_ camp: Camp) async throws {
        let created = try await service.create(camp)
        camps.insert(created, at: 0)
        selectedCampID = created.id
    }

    public func update(_ camp: Camp) async throws {
        try await service.update(camp)
        if let i = camps.firstIndex(where: { $0.id == camp.id }) { camps[i] = camp }
    }

    public func delete(_ camp: Camp) async throws {
        try await service.delete(id: camp.id)
        camps.removeAll { $0.id == camp.id }
        if selectedCampID == camp.id { selectedCampID = camps.first?.id }
    }
}
