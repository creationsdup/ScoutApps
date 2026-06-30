import SwiftUI
import ScoutKit

/// Fiche de lecture du camp sélectionné (section Infos de ProgramHomeView).
struct CampInfoView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @State private var showingEdit = false

    private static let displayDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.md) {
                if let camp = campStore.selectedCamp {
                    campCard(camp: camp)
                    if session.canWrite {
                        SGDFButton("Modifier le camp", kind: .secondary, systemImage: "pencil") {
                            showingEdit = true
                        }
                        .padding(.horizontal, SGDFTheme.Spacing.md)
                    }
                }
            }
            .padding(.vertical, SGDFTheme.Spacing.md)
            .padding(.horizontal, SGDFTheme.Spacing.md)
        }
        .background(SGDFColors.background)
        .sheet(isPresented: $showingEdit) {
            CampFormView(existingCamp: campStore.selectedCamp)
        }
    }

    private func formatDate(_ s: String) -> String {
        if let d = SGDFDate.day(from: s) {
            return Self.displayDF.string(from: d)
        }
        return s
    }

    private func campCard(camp: Camp) -> some View {
        SGDFCard {
            Text(camp.name)
                .font(SGDFTheme.FontStyle.sectionTitle())
                .foregroundStyle(SGDFColors.violet)

            if let location = camp.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textPrimary)
            }

            campDates(camp: camp)
            campBranch(camp: camp)
            campEffectifs(camp: camp)
        }
    }

    private func campDates(camp: Camp) -> some View {
        Group {
            if let start = camp.startDate, let end = camp.endDate {
                Label("\(formatDate(start)) → \(formatDate(end))", systemImage: "calendar")
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textPrimary)
            } else if let start = camp.startDate {
                Label("Dès le \(formatDate(start))", systemImage: "calendar")
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textPrimary)
            } else {
                EmptyView()
            }
        }
    }

    private func campBranch(camp: Camp) -> some View {
        Group {
            if let branch = camp.branch {
                Label(branch.label, systemImage: "person.3.fill")
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textPrimary)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func campEffectifs(camp: Camp) -> some View {
        if camp.participantsCount != nil || camp.encadrantsCount != nil {
            HStack(spacing: SGDFTheme.Spacing.lg) {
                if let p = camp.participantsCount {
                    effectifItem(count: p, label: "participants")
                }
                if let e = camp.encadrantsCount {
                    effectifItem(count: e, label: "encadrants")
                }
            }
        }
    }

    private func effectifItem(count: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            Text("\(count)")
                .font(SGDFTheme.FontStyle.sectionTitle())
                .foregroundStyle(SGDFColors.violet)
            Text(label)
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
        }
    }
}
