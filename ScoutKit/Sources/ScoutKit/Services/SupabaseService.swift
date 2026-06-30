import Foundation
import Supabase

/// Point d'accès unique au backend Supabase via le SDK officiel.
/// Toute la couche réseau passe par ce client (auth, PostgREST, Storage).
final class SupabaseService {
    static let shared = SupabaseService()
    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: Auth

    @discardableResult
    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws { try await client.auth.signOut() }

    /// Session persistée au lancement (nil si pas de session).
    func currentSession() async -> Session? {
        try? await client.auth.session
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    // MARK: Rôle

    private struct RoleRow: Decodable { let role: UserRole }

    func currentUserRole() async throws -> UserRole? {
        guard let uid = currentUserID else { return nil }
        let rows: [RoleRow] = try await client
            .from("profiles")
            .select("role")
            .eq("id", value: uid)
            .execute()
            .value
        return rows.first?.role
    }
}
