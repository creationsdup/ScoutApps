import SwiftUI
import ScoutKit

@MainActor
final class CheckoutDetailViewModel: ObservableObject {
    @Published var lines: [CheckoutLine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(checkoutId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            lines = try await CheckoutService().lines(checkoutId: checkoutId)
        } catch {
            errorMessage = "Impossible de charger les lignes."
            lines = []
        }
        isLoading = false
    }

    func returnLine(_ line: CheckoutLine, qty: Int, checkoutId: String) async {
        do {
            try await CheckoutService().returnLine(checkoutItemId: line.id, qty: qty)
            await load(checkoutId: checkoutId)
        } catch {
            errorMessage = "Retour impossible : \(error.localizedDescription)"
        }
    }

    func returnAll(checkoutId: String) async {
        do {
            try await CheckoutService().returnAll(checkoutId: checkoutId)
            await load(checkoutId: checkoutId)
        } catch {
            errorMessage = "Retour total impossible : \(error.localizedDescription)"
        }
    }
}
