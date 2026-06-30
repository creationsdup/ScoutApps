import SwiftUI

struct IntendanceHomeView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @State private var showingCreateCamp = false

    // Sous-modules placeholder (Task M — arrive aux tasks N→S)
    private let subModules: [(title: String, icon: String)] = [
        ("Menus", "fork.knife"),
        ("Recettes", "book.closed"),
        ("Courses", "cart"),
        ("Budget", "eurosign.circle"),
        ("Stock", "shippingbox"),
        ("Registre", "doc.text")
    ]

    var body: some View {
        NavigationStack {
            Group {
                if campStore.isLoading {
                    LoadingView()
                } else if campStore.camps.isEmpty {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle("Intendance")
            .sheet(isPresented: $showingCreateCamp) {
                CampFormView(existingCamp: nil)
            }
        }
        .task { await campStore.load() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: SGDFTheme.Spacing.lg) {
            EmptyStateView(
                systemImage: "tent",
                title: "Aucun camp",
                message: "Crée ton premier camp pour commencer l'intendance."
            )
            if session.canWrite {
                SGDFButton("Créer un camp", kind: .quickAction, systemImage: "plus") {
                    showingCreateCamp = true
                }
                .padding(.horizontal, SGDFTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.lg) {
                // Sélecteur de camp
                CampPickerView()
                    .padding(.horizontal, SGDFTheme.Spacing.md)

                if let error = campStore.errorMessage {
                    Text(error)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                        .padding(.horizontal, SGDFTheme.Spacing.md)
                }

                // Grille des sous-modules (placeholders)
                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
                    Text("Modules")
                        .font(SGDFTheme.FontStyle.sectionTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                        .padding(.horizontal, SGDFTheme.Spacing.md)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: SGDFTheme.Spacing.sm),
                            GridItem(.flexible(), spacing: SGDFTheme.Spacing.sm)
                        ],
                        spacing: SGDFTheme.Spacing.sm
                    ) {
                        ForEach(subModules, id: \.title) { module in
                            subModuleCard(title: module.title, icon: module.icon)
                        }
                    }
                    .padding(.horizontal, SGDFTheme.Spacing.md)
                }
            }
            .padding(.vertical, SGDFTheme.Spacing.md)
        }
        .background(SGDFColors.background)
    }

    private func subModuleCard(title: String, icon: String) -> some View {
        SGDFCard {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(SGDFColors.primaryBlue)
                Text(title)
                    .font(SGDFTheme.FontStyle.body().weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Text("Bientôt")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
