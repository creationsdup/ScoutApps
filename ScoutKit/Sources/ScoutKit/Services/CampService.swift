import Foundation
import Supabase

/// Accès aux camps (table `camps`). Pivot partagé Intendance/Programme.
public struct CampService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    public func list() async throws -> [Camp] {
        try await client.from("camps").select().order("start_date", ascending: false).execute().value
    }

    @discardableResult
    public func create(_ camp: Camp) async throws -> Camp {
        try await client.from("camps").insert(camp).select().single().execute().value
    }

    public func update(_ camp: Camp) async throws {
        try await client.from("camps").update(camp).eq("id", value: camp.id).execute()
    }

    public func delete(id: String) async throws {
        try await client.from("camps").delete().eq("id", value: id).execute()
    }
}
