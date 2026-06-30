import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = MealPlanViewModel()

    @State private var editingCell: MealCell?

    /// Cellule (jour × créneau) en cours d'édition. Identifiable pour `.sheet(item:)`.
    private struct MealCell: Identifiable {
        let date: String
        let slot: MealSlot
        var id: String { "\(date)|\(slot.rawValue)" }
    }

    // Formatter pour afficher les jours en FR (ex. « Lun 12 juil. »)
    private static let displayDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    var body: some View {
        Group {
            if let camp = campStore.selectedCamp {
                let days = viewModel.days(of: camp)
                if days.isEmpty {
                    EmptyStateView(
                        systemImage: "calendar",
                        title: "Dates manquantes",
                        message: "Renseigne les dates de début et de fin du camp pour planifier les repas."
                    )
                } else {
                    mealGrid(camp: camp, days: days)
                }
            } else {
                EmptyStateView(
                    systemImage: "tent",
                    title: "Aucun camp",
                    message: "Sélectionne un camp dans l'onglet Intendance."
                )
            }
        }
        .navigationTitle("Menus")
        .task {
            if let camp = campStore.selectedCamp {
                await viewModel.load(campId: camp.id)
            }
        }
        .onChange(of: campStore.selectedCampID) { _, newID in
            guard let id = newID else { return }
            Task { await viewModel.load(campId: id) }
        }
        .sheet(item: $editingCell) { cell in
            if let camp = campStore.selectedCamp {
                MealEditorView(
                    viewModel: viewModel,
                    campId: camp.id,
                    date: cell.date,
                    slot: cell.slot,
                    existingMeal: viewModel.meal(date: cell.date, slot: cell.slot)
                )
            }
        }
    }

    private func mealGrid(camp: Camp, days: [String]) -> some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                }
            }

            ForEach(days, id: \.self) { day in
                Section(header: Text(dayLabel(day))
                    .font(SGDFTheme.FontStyle.sectionTitle())
                    .foregroundStyle(SGDFColors.textPrimary)
                ) {
                    ForEach(MealSlot.allCases, id: \.self) { slot in
                        mealRow(day: day, slot: slot)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isLoading {
                LoadingView()
            }
        }
    }

    private func mealRow(day: String, slot: MealSlot) -> some View {
        let meal = viewModel.meal(date: day, slot: slot)
        return Button {
            guard session.canWrite else { return }
            editingCell = MealCell(date: day, slot: slot)
        } label: {
            HStack {
                Text(slot.label)
                    .font(SGDFTheme.FontStyle.body().weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                    .frame(width: 80, alignment: .leading)
                Spacer()
                if let title = meal?.title, !title.isEmpty {
                    Text(title)
                        .font(SGDFTheme.FontStyle.body())
                        .foregroundStyle(SGDFColors.textPrimary)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .font(SGDFTheme.FontStyle.body())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
                if session.canWrite {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            }
        }
        .disabled(!session.canWrite)
        .buttonStyle(.plain)
    }

    private func dayLabel(_ day: String) -> String {
        if let d = SGDFDate.day(from: day) {
            return Self.displayDF.string(from: d).capitalized
        }
        return day
    }
}
