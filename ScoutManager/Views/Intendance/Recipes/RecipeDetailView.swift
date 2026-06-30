import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @StateObject private var viewModel = RecipeDetailViewModel()
    @EnvironmentObject private var session: SessionStore
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.lg) {
                // En-tête
                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                    Text(recipe.name)
                        .font(SGDFTheme.FontStyle.screenTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                    HStack(spacing: SGDFTheme.Spacing.sm) {
                        Text("Pour \(recipe.servingsBase) part\(recipe.servingsBase > 1 ? "s" : "")")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                        if let branch = recipe.branch {
                            Text(branch.rawValue)
                                .font(SGDFTheme.FontStyle.caption().weight(.semibold))
                                .foregroundStyle(SGDFColors.lightBlue)
                        }
                    }
                }

                // Section Ingrédients
                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
                    Text("Ingrédients")
                        .font(SGDFTheme.FontStyle.sectionTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                    SGDFCard {
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .tint(SGDFColors.primaryBlue)
                                Spacer()
                            }
                        } else if viewModel.ingredients.isEmpty {
                            Text("Aucun ingrédient")
                                .font(SGDFTheme.FontStyle.body())
                                .foregroundStyle(SGDFColors.textSecondary)
                        } else {
                            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                                ForEach(viewModel.ingredients) { ing in
                                    HStack {
                                        Text(ing.name)
                                            .font(SGDFTheme.FontStyle.body())
                                            .foregroundStyle(SGDFColors.textPrimary)
                                        Spacer()
                                        Text(ingredientDetail(ing))
                                            .font(SGDFTheme.FontStyle.body())
                                            .foregroundStyle(SGDFColors.textSecondary)
                                    }
                                    .padding(.vertical, 2)
                                    if ing.id != viewModel.ingredients.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }

                // Section Préparation
                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
                    Text("Préparation")
                        .font(SGDFTheme.FontStyle.sectionTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                    SGDFCard {
                        Text(recipe.instructions ?? "—")
                            .font(SGDFTheme.FontStyle.body())
                            .foregroundStyle(recipe.instructions != nil ? SGDFColors.textPrimary : SGDFColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                }
            }
            .padding(SGDFTheme.Spacing.md)
        }
        .background(SGDFColors.background)
        .navigationTitle("Fiche recette")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.canWrite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Modifier") { showEdit = true }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            RecipeFormView(recipe: recipe) {
                Task { await viewModel.load(recipeId: recipe.id) }
            }
        }
        .task { await viewModel.load(recipeId: recipe.id) }
    }

    private func ingredientDetail(_ ing: RecipeIngredient) -> String {
        var parts: [String] = []
        if let q = ing.quantity {
            let qStr = q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(q)
            parts.append(qStr)
        }
        if let u = ing.unit, !u.isEmpty { parts.append(u) }
        return parts.joined(separator: " ")
    }
}
