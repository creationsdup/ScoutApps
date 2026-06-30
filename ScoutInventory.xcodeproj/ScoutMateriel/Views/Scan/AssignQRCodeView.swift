import SwiftUI
import ScoutKit

/// Associe une étiquette QR vierge à un matériel existant (choisi dans la liste).
struct AssignQRCodeView: View {
    let tagCode: String
    let onAssigned: () -> Void

    @StateObject private var listViewModel = MaterialListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isAssigning = false
    @State private var errorMessage: String?

    private let qrService = QRCodeService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SGDFCard {
                    Label("QR vierge : \(tagCode)", systemImage: "qrcode")
                        .foregroundStyle(SGDFColors.primaryBlue)
                    Text("Choisis le matériel à associer.")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
                .padding(SGDFTheme.Spacing.md)

                List(listViewModel.items) { item in
                    Button { assign(to: item) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name).foregroundStyle(SGDFColors.textPrimary)
                                Text(item.inventoryCode)
                                    .font(SGDFTheme.FontStyle.caption())
                                    .foregroundStyle(SGDFColors.textSecondary)
                            }
                            Spacer()
                            SGDFBadge(status: item.status)
                        }
                    }
                    .disabled(isAssigning)
                }
                .listStyle(.plain)
            }
            .background(SGDFColors.background)
            .navigationTitle("Associer le QR")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $listViewModel.search, prompt: "Rechercher")
            .onSubmit(of: .search) { Task { await listViewModel.load() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .task { await listViewModel.load() }
            .alert("Erreur", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })
            ) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func assign(to item: Item) {
        guard !isAssigning else { return }
        isAssigning = true
        Task {
            do {
                try await qrService.assign(tagCode: tagCode, toItem: item.id)
                onAssigned()
                dismiss()
            } catch {
                errorMessage = "Échec de l'association. Réessaie."
            }
            isAssigning = false
        }
    }
}
