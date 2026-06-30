import SwiftUI

struct CampListView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @State private var editingCamp: Camp? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if campStore.camps.isEmpty {
                    EmptyStateView(
                        systemImage: "tent",
                        title: "Aucun camp",
                        message: "Aucun camp disponible."
                    )
                } else {
                    List {
                        ForEach(campStore.camps) { camp in
                            Button {
                                editingCamp = camp
                            } label: {
                                CampRowView(camp: camp)
                            }
                            .foregroundStyle(SGDFColors.textPrimary)
                        }
                        .onDelete(perform: session.canWrite ? deleteCamps : nil)
                    }
                }
            }
            .navigationTitle("Gérer les camps")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingCamp) { camp in
                CampFormView(existingCamp: camp)
            }
            .overlay(alignment: .bottom) {
                if let error = errorMessage {
                    Text(error)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.onColor)
                        .padding(SGDFTheme.Spacing.sm)
                        .background(SGDFColors.red)
                        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button))
                        .padding(SGDFTheme.Spacing.md)
                }
            }
        }
    }

    private func deleteCamps(at offsets: IndexSet) {
        for index in offsets {
            let camp = campStore.camps[index]
            Task {
                do {
                    try await campStore.delete(camp)
                } catch {
                    errorMessage = "Impossible de supprimer : \(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { errorMessage = nil }
                }
            }
        }
    }
}

private struct CampRowView: View {
    let camp: Camp

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            Text(camp.name)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(SGDFColors.textPrimary)
            if let loc = camp.location {
                Text(loc)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
            if let branch = camp.branch {
                Text(branch.label)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
        .padding(.vertical, SGDFTheme.Spacing.xs)
    }
}
