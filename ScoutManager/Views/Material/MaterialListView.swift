import SwiftUI

struct MaterialListView: View {
    @StateObject private var viewModel = MaterialListViewModel()
    @State private var showFilters = false
    @State private var showAddForm = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Matériel")
                .background(SGDFColors.background)
                .searchable(text: $viewModel.search, prompt: "Rechercher un matériel")
                .onSubmit(of: .search) { Task { await viewModel.load() } }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showAddForm = true } label: { Image(systemName: "plus") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showFilters = true } label: {
                            Image(systemName: viewModel.activeFilterCount > 0
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .sheet(isPresented: $showAddForm) {
                    MaterialFormView(item: nil) { Task { await viewModel.load() } }
                }
                .sheet(isPresented: $showFilters) {
                    MaterialFilterView(viewModel: viewModel)
                }
                .navigationDestination(for: Item.self) { item in
                    MaterialDetailView(item: item, listViewModel: viewModel)
                }
                .task {
                    await viewModel.loadReferentials()
                    await viewModel.load()
                }
                .refreshable { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            LoadingView()
        } else if let error = viewModel.errorMessage {
            EmptyStateView(systemImage: "exclamationmark.triangle.fill",
                           title: "Erreur", message: error)
        } else if viewModel.items.isEmpty {
            EmptyStateView(systemImage: "shippingbox",
                           title: "Aucun matériel",
                           message: "Aucun matériel ne correspond à ta recherche.")
        } else {
            List {
                ForEach(viewModel.items) { item in
                    NavigationLink(value: item) { MaterialRow(item: item) }
                }
            }
            .listStyle(.plain)
        }
    }
}

/// Ligne de liste : nom + code + badge statut (+ quantité).
private struct MaterialRow: View {
    let item: Item
    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                Text(item.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Text(item.inventoryCode)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
            Spacer()
            SGDFBadge(status: item.status)
        }
        .padding(.vertical, SGDFTheme.Spacing.xs)
    }
}
