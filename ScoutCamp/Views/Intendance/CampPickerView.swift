import SwiftUI
import ScoutKit

struct CampPickerView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @State private var showingForm = false
    @State private var campToEdit: Camp? = nil   // nil → création, non-nil → édition
    @State private var showingList = false

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
            HStack {
                // Sélecteur de camp
                Menu {
                    ForEach(campStore.camps) { camp in
                        Button(campMenuLabel(camp)) {
                            campStore.selectedCampID = camp.id
                        }
                    }
                    Divider()
                    Button("Gérer les camps…") { showingList = true }
                } label: {
                    HStack(spacing: SGDFTheme.Spacing.xs) {
                        Text(campStore.selectedCamp?.name ?? "Choisir un camp")
                            .font(SGDFTheme.FontStyle.body().weight(.semibold))
                            .foregroundStyle(SGDFColors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                }

                Spacer()

                if session.canWrite {
                    // Modifier le camp courant
                    if let current = campStore.selectedCamp {
                        Button {
                            campToEdit = current
                            showingForm = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(SGDFColors.primaryBlue)
                        }
                    }
                    // Nouveau camp
                    Button {
                        campToEdit = nil
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(SGDFColors.orange)
                    }
                }
            }

            // Carte d'info du camp sélectionné
            if let camp = campStore.selectedCamp {
                SGDFCard {
                    Text(camp.name)
                        .font(SGDFTheme.FontStyle.sectionTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                    if let loc = camp.location {
                        Label(loc, systemImage: "mappin")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                    if let start = camp.startDate, let end = camp.endDate {
                        Label("\(start) → \(end)", systemImage: "calendar")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    } else if let start = camp.startDate {
                        Label("Dès le \(start)", systemImage: "calendar")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                    HStack(spacing: SGDFTheme.Spacing.md) {
                        if let branch = camp.branch {
                            Label(branch.label, systemImage: "person.3")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                        if let p = camp.participantsCount, p > 0 {
                            Label("\(p) participants", systemImage: "person.fill")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                        if let e = camp.encadrantsCount, e > 0 {
                            Label("\(e) encadrants", systemImage: "person.badge.shield.checkmark")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            CampFormView(existingCamp: campToEdit)
        }
        .sheet(isPresented: $showingList) {
            CampListView()
        }
    }

    private func campMenuLabel(_ camp: Camp) -> String {
        if let start = camp.startDate {
            return "\(camp.name) (\(start))"
        }
        return camp.name
    }
}
