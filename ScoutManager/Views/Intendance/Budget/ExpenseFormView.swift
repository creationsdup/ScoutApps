import SwiftUI

struct ExpenseFormView: View {
    let expense: Expense?
    let campId: String
    @ObservedObject var viewModel: BudgetViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var category: ExpenseCategory? = nil
    @State private var plannedStr: String = ""
    @State private var realStr: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isNew: Bool { expense == nil }

    private var parsedPlanned: Double? {
        let s = plannedStr.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        return Double(s.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedReal: Double? {
        let s = realStr.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        return Double(s.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Libellé") {
                    SGDFTextField("Libellé (requis)", text: $label)
                }

                Section("Catégorie") {
                    Picker("Catégorie", selection: $category) {
                        Text("Aucune").tag(Optional<ExpenseCategory>.none)
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text(cat.label).tag(Optional(cat))
                        }
                    }
                    .foregroundStyle(SGDFColors.textPrimary)
                }

                Section("Montants") {
                    SGDFTextField("Montant prévu (ex : 12,50)", text: $plannedStr)
                        .keyboardType(.decimalPad)
                    SGDFTextField("Montant réel (ex : 14,00)", text: $realStr)
                        .keyboardType(.decimalPad)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle(isNew ? "Nouvelle dépense" : "Modifier la dépense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? SGDFColors.primaryBlue : SGDFColors.textSecondary)
                }
            }
            .onAppear { populateFields() }
        }
    }

    // MARK: - Helpers

    private func populateFields() {
        guard let e = expense else { return }
        label = e.label
        category = e.category
        if let p = e.amountPlanned { plannedStr = String(p) }
        if let r = e.amountReal { realStr = String(r) }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let built = Expense(
            id: expense?.id ?? UUID().uuidString,
            campId: campId,
            label: label.trimmingCharacters(in: .whitespaces),
            category: category,
            amountPlanned: parsedPlanned,
            amountReal: parsedReal
        )
        do {
            try await viewModel.save(built, isNew: isNew)
            dismiss()
        } catch {
            errorMessage = "Enregistrement impossible : \(error.localizedDescription)"
        }
        isSaving = false
    }
}
