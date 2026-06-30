import Foundation
import Supabase

/// Upload / URL des images de matériel dans le bucket Storage `item-images`.
public struct ImageStorageService {
    public init() {}

    private let bucket = "item-images"
    private var storage: SupabaseStorageClient { SupabaseService.shared.client.storage }

    /// Téléverse des données image et retourne le chemin stocké (image_path).
    @discardableResult
    public func upload(_ data: Data, path: String, contentType: String = "image/jpeg") async throws -> String {
        _ = try await storage.from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: contentType, upsert: true))
        return path
    }

    /// URL publique d'une image stockée.
    public func publicURL(for path: String) throws -> URL {
        try storage.from(bucket).getPublicURL(path: path)
    }
}
