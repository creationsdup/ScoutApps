import SwiftUI
import ScoutKit

struct MaterialListView: View {
    @StateObject private var viewModel = MaterialListViewModel()
    @EnvironmentObject private var session: SessionStore
    @State private var showFilters = false
    @State private var showAddForm = false
    @State private var showCategoryManager = false
    @State private var isSelecting = false
    @State private var selectedIds: Set<String> = []
    @State private var showMoveSheet = false
    @State private var moveErrorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Matériel")
                .background(SGDFColors.background)
                .searchable(text: $viewModel.search, prompt: "Rechercher un matériel")
                .onSubmit(of: .search) { Task { await viewModel.load() } }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if isSelecting {
                            Button("Annuler") {
                                isSelecting = false
                                selectedIds = []
                            }
                        } else {
                            Button { showAddForm = true } label: { Image(systemName: "plus") }
                        }
                    }
                    if isSelecting {
                        ToolbarItem(placement: .principal) {
                            Text("\(selectedIds.count) sélectionné(s)")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                    }
                    if isSelecting {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showMoveSheet = true
                            } label: {
                                Text("Déplacer (\(selectedIds.count))")
                                    .fontWeight(.semibold)
                            }
                            .disabled(selectedIds.isEmpty)
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showFilters = true } label: {
                                Image(systemName: viewModel.activeFilterCount > 0
                                      ? "line.3.horizontal.decrease.circle.fill"
                                      : "line.3.horizontal.decrease.circle")
                            }
                        }
                        if session.canWrite {
                            ToolbarItem(placement: .topBarTrailing) {
                                Menu {
                                    Button { isSelecting = true } label: {
                                        Label("Sélectionner", systemImage: "checkmark.circle")
                                    }
                                    Button { showCategoryManager = true } label: {
                                        Label("Organiser le matériel", systemImage: "folder.badge.gearshape")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                                .accessibilityLabel("Plus d'actions")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAddForm) {
                    MaterialFormView(item: nil) { Task { await viewModel.load() } }
                }
                .sheet(isPresented: $showFilters) {
                    MaterialFilterView(viewModel: viewModel)
                }
                .sheet(isPresented: $showCategoryManager, onDismiss: {
                    Task { await viewModel.loadReferentials(); await viewModel.load() }
                }) {
                    CategoryManagerView()
                }
                .sheet(isPresented: $showMoveSheet) {
                    MoveItemsSheet(
                        count: selectedIds.count,
                        categories: viewModel.categories,
                        subcategories: viewModel.subcategories
                    ) { categoryId, subcategoryId in
                        let ids = selectedIds
                        Task {
                            let error = await viewModel.move(itemIds: ids,
                                                             categoryId: categoryId,
                                                             subcategoryId: subcategoryId)
                            if let error {
                                moveErrorMessage = error
                            } else {
                                isSelecting = false
                                selectedIds = []
                            }
                        }
                    }
                }
                .alert("Erreur", isPresented: Binding(
                    get: { moveErrorMessage != nil },
                    set: { if !$0 { moveErrorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { moveErrorMessage = nil }
                } message: {
                    Text(moveErrorMessage ?? "")
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
                                    Group {
                                        if isSelecting {
                                            HStack(spacing: SGDFTheme.Spacing.md) {
                                                Image(systemName: selectedIds.contains(item.id)
                                                      ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedIds.contains(item.id)
                                                                     ? SGDFColors.primaryBlue
                                                                     : SGDFColors.textSecondary)
                                                MaterialRow(item: item)
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if selectedIds.contains(item.id) {
                                                    selectedIds.remove(item.id)
                                                } else {
                                                    selectedIds.insert(item.id)
                                                }
                                            }
                                        } else {
                                            NavigationLink(value: item) { MaterialRow(item: item) }
                                        }
                                    }
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

/// Sheet de choix de la cible d'un déplacement multiple : catégorie (obligatoire)
/// + sous-catégorie optionnelle. Catégorie seule ⇒ sous-catégorie effacée.
private struct MoveItemsSheet: View {
    let count: Int
    let categories: [ItemCategory]
    let subcategories: [Subcategory]
    let onConfirm: (_ categoryId: String, _ subcategoryId: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategoryId: String?
    @State private var selectedSubcategoryId: String?

    private var availableSubcategories: [Subcategory] {
        guard let categoryId = selectedCategoryId else { return [] }
        return subcategories.filter { $0.categoryId == categoryId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(count) matériel(s) sélectionné(s)")
                        .foregroundStyle(SGDFColors.textSecondary)
                }
                Section("Catégorie cible") {
                    Picker("Catégorie", selection: $selectedCategoryId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(String?.some(category.id))
                        }
                    }
                    .onChange(of: selectedCategoryId) { _, _ in
                        selectedSubcategoryId = nil
                    }
                }
                if !availableSubcategories.isEmpty {
                    Section("Sous-catégorie (optionnel)") {
                        Picker("Sous-catégorie", selection: $selectedSubcategoryId) {
                            Text("Aucune").tag(String?.none)
                            ForEach(availableSubcategories) { sub in
                                Text(sub.name).tag(String?.some(sub.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Déplacer")
            .navigationBarTitleDisplayMode(.inline)
            .background(SGDFColors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Déplacer") {
                        guard let categoryId = selectedCategoryId else { return }
                        onConfirm(categoryId, selectedSubcategoryId)
                        dismiss()
                    }
                    .disabled(selectedCategoryId == nil)
                }
            }
        }
    }
}
