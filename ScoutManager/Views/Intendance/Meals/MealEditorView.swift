import SwiftUI

struct MealEditorView: View {
    @ObservedObject var viewModel: MealPlanViewModel
    @Environment(\.dismiss) private var dismiss

    let campId: String
    let date: String
    let slot: MealSlot
    let existingMeal: Meal?

    @State private var title: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Formatter pour afficher la date en FR (ex. « Lun 12 juil. »)
    private static let displayDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()
    private static let parseDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(viewModel: MealPlanViewModel, campId: String, date: String,
         slot: MealSlot, existingMeal: Meal?) {
        self.viewModel = viewModel
        self.campId = campId
        self.date = date
        self.slot = slot
        self.existingMeal = existingMeal
        _title = State(initialValue: existingMeal?.title ?? "")
        _notes = State(initialValue: existingMeal?.notes ?? "")
    }

    private var dateDisplay: String {
        if let d = Self.parseDF.date(from: date) {
            return Self.displayDF.string(from: d).capitalized
        }
        return date
    }

    var body: some View {
        NavigationStack {
            Form {
                // En-tête lecture seule
                Section {
                    HStack {
                        Text(dateDisplay)
                            .font(SGDFTheme.FontStyle.body().weight(.semibold))
                            .foregroundStyle(SGDFColors.textPrimary)
                        Spacer()
                        Text(slot.label)
                            .font(SGDFTheme.FontStyle.body())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                }

                Section("Repas") {
                    TextField("Plat / menu", text: $title)
                        .foregroundStyle(SGDFColors.textPrimary)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundStyle(SGDFColors.textPrimary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle(existingMeal == nil ? "Nouveau repas" : "Modifier")
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
                    .foregroundStyle(SGDFColors.primaryBlue)
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await viewModel.save(
                campId: campId,
                date: date,
                slot: slot,
                existingId: existingMeal?.id,
                title: title,
                notes: notes
            )
            dismiss()
        } catch {
            errorMessage = "Impossible d'enregistrer le repas : \(error.localizedDescription)"
        }
        isSaving = false
    }
}
