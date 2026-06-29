import SwiftUI

struct MaterialFilterView: View {
    @ObservedObject var viewModel: MaterialListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Statut") {
                    Picker("Statut", selection: $viewModel.statusFilter) {
                        Text("Tous").tag(ItemStatus?.none)
                        // 'archived' est exclu des listes par défaut (ItemService.list) → pas filtrable ici.
                        ForEach(ItemStatus.allCases.filter { $0 != .archive }, id: \.self) { status in
                            Text(status.label).tag(ItemStatus?.some(status))
                        }
                    }
                }
                Section("Catégorie") {
                    Picker("Catégorie", selection: $viewModel.categoryFilter) {
                        Text("Toutes").tag(String?.none)
                        ForEach(viewModel.categories) { cat in
                            Text(cat.name).tag(String?.some(cat.id))
                        }
                    }
                }
                Section("Localisation") {
                    Picker("Localisation", selection: $viewModel.locationFilter) {
                        Text("Toutes").tag(String?.none)
                        ForEach(viewModel.locations) { loc in
                            Text(loc.name).tag(String?.some(loc.id))
                        }
                    }
                }
                Section {
                    Button("Réinitialiser les filtres") { viewModel.clearFilters() }
                        .foregroundStyle(SGDFColors.red)
                }
            }
            .navigationTitle("Filtres")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        Task { await viewModel.load() }
                        dismiss()
                    }
                }
            }
        }
    }
}
