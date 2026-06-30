import SwiftUI

struct FoodTraceListView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = FoodTraceViewModel()
    @State private var showingForm = false
    @State private var editingEntry: FoodTraceEntry? = nil

    private static let displayDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    var body: some View {
        Group {
            if campStore.selectedCamp == nil {
                EmptyStateView(
                    systemImage: "doc.text.magnifyingglass",
                    title: "Aucun camp",
                    message: "Sélectionne un camp dans l'onglet Intendance."
                )
            } else {
                campContent
            }
        }
        .navigationTitle("Registre")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if session.canWrite, campStore.selectedCamp != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingEntry = nil
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
                    viewModel.entries = []
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            if let camp = campStore.selectedCamp {
                FoodTraceFormView(viewModel: viewModel, campId: camp.id, entry: editingEntry)
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

                if viewModel.entries.isEmpty {
                    Section {
                        Text("Registre vide. Ajoute une denrée reçue.")
                            .font(SGDFTheme.FontStyle.body())
                            .foregroundStyle(SGDFColors.textSecondary)
                            .listRowBackground(SGDFColors.background)
                    }
                } else {
                    Section {
                        ForEach(viewModel.entries) { entry in
                            TraceRow(
                                entry: entry,
                                receivedLabel: formattedDate(entry.receivedDate)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard session.canWrite else { return }
                                editingEntry = entry
                                showingForm = true
                            }
                        }
                        .onDelete { offsets in
                            guard session.canWrite else { return }
                            for i in offsets {
                                let entry = viewModel.entries[i]
                                Task { await viewModel.delete(entry) }
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

    private func formattedDate(_ dateStr: String?) -> String? {
        guard let s = dateStr, let date = SGDFDate.day(from: s) else { return nil }
        return Self.displayDF.string(from: date)
    }
}

// MARK: - Row (sous-vue privée pour éviter "unable to type-check")

private struct TraceRow: View {
    let entry: FoodTraceEntry
    let receivedLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            Text(entry.productName)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(SGDFColors.textPrimary)

            subtitleText

            if let lot = entry.lotNumber, !lot.isEmpty {
                Text("Lot : \(lot)")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }

            if let dateLabel = receivedLabel {
                Text("Reçu le \(dateLabel)")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var subtitleText: some View {
        let parts = [entry.brand, entry.supplier].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
        }
    }
}
