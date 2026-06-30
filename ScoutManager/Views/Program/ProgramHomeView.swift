import SwiftUI

private enum ProgramSection: String, CaseIterable {
    case infos     = "Infos"
    case planning  = "Planning"
    case activites = "Activités"
}

/// Onglet Camp — coquille avec sélecteur de section segmenté.
struct ProgramHomeView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @State private var selectedSection: ProgramSection = .infos
    @State private var showingCreateCamp = false

    var body: some View {
        NavigationStack {
            Group {
                if campStore.isLoading {
                    LoadingView()
                } else if campStore.selectedCamp == nil {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle("Camp")
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
                message: "Crée ou choisis un camp."
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
        VStack(spacing: 0) {
            // Sélecteur de camp
            CampPickerView()
                .padding(.horizontal, SGDFTheme.Spacing.md)
                .padding(.top, SGDFTheme.Spacing.sm)
                .padding(.bottom, SGDFTheme.Spacing.sm)

            // Sélecteur de section
            Picker("Section", selection: $selectedSection) {
                ForEach(ProgramSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, SGDFTheme.Spacing.md)
            .padding(.bottom, SGDFTheme.Spacing.sm)
            .tint(SGDFColors.violet)

            // Contenu de la section active
            sectionContent
        }
        .background(SGDFColors.background)
    }

    @ViewBuilder
    private var sectionContent: some View {
        if selectedSection == .infos {
            CampInfoView()
        } else if selectedSection == .planning {
            ProgramPlanView()
        } else {
            ActivityLibraryView()
        }
    }
}
