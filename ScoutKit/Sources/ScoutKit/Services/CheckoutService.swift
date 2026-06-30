import Foundation
import Supabase

public struct CheckoutService {
    public init() {}
    private var client: SupabaseClient { SupabaseService.shared.client }

    public func list() async throws -> [Checkout] {
        try await client.from("checkouts").select().order("created_at", ascending: false).execute().value
    }

    public func lines(checkoutId: String) async throws -> [CheckoutLine] {
        try await client.from("checkout_items")
            .select("*, inventory_items(*)").eq("checkout_id", value: checkoutId)
            .execute().value
    }

    private struct CreateParams: Encodable {
        let p_label: String; let p_notes: String?; let p_items: [Line]
        struct Line: Encodable { let item_id: String; let quantity: Int }
    }
    @discardableResult
    public func create(label: String, notes: String?, items: [(itemId: String, qty: Int)]) async throws -> String {
        let params = CreateParams(p_label: label, p_notes: notes,
                                  p_items: items.map { .init(item_id: $0.itemId, quantity: $0.qty) })
        return try await client.rpc("create_checkout", params: params).execute().value
    }

    private struct ReturnLineParams: Encodable { let p_checkout_item_id: String; let p_qty: Int }
    public func returnLine(checkoutItemId: String, qty: Int) async throws {
        try await client.rpc("return_checkout_line",
                             params: ReturnLineParams(p_checkout_item_id: checkoutItemId, p_qty: qty)).execute()
    }
    public func returnAll(checkoutId: String) async throws {
        try await client.rpc("return_checkout_all", params: ["p_checkout_id": checkoutId]).execute()
    }
}
