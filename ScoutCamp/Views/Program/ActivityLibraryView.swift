import SwiftUI
import ScoutKit

/// Bibliothèque d'activités réutilisables, section Activités de ProgramHomeView.
struct ActivityLibraryView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = ActivityLibraryViewModel()
    @State private var formTarget: ActivityFormTarget?

    /// Cible du formulaire : nouvelle activité ou édition d'une existante.
    private enum ActivityFormTarget: Identifiable {
        case new
        case edit(Activity)
        var id: String { if case .edit(let a) = self { return a.id } else { return "new" } }
        var activity: Activity? { if case .edit(let a) = self { return a } else { return nil } }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.filtered.isEmpty {
                emptyState
            } else {
                activityList
            }
        }
        .toolbar {
            if session.canWrite {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        formTarget = .new
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(SGDFColors.orange)
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                filterMenu
            }
        }
        .sheet(item: $formTarget) { target in
            ActivityFormView(activity: target.activity, onSaved: { activity, isNew in
                if isNew {
                    viewModel.activities.insert(activity, at: 0)
                } else if let i = viewModel.activities.firstIndex(where: { $0.id == activity.id }) {
                    viewModel.activities[i] = activity
                }
            })
        }
        .task { await viewModel.load() }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: SGDFTheme.Spacing.lg) {
            EmptyStateView(
                systemImage: "star.circle",
                title: "Aucune activité",
                message: "Ajoute des activités à ta bibliothèque."
            )
            if session.canWrite {
                SGDFButton("Nouvelle activité", kind: .quickAction, systemImage: "plus") {
                    formTarget = .new
                }
                .padding(.horizontal, SGDFTheme.Spacing.xl)
            }
        }
    }

    private var activityList: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                }
            }
            ForEach(viewModel.filtered) { activity in
                ActivityRow(activity: activity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if session.canWrite {
                            formTarget = .edit(activity)
                        }
                    }
            }
            .onDelete { indexSet in
                Task {
                    for i in indexSet {
                        await viewModel.delete(viewModel.filtered[i])
                    }
                }
            }
            .deleteDisabled(!session.canWrite)
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Type") {
                Button("Tous") { viewModel.typeFilter = nil }
                ForEach(ActivityType.allCases, id: \.self) { type in
                    Button(type.label) { viewModel.typeFilter = type }
                }
            }
            Section("Branche") {
                Button("Toutes") { viewModel.branchFilter = nil }
                ForEach(Branch.allCases, id: \.self) { branch in
                    Button(branch.label) { viewModel.branchFilter = branch }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(SGDFColors.violet)
        }
    }
}

// MARK: - Row (private subview pour éviter les expressions géantes)

private struct ActivityRow: View {
    let activity: Activity
    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            Text(activity.name)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(SGDFColors.textPrimary)
            ActivityRowMeta(activity: activity)
        }
        .padding(.vertical, SGDFTheme.Spacing.xs)
    }
}

private struct ActivityRowMeta: View {
    let activity: Activity
    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.sm) {
            if let type = activity.type {
                Text(type.label)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.violet)
            }
            if let dur = activity.durationMin {
                Text("\(dur) min")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
            if let branch = activity.branch {
                Text(branch.label)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
    }
}
