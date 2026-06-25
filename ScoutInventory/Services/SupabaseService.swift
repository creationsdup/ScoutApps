import Foundation

enum ServiceError: LocalizedError {
    case notConfigured
    case http(Int, String)
    case decoding(String)
    case auth(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Clé Supabase manquante. Renseigne Config.supabaseAnonKey."
        case .http(let code, let message):
            return "Erreur réseau (\(code)) : \(message)"
        case .decoding(let detail):
            return "Réponse inattendue : \(detail)"
        case .auth(let message):
            return message
        }
    }
}

/// Accès Supabase via REST (PostgREST) + Auth (GoTrue), sans dépendance externe.
/// Toute écriture du parcours cœur passe par cette couche (un seul point de contact).
final class SupabaseService {
    private let baseURL = Config.supabaseURL
    private let anonKey = Config.supabaseAnonKey
    private let session = URLSession(configuration: .default)

    private(set) var accessToken: String?
    private(set) var userId: String?

    var isAuthenticated: Bool { accessToken != nil }

    // MARK: - Auth

    private struct LoginResponse: Decodable {
        let accessToken: String
        let user: AuthUser
        struct AuthUser: Decodable { let id: String }
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case user
        }
    }

    func login(email: String, password: String) async throws {
        guard Config.isConfigured else { throw ServiceError.notConfigured }

        var request = URLRequest(url: baseURL.appendingPathComponent("auth/v1/token"))
        request.url?.append(queryItems: [URLQueryItem(name: "grant_type", value: "password")])
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            throw ServiceError.auth("Connexion refusée. Vérifie l'email et le mot de passe.")
        }
        do {
            let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
            accessToken = decoded.accessToken
            userId = decoded.user.id
        } catch {
            throw ServiceError.decoding("login: \(error.localizedDescription)")
        }
    }

    func logout() {
        accessToken = nil
        userId = nil
    }

    // MARK: - REST helpers

    private func restRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        preferMinimal: Bool = false
    ) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("rest/v1/\(path)"))
        if !queryItems.isEmpty { request.url?.append(queryItems: queryItems) }
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if preferMinimal {
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let message = String(data: data, encoding: .utf8) ?? "—"
            throw ServiceError.http(code, message)
        }
        return data
    }

    private func decodeList<T: Decodable>(_ data: Data, as type: T.Type) throws -> [T] {
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            throw ServiceError.decoding("\(T.self): \(error.localizedDescription)")
        }
    }

    // MARK: - Lectures

    func getTagByCode(_ tagCode: String) async throws -> QrTag? {
        let request = restRequest(path: "qr_tags", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "tag_code", value: "eq.\(tagCode)")
        ])
        let data = try await send(request)
        return try decodeList(data, as: QrTag.self).first
    }

    func getItemById(_ id: String) async throws -> InventoryItem? {
        let request = restRequest(path: "inventory_items", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "eq.\(id)")
        ])
        let data = try await send(request)
        return try decodeList(data, as: InventoryItem.self).first
    }

    private struct RoleRow: Decodable { let role: UserRole }

    func getCurrentUserRole() async throws -> UserRole? {
        guard let userId else { return nil }
        let request = restRequest(path: "profiles", queryItems: [
            URLQueryItem(name: "select", value: "role"),
            URLQueryItem(name: "id", value: "eq.\(userId)")
        ])
        let data = try await send(request)
        return try decodeList(data, as: RoleRow.self).first?.role
    }

    // MARK: - Écriture cœur

    /// Enregistre un mouvement. Pour un rejeu sûr (idempotence), on met à jour
    /// le statut (idempotent) AVANT d'insérer le mouvement (journal append).
    func createMovement(itemId: String, action: MovementAction) async throws {
        guard let userId else { throw ServiceError.auth("Utilisateur non authentifié.") }

        let nextStatus = MovementStatusMapping.nextStatus(for: action)
        let statusBody = try JSONEncoder().encode(["status": nextStatus.rawValue])
        let statusRequest = restRequest(
            path: "inventory_items",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(itemId)")],
            body: statusBody,
            preferMinimal: true
        )
        _ = try await send(statusRequest)

        let movementBody = try JSONEncoder().encode([
            "item_id": itemId,
            "action": action.rawValue,
            "user_id": userId
        ])
        let movementRequest = restRequest(
            path: "item_movements",
            method: "POST",
            body: movementBody,
            preferMinimal: true
        )
        _ = try await send(movementRequest)
    }
}
