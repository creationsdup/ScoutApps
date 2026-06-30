import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = BudgetViewModel()

    @State private var showingAddExpense = false
    @State private var editingExpense: Expense?

    var body: some View {
        Group {
            if campStore.selectedCamp == nil {
                EmptyStateView(
                    systemImage: "eurosign.circle",
                    title: "Aucun camp",
                    message: "Sélectionne un camp dans l'onglet Intendance."
                )
            } else {
                content
            }
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if session.canWrite {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(SGDFColors.orange)
                    }
                }
            }
        }
        .task {
            if let c = campStore.selectedCamp {
                await viewModel.load(campId: c.id)
            }
        }
        .onChange(of: campStore.selectedCampID) { _, _ in
            Task {
                if let c = campStore.selectedCamp {
                    await viewModel.load(campId: c.id)
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            if let camp = campStore.selectedCamp {
                ExpenseFormView(expense: nil, campId: camp.id, viewModel: viewModel)
            }
        }
        .sheet(item: $editingExpense) { expense in
            if let camp = campStore.selectedCamp {
                ExpenseFormView(expense: expense, campId: camp.id, viewModel: viewModel)
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.lg) {
                // Récapitulatif
                summaryCard

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                        .padding(.horizontal, SGDFTheme.Spacing.md)
                }

                // Liste des dépenses
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.expenses.isEmpty {
                    EmptyStateView(
                        systemImage: "eurosign.circle",
                        title: "Aucune dépense",
                        message: "Aucune dépense. Ajoute ta première ligne."
                    )
                } else {
                    expenseList
                }
            }
            .padding(.vertical, SGDFTheme.Spacing.md)
        }
        .background(SGDFColors.background)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        SGDFCard {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.md) {
                Text("Récapitulatif")
                    .font(SGDFTheme.FontStyle.sectionTitle())
                    .foregroundStyle(SGDFColors.textPrimary)

                HStack(spacing: SGDFTheme.Spacing.lg) {
                    summaryItem(label: "Prévu", value: viewModel.totalPlanned.euroDisplay, color: SGDFColors.textPrimary)
                    Divider()
                    summaryItem(label: "Réel", value: viewModel.totalReal.euroDisplay, color: SGDFColors.textPrimary)
                    Divider()
                    summaryItem(
                        label: "Écart",
                        value: ecartDisplay,
                        color: ecartColor
                    )
                }
            }
        }
        .padding(.horizontal, SGDFTheme.Spacing.md)
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            Text(label)
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
            Text(value)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ecartDisplay: String {
        let e = viewModel.ecart
        if e > 0 { return "+" + e.euroDisplay }
        return e.euroDisplay
    }

    private var ecartColor: Color {
        let e = viewModel.ecart
        if e > 0 { return SGDFColors.red }
        if e < 0 { return SGDFColors.green }
        return SGDFColors.textPrimary
    }

    // MARK: - Expense list

    private var expenseList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.expenses) { expense in
                expenseRow(expense)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if session.canWrite {
                            editingExpense = expense
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if session.canWrite {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(expense) }
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                Divider()
                    .padding(.leading, SGDFTheme.Spacing.md)
            }
        }
        .background(SGDFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
        .padding(.horizontal, SGDFTheme.Spacing.md)
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(alignment: .center, spacing: SGDFTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                Text(expense.label)
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textPrimary)
                if let cat = expense.category {
                    Text(cat.label)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            }

            Spacer()

            Text(amountsDisplay(expense))
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, SGDFTheme.Spacing.md)
        .padding(.vertical, SGDFTheme.Spacing.sm)
    }

    private func amountsDisplay(_ expense: Expense) -> String {
        let planned = expense.amountPlanned.map { $0.euroDisplay } ?? "—"
        let real = expense.amountReal.map { $0.euroDisplay } ?? "—"
        return "\(planned) → \(real)"
    }
}
