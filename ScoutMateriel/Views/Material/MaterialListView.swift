import SwiftUI
import ScoutKit

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
                ForEach(viewModel.groups) { group in
                    Section {
                        ForEach(group.subgroups) { sub in
                            DisclosureGroup {
                                ForEach(sub.items) { item in
                                    NavigationLink(value: item) { MaterialRow(item: item) }
                                        .listRowInsets(EdgeInsets(
                                            top: SGDFTheme.Spacing.xs,
                                            leading: SGDFTheme.Spacing.sm,
                                            bottom: SGDFTheme.Spacing.xs,
                                            trailing: SGDFTheme.Spacing.md))
                                }
                            } label: {
                                Text(sub.name)
                                    .font(SGDFTheme.FontStyle.caption())
                                    .foregroundStyle(SGDFColors.textSecondary)
                            }
                        }
                    } header: {
                        Text(group.name)
                            .foregroundStyle(SGDFColors.primaryBlue)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

/// Ligne de liste : vignette + nom + code + badge statut (+ quantité).
private struct MaterialRow: View {
    let item: Item

    private var imageURL: URL? {
        guard let path = item.imagePath else { return nil }
        return try? ImageStorageService().publicURL(for: path)
    }

    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.md) {
            thumbnail
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                Text(item.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Text(item.inventoryCode)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
                if item.trackingType == .global {
                    Text("Dispo \(item.quantityAvailable ?? item.quantity) / \(item.quantity)")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            }
            Spacer()
            if item.isLowStock {
                Label("Stock faible", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(SGDFColors.orange)
                    .accessibilityLabel("Stock faible")
            }
            SGDFBadge(status: item.status)
        }
        .padding(.vertical, SGDFTheme.Spacing.xs)
    }

    @ViewBuilder
    private var thumbnail: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle().fill(SGDFColors.border)
                    .overlay(Image(systemName: "photo")
                        .foregroundStyle(SGDFColors.textSecondary))
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
    }
}
