import SwiftUI
import ScoutKit

@MainActor
final class CheckoutListViewModel: ObservableObject {
    @Published var checkouts: [Checkout] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            checkouts = try await CheckoutService().list()
        } catch {
            errorMessage = "Impossible de charger les sorties."
            checkouts = []
        }
        isLoading = false
    }
}
