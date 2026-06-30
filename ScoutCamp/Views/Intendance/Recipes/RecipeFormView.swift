import SwiftUI
import ScoutKit

struct RecipeFormView: View {
    @StateObject private var viewModel: RecipeFormViewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    init(recipe: Recipe?, onSaved: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RecipeFormViewModel(recipe: recipe))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section Identité
                Section("Identité") {
                    TextField("Nom", text: $viewModel.name)
                        .foregroundStyle(SGDFColors.textPrimary)

                    Picker("Branche", selection: $viewModel.branch) {
                        Text("Aucune").tag(Branch?.none)
                        ForEach(Branch.allCases, id: \.self) { b in
                            Text(b.rawValue).tag(Branch?.some(b))
                        }
                    }
                    .foregroundStyle(SGDFColors.textPrimary)

                    Stepper(
                        "Parts de référence : \(viewModel.servingsBase)",
                        value: $viewModel.servingsBase,
                        in: 1...999
                    )
                    .foregroundStyle(SGDFColors.textPrimary)
                }

                // Section Ingrédients
                Section {
                    ForEach($viewModel.drafts) { $draft in
                        HStack(spacing: SGDFTheme.Spacing.sm) {
                            TextField("Ingrédient", text: $draft.name)
                                .foregroundStyle(SGDFColors.textPrimary)
                            TextField("Qté", text: $draft.quantityStr)
                                .keyboardType(.decimalPad)
                                .frame(width: 55)
                                .foregroundStyle(SGDFColors.textPrimary)
                            TextField("Unité", text: $draft.unit)
                                .frame(width: 55)
                                .foregroundStyle(SGDFColors.textPrimary)
                        }
                    }
                    .onDelete { offsets in viewModel.removeIngredient(at: offsets) }

                    Button {
                        viewModel.addIngredient()
                    } label: {
                        Label("Ajouter un ingrédient", systemImage: "plus.circle")
                            .foregroundStyle(SGDFColors.orange)
                    }
                } header: {
                    Text("Ingrédients")
                }

                // Section Préparation
                Section("Préparation") {
                    TextField("Instructions", text: $viewModel.instructions, axis: .vertical)
                        .lineLimit(4...10)
                        .foregroundStyle(SGDFColors.textPrimary)
                }

                // Section erreur
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            do {
                                try await viewModel.save()
                                onSaved()
                                dismiss()
                            } catch {
                                // errorMessage is already set by the VM
                            }
                        }
                    }
                    .foregroundStyle(SGDFColors.primaryBlue)
                    .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
                }
            }
        }
        .task { await viewModel.load() }
    }
}
