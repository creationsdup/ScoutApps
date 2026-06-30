import Foundation
import Supabase

/// Accès à la bibliothèque d'activités (table `activities`).
public struct ActivityService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    public func list() async throws -> [Activity] {
        try await client.from("activities").select().order("name").execute().value
    }

    @discardableResult
    public func create(_ activity: Activity) async throws -> Activity {
        try await client.from("activities").insert(activity).select().single().execute().value
    }

    public func update(_ activity: Activity) async throws {
        try await client.from("activities")
            .update(activity).eq("id", value: activity.id).execute()
    }

    public func delete(id: String) async throws {
        try await client.from("activities").delete().eq("id", value: id).execute()
    }
}
