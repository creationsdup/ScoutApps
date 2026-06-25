import Foundation
import SwiftUI

/// État global de l'app : session, rôle, et façade vers le service Supabase.
@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var role: UserRole?
    @Published var errorMessage: String?
    @Published var events: [Event] = []
    @Published var selectedEvent: Event?

    private let service = SupabaseService()

    var canWrite: Bool { role?.canWrite ?? false }

    func login(email: String, password: String) async {
        errorMessage = nil
        do {
            try await service.login(email: email, password: password)
            isAuthenticated = service.isAuthenticated
            role = try await service.getCurrentUserRole()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        service.logout()
        isAuthenticated = false
        role = nil
        events = []
        selectedEvent = nil
    }

    func loadEvents() async {
        events = (try? await service.listEvents()) ?? []
    }

    func loadItems() async -> [InventoryItem] {
        (try? await service.listItems()) ?? []
    }

    func createEvent(name: String, startDate: String, endDate: String) async -> Bool {
        do {
            _ = try await service.createEvent(name: name, startDate: startDate, endDate: endDate)
            await loadEvents()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func resolveTag(_ rawCode: String) async -> TagResolution {
        guard let parsed = TagCode.parse(rawCode) else {
            return .invalid("Code invalide. Format attendu : TAG-000001.")
        }
        do {
            guard let tag = try await service.getTagByCode(parsed) else {
                return .unknown("QR inconnu. Génère d'abord le lot depuis le web.")
            }
            switch tag.status {
            case .assigned:
                guard let itemId = tag.assignedItemId,
                      let item = try await service.getItemById(itemId) else {
                    return .unknown("Objet associé introuvable.")
                }
                return .item(item)
            case .unassigned:
                return .unassigned("QR vierge. Associe-le à un objet depuis le web.")
            case .disabled:
                return .disabled("QR désactivé. Remplace l'étiquette.")
            }
        } catch {
            return .invalid(error.localizedDescription)
        }
    }

    func runMovement(on item: InventoryItem, action: MovementAction) async -> Result<ItemStatus, AppError> {
        guard canWrite else {
            return .failure(AppError("Lecture seule — ton rôle ne permet pas d'agir."))
        }
        do {
            try await service.createMovement(itemId: item.id, action: action, eventId: selectedEvent?.id)
            return .success(MovementStatusMapping.nextStatus(for: action))
        } catch {
            return .failure(AppError(error.localizedDescription))
        }
    }
}

/// Erreur applicative porteuse d'un message affichable.
struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum TagResolution {
    case item(InventoryItem)
    case unassigned(String)
    case disabled(String)
    case unknown(String)
    case invalid(String)
}
