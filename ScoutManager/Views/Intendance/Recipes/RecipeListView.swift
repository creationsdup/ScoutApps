import SwiftUI

struct RecipeListView: View {
    @StateObject private var viewModel = RecipeListViewModel()
    @EnvironmentObject private var session: SessionStore
    @State private var showForm = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.filtered.isEmpty {
                EmptyStateView(
                    systemImage: "book",
                    title: "Aucune recette",
                    message: "Crée ta première fiche recette."
                )
            } else {
                recipeList
            }
        }
        .navigationTitle("Recettes")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                branchPicker
            }
            if session.canWrite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(SGDFColors.primaryBlue)
                    }
                }
            }
        }
        .sheet(isPresented: $showForm) {
            RecipeFormView(recipe: nil) {
                Task { await viewModel.load() }
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "") }
        .task { await viewModel.load() }
    }

    private var recipeList: some View {
        List {
            ForEach(viewModel.filtered) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                    recipeRow(recipe)
                }
                .deleteDisabled(!session.canWrite)
            }
            .onDelete { offsets in
                for i in offsets {
                    let recipe = viewModel.filtered[i]
                    Task { await viewModel.delete(recipe) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func recipeRow(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            Text(recipe.name)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(SGDFColors.textPrimary)
            HStack(spacing: SGDFTheme.Spacing.sm) {
                Text("Pour \(recipe.servingsBase) pers.")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
                if let branch = recipe.branch {
                    Text(branch.rawValue)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.lightBlue)
                }
            }
        }
        .padding(.vertical, SGDFTheme.Spacing.xs)
    }

    private var branchPicker: some View {
        Menu {
            Button("Toutes") { viewModel.branchFilter = nil }
            ForEach(Branch.allCases, id: \.self) { b in
                Button(b.rawValue) { viewModel.branchFilter = b }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.branchFilter?.rawValue ?? "Toutes")
                    .font(SGDFTheme.FontStyle.caption())
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(SGDFColors.primaryBlue)
        }
    }
}
