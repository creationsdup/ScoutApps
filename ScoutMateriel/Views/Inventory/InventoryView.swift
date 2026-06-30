import SwiftUI
import ScoutKit

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .scope:    scopePhase
                case .scanning: scanningPhase
                case .summary:  summaryPhase
                }
            }
            .background(SGDFColors.background)
            .navigationTitle("Inventaire rapide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task { await viewModel.loadReferentials() }
            .onChange(of: viewModel.closed) { _, isClosed in if isClosed { dismiss() } }
            .alert("Erreur", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "") }
        }
    }

    // MARK: - Phase 1 : périmètre
    private var scopePhase: some View {
        Form {
            Section("Périmètre") {
                Picker("Filtrer par", selection: $viewModel.useLocation) {
                    Text("Localisation").tag(true)
                    Text("Catégorie").tag(false)
                }
                .pickerStyle(.segmented)
                if viewModel.useLocation {
                    Picker("Localisation", selection: $viewModel.selectedLocationId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(viewModel.locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                } else {
                    Picker("Catégorie", selection: $viewModel.selectedCategoryId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(viewModel.categories) { Text($0.name).tag(String?.some($0.id)) }
                    }
                }
            }
            Section {
                SGDFButton("Démarrer l'inventaire", kind: .primary, systemImage: "play.fill") {
                    Task { await viewModel.start() }
                }
                .disabled(!viewModel.canStart || viewModel.isLoading)
            }
        }
    }

    // MARK: - Phase 2 : scan / pointage
    private var scanningPhase: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Présent \(viewModel.present.count)/\(viewModel.expected.count)")
                    .foregroundStyle(SGDFColors.green)
                Spacer()
                Text("Non scanné \(viewModel.remaining)")
                    .foregroundStyle(SGDFColors.textSecondary)
                Spacer()
                Text("En trop \(viewModel.extras.count)")
                    .foregroundStyle(SGDFColors.orange)
            }
            .font(SGDFTheme.FontStyle.caption().weight(.semibold))
            .padding(SGDFTheme.Spacing.md)

            List {
                Section {
                    SGDFTextField("TAG-000001", text: $viewModel.manualCode, systemImage: "qrcode")
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    SGDFButton("Valider le code", kind: .secondary, systemImage: "checkmark") {
                        viewModel.resolve(viewModel.manualCode)
                    }
                    if let msg = viewModel.scanMessage {
                        Text(msg)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                }
                Section("À pointer") {
                    ForEach(viewModel.expected) { item in
                        Button { viewModel.toggle(item) } label: {
                            HStack(spacing: SGDFTheme.Spacing.md) {
                                Image(systemName: viewModel.pointedIds.contains(item.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.pointedIds.contains(item.id)
                                      ? SGDFColors.green : SGDFColors.textSecondary)
                                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                                    Text(item.name).foregroundStyle(SGDFColors.textPrimary)
                                    Text(item.inventoryCode)
                                        .font(SGDFTheme.FontStyle.caption())
                                        .foregroundStyle(SGDFColors.textSecondary)
                                }
                            }
                        }
                    }
                }
                if !viewModel.extras.isEmpty {
                    Section("En trop") {
                        ForEach(viewModel.extras) { item in
                            Text("\(item.name) — \(item.inventoryCode)")
                                .foregroundStyle(SGDFColors.orange)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            SGDFButton("Terminer", kind: .primary, systemImage: "flag.checkered") {
                viewModel.finish()
            }
            .padding(SGDFTheme.Spacing.md)
        }
    }

    // MARK: - Phase 3 : résumé
    private var summaryPhase: some View {
        List {
            Section {
                summaryRow("Présent", viewModel.present.count, SGDFColors.lightGreen)
                summaryRow("Manquant", viewModel.missing.count, SGDFColors.red)
                summaryRow("En trop", viewModel.extras.count, SGDFColors.orange)
            }
            if !viewModel.missing.isEmpty {
                Section("Manquants") {
                    ForEach(viewModel.missing) { item in
                        Text("\(item.name) — \(item.inventoryCode)")
                            .foregroundStyle(SGDFColors.textPrimary)
                    }
                }
            }
            if !viewModel.extras.isEmpty {
                Section("En trop") {
                    ForEach(viewModel.extras) { item in
                        Text("\(item.name) — \(item.inventoryCode)")
                            .foregroundStyle(SGDFColors.textPrimary)
                    }
                }
            }
            Section {
                SGDFButton("Clôturer l'inventaire", kind: .primary, systemImage: "checkmark.seal.fill") {
                    Task { await viewModel.close() }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func summaryRow(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(SGDFColors.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
        }
    }
}
