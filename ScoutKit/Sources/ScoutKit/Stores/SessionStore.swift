import Foundation
import SwiftUI

/// État de session global : authentification, rôle, erreurs.
@MainActor
final class SessionStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var role: UserRole?
    @Published var errorMessage: String?

    private let service = SupabaseService.shared

    var canWrite: Bool { role?.canWrite ?? false }

    /// Restaure une session persistée au lancement.
    func restore() async {
        if await service.currentSession() != nil {
            isAuthenticated = true
            role = try? await service.currentUserRole()
        }
    }

    func login(email: String, password: String) async {
        errorMessage = nil
        do {
            try await service.signIn(email: email, password: password)
        } catch {
            // Échec de l'authentification elle-même (identifiants).
            errorMessage = "Connexion refusée. Vérifie l'email et le mot de passe."
            isAuthenticated = false
            return
        }
        // Auth réussie : on est connecté même si la lecture du rôle échoue
        // (fallback lecture seule via canWrite == false).
        isAuthenticated = true
        role = try? await service.currentUserRole()
    }

    func logout() async {
        try? await service.signOut()
        isAuthenticated = false
        role = nil
    }
}
