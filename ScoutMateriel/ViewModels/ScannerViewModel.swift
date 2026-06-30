import Foundation
import ScoutKit

enum ScanResolution {
    case item(Item)
    case unassigned(String)
    case disabled(String)
    case unknown(String)
    case invalid(String)
}

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published var isResolving = false

    private let itemService = ItemService()

    func resolve(_ raw: String) async -> ScanResolution {
        guard let code = TagCode.parse(raw) else {
            return .invalid("Code invalide. Format attendu : TEN-0001.")
        }
        isResolving = true
        defer { isResolving = false }
        do {
            guard let item = try await itemService.item(byCode: code) else {
                return .unknown("Code inconnu. Aucun matériel ne porte ce code.")
            }
            return .item(item)
        } catch {
            return .invalid("Erreur de lecture. Réessaie.")
        }
    }
}
