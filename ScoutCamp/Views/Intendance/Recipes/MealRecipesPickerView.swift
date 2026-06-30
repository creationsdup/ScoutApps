import SwiftUI
import ScoutKit

/// Sélecteur de recettes pour un repas. Utilisé en push depuis MealEditorView.
struct MealRecipesPickerView: View {
    let allRecipes: [Recipe]
    @Binding var selectedIds: Set<String>

    var body: some View {
        List {
            ForEach(allRecipes) { recipe in
                Button {
                    if selectedIds.contains(recipe.id) {
                        selectedIds.remove(recipe.id)
                    } else {
                        selectedIds.insert(recipe.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.name)
                                .font(SGDFTheme.FontStyle.body())
                                .foregroundStyle(SGDFColors.textPrimary)
                            Text("Pour \(recipe.servingsBase) pers.")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                        Spacer()
                        if selectedIds.contains(recipe.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(SGDFColors.green)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recettes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
