import SwiftUI

struct FoodStockView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = FoodStockViewModel()
    @State private var showingForm = false
    @State private var editingItem: FoodStockItem? = nil

    // Formatteur d'affichage FR court (ex. "12 juil.")
    private static let displayDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        Group {
            if campStore.selectedCamp == nil {
                EmptyStateView(
                    systemImage: "shippingbox",
                    title: "Aucun camp",
                    message: "Sélectionne un camp dans l'onglet Intendance."
                )
            } else {
                campContent
            }
        }
        .navigationTitle("Stock")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if session.canWrite, campStore.selectedCamp != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingItem = nil
                        showingForm = true
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
        .sheet(isPresented: $showingForm) {
            if let camp = campStore.selectedCamp {
                FoodStockFormView(viewModel: viewModel, campId: camp.id, item: editingItem)
            }
        }
    }

    // MARK: - Camp content

    @ViewBuilder
    private var campContent: some View {
        if viewModel.isLoading {
            LoadingView()
        } else {
            List {
                if let err = viewModel.errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }

                if viewModel.items.isEmpty {
                    Section {
                        Text("Réserve vide. Ajoute une denrée.")
                            .font(SGDFTheme.FontStyle.body())
                            .foregroundStyle(SGDFColors.textSecondary)
                            .listRowBackground(SGDFColors.background)
                    }
                } else {
                    Section {
                        ForEach(viewModel.items) { item in
                            stockRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard session.canWrite else { return }
                                    editingItem = item
                                    showingForm = true
                                }
                        }
                        .onDelete { offsets in
                            guard session.canWrite else { return }
                            for i in offsets {
                                let item = viewModel.items[i]
                                Task { await viewModel.delete(item) }
                            }
                        }
                        .deleteDisabled(!session.canWrite)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(SGDFColors.background)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func stockRow(item: FoodStockItem) -> some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            HStack {
                Text(item.name)
                    .font(SGDFTheme.FontStyle.body().weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)

                Spacer()

                // Quantité + unité
                if let qty = item.quantity {
                    Text("\(qty.qtyDisplay)\(item.unit.map { " \($0)" } ?? "")")
                        .font(SGDFTheme.FontStyle.body())
                        .foregroundStyle(SGDFColors.textPrimary)
                } else if let unit = item.unit {
                    Text(unit)
                        .font(SGDFTheme.FontStyle.body())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            }

            // Emplacement
            if let loc = item.location, !loc.isEmpty {
                Text(loc)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }

            // Badge péremption
            expiryBadge(for: item)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func expiryBadge(for item: FoodStockItem) -> some View {
        let status = viewModel.expiryStatus(item)
        switch status {
        case .none:
            EmptyView()
        case .ok:
            if let dateStr = item.expiryDate,
               let date = SGDFDate.day(from: dateStr) {
                Text("Péremption : \(Self.displayDF.string(from: date))")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        case .soon:
            if let dateStr = item.expiryDate,
               let date = SGDFDate.day(from: dateStr) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(SGDFColors.orange)
                    Text("Bientôt périmé · \(Self.displayDF.string(from: date))")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.orange)
                }
            }
        case .expired:
            if let dateStr = item.expiryDate,
               let date = SGDFDate.day(from: dateStr) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(SGDFColors.red)
                    Text("Périmé · \(Self.displayDF.string(from: date))")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                }
            }
        }
    }
}
