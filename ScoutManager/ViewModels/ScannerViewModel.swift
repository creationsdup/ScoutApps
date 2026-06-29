import Foundation

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

    private let qrService = QRCodeService()
    private let itemService = ItemService()

    func resolve(_ raw: String) async -> ScanResolution {
        guard let code = TagCode.parse(raw) else {
            return .invalid("Code invalide. Format attendu : TAG-000001.")
        }
        isResolving = true
        defer { isResolving = false }
        do {
            guard let tag = try await qrService.tag(byCode: code) else {
                return .unknown("QR inconnu. Génère d'abord le lot depuis le web.")
            }
            switch tag.status {
            case .assigned:
                guard let itemId = tag.assignedItemId,
                      let item = try await itemService.get(id: itemId) else {
                    return .unknown("Objet associé introuvable.")
                }
                return .item(item)
            case .unassigned:
                return .unassigned("QR vierge. Associe-le à un objet (bientôt depuis l'app).")
            case .disabled:
                return .disabled("QR désactivé. Remplace l'étiquette.")
            }
        } catch {
            return .invalid("Erreur de lecture. Réessaie.")
        }
    }
}
