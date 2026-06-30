import Foundation
import Supabase

/// Accès à la bibliothèque d'activités (table `activities`).
struct ActivityService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func list() async throws -> [Activity] {
        try await client.from("activities").select().order("name").execute().value
    }

    @discardableResult
    func create(_ activity: Activity) async throws -> Activity {
        try await client.from("activities").insert(activity).select().single().execute().value
    }

    func update(_ activity: Activity) async throws {
        try await client.from("activities")
            .update(activity).eq("id", value: activity.id).execute()
    }

    func delete(id: String) async throws {
        try await client.from("activities").delete().eq("id", value: id).execute()
    }
}
