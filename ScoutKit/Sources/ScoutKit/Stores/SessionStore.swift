import Foundation
import SwiftUI

/// État de session global : authentification, rôle, erreurs.
@MainActor
public final class SessionStore: ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var role: UserRole?
    @Published public var errorMessage: String?

    private let service = SupabaseService.shared

    public var canWrite: Bool { role?.canWrite ?? false }

    public init() {}

    /// Restaure une session persistée au lancement.
    public func restore() async {
        if await service.currentSession() != nil {
            isAuthenticated = true
            role = try? await service.currentUserRole()
        }
    }

    public func login(email: String, password: String) async {
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

    public func logout() async {
        try? await service.signOut()
        isAuthenticated = false
        role = nil
    }
}
