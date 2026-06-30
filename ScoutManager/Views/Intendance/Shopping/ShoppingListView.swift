import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        Group {
            if let camp = campStore.selectedCamp {
                campContent(camp: camp)
            } else {
                EmptyStateView(
                    systemImage: "cart",
                    title: "Aucun camp",
                    message: "Sélectionne un camp dans l'onglet Intendance."
                )
            }
        }
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if session.canWrite, campStore.selectedCamp != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.errorMessage = nil
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(SGDFColors.primaryBlue)
                    }
                }
            }
        }
        .task {
            if let camp = campStore.selectedCamp {
                await viewModel.load(campId: camp.id)
            }
        }
        .onChange(of: campStore.selectedCampID) { _, _ in
            Task {
                if let camp = campStore.selectedCamp {
                    await viewModel.load(campId: camp.id)
                } else {
                    viewModel.items = []
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            if let camp = campStore.selectedCamp {
                ShoppingAddView(viewModel: viewModel, campId: camp.id, isPresented: $showingAddSheet)
            }
        }
    }

    // MARK: - Camp content

    @ViewBuilder
    private func campContent(camp: Camp) -> some View {
        if viewModel.isLoading {
            LoadingView()
        } else {
            List {
                // Section : bouton de génération
                if session.canWrite {
                    Section {
                        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                            SGDFButton(
                                viewModel.isGenerating ? "Génération…" : "Générer depuis les menus",
                                kind: .quickAction,
                                systemImage: viewModel.isGenerating ? nil : "wand.and.stars"
                            ) {
                                Task { await viewModel.generate(camp: camp) }
                            }
                            .disabled(viewModel.isGenerating)
                            .overlay {
                                if viewModel.isGenerating {
                                    HStack {
                                        Spacer()
                                        ProgressView().tint(SGDFColors.onColor)
                                        Spacer()
                                    }
                                }
                            }

                            Text("Remplace les lignes issues des menus, garde les ajouts manuels.")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                        .listRowBackground(SGDFColors.background)
                        .listRowInsets(EdgeInsets(top: SGDFTheme.Spacing.sm,
                                                  leading: SGDFTheme.Spacing.md,
                                                  bottom: SGDFTheme.Spacing.sm,
                                                  trailing: SGDFTheme.Spacing.md))
                    }
                }

                // Erreur éventuelle
                if let err = viewModel.errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }

                // Liste des articles
                if viewModel.items.isEmpty {
                    Section {
                        Text("Liste vide. Génère depuis les menus ou ajoute un article.")
                            .font(SGDFTheme.FontStyle.body())
                            .foregroundStyle(SGDFColors.textSecondary)
                            .listRowBackground(SGDFColors.background)
                    }
                } else {
                    Section {
                        ForEach(viewModel.items) { item in
                            ShoppingItemRow(item: item, canWrite: session.canWrite) {
                                Task { await viewModel.toggle(item) }
                            }
                        }
                        .onDelete { offsets in
                            guard session.canWrite else { return }
                            for i in offsets {
                                let item = viewModel.items[i]
                                Task { await viewModel.delete(item) }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(SGDFColors.background)
        }
    }
}

// MARK: - Row

private struct ShoppingItemRow: View {
    let item: ShoppingItem
    let canWrite: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.sm) {
            // Case à cocher
            Button(action: {
                guard canWrite else { return }
                onToggle()
            }) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.checked ? SGDFColors.green : SGDFColors.textSecondary)
            }
            .buttonStyle(.plain)

            // Nom + source
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(item.checked ? SGDFColors.textSecondary : SGDFColors.textPrimary)
                    .strikethrough(item.checked, color: SGDFColors.textSecondary)

                Text(item.source.label)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }

            Spacer()

            // Quantité + unité
            if let qty = item.quantity {
                Text("\(qty.qtyDisplay)\(item.unit.map { " \($0)" } ?? "")")
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(item.checked ? SGDFColors.textSecondary : SGDFColors.textPrimary)
            } else if let unit = item.unit {
                Text(unit)
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}
