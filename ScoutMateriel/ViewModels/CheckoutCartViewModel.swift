import SwiftUI
import ScoutKit

@MainActor
final class CheckoutCartViewModel: ObservableObject {
    struct CartLine: Identifiable {
        let item: Item
        var qty: Int
        var id: String { item.id }
    }

    @Published var available: [Item] = []
    @Published var label: String = ""
    @Published var notes: String = ""
    @Published var cart: [CartLine] = []
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    func loadAvailable() async {
        available = (try? await ItemService().list())?.filter {
            ($0.quantityAvailable ?? $0.quantity) > 0
        } ?? []
    }

    func maxQty(_ item: Item) -> Int {
        item.quantityAvailable ?? item.quantity
    }

    func add(_ item: Item) {
        guard !cart.contains(where: { $0.item.id == item.id }) else { return }
        cart.append(CartLine(item: item, qty: 1))
    }

    func removeLine(at offsets: IndexSet) {
        cart.remove(atOffsets: offsets)
    }

    var canValidate: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && !cart.isEmpty
    }

    func validate() async throws {
        _ = try await CheckoutService().create(
            label: label,
            notes: notes.isEmpty ? nil : notes,
            items: cart.map { ($0.item.id, $0.qty) }
        )
    }
}
