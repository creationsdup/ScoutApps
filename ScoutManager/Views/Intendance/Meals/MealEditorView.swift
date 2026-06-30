import SwiftUI

struct MealEditorView: View {
    @ObservedObject var viewModel: MealPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore

    let campId: String
    let date: String
    let slot: MealSlot
    let existingMeal: Meal?

    @State private var title: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Recipe state
    @State private var selectedRecipeIds: Set<String> = []
    @State private var allRecipes: [Recipe] = []
    @State private var recipesLoaded = false

    private let recipeService = RecipeService()

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

    private var selectedRecipeNames: String {
        let names = allRecipes
            .filter { selectedRecipeIds.contains($0.id) }
            .map(\.name)
        return names.isEmpty ? "Aucune" : names.joined(separator: ", ")
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

                // Section Recettes
                Section("Recettes") {
                    NavigationLink(destination: MealRecipesPickerView(
                        allRecipes: allRecipes,
                        selectedIds: $selectedRecipeIds
                    )) {
                        HStack {
                            Text("Recettes (\(selectedRecipeIds.count))")
                                .foregroundStyle(SGDFColors.textPrimary)
                            Spacer()
                            Text(selectedRecipeNames)
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
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
        .task { await loadRecipes() }
    }

    private func loadRecipes() async {
        guard !recipesLoaded else { return }
        do {
            async let recipesTask = recipeService.list()
            if let mealId = existingMeal?.id {
                async let idsTask = recipeService.recipeIds(mealId: mealId)
                let (recipes, ids) = try await (recipesTask, idsTask)
                allRecipes = recipes
                selectedRecipeIds = Set(ids)
            } else {
                allRecipes = try await recipesTask
            }
            recipesLoaded = true
        } catch {
            // Non-fatal: recipe picker still shows empty
            allRecipes = []
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            // 1. Upsert le repas — propage l'erreur (rien à annuler)
            let saved = try await viewModel.save(
                campId: campId,
                date: date,
                slot: slot,
                existingId: existingMeal?.id,
                title: title,
                notes: notes
            )
            // 2. Lie les recettes — non-bloquant : on dismiss dans tous les cas
            do {
                try await recipeService.setRecipes(
                    mealId: saved.id,
                    recipeIds: Array(selectedRecipeIds)
                )
            } catch {
                errorMessage = "Repas enregistré. Lien recettes non sauvegardé : \(error.localizedDescription)"
            }
            dismiss()
        } catch {
            errorMessage = "Impossible d'enregistrer : \(error.localizedDescription)"
        }
    }
}
