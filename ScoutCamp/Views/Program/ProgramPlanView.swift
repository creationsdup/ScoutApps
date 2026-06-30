import SwiftUI
import ScoutKit

/// Planning journalier du camp, section Planning de ProgramHomeView.
struct ProgramPlanView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = ProgramPlanViewModel()

    @State private var formTarget: SlotFormTarget?

    /// Cible du formulaire : nouveau créneau (avec sa date) ou édition d'un existant.
    private enum SlotFormTarget: Identifiable {
        case new(date: String)
        case edit(slot: ProgramSlot, date: String)
        var id: String {
            switch self {
            case .new(let d): return "new-\(d)"
            case .edit(let s, _): return s.id
            }
        }
        var date: String {
            switch self {
            case .new(let d): return d
            case .edit(_, let d): return d
            }
        }
        var slot: ProgramSlot? {
            if case .edit(let s, _) = self { return s } else { return nil }
        }
    }

    var body: some View {
        Group {
            if let camp = campStore.selectedCamp {
                let days = viewModel.days(of: camp)
                if days.isEmpty {
                    EmptyStateView(
                        systemImage: "calendar.badge.exclamationmark",
                        title: "Dates manquantes",
                        message: "Renseigne les dates du camp pour planifier."
                    )
                } else {
                    planList(camp: camp, days: days)
                }
            } else {
                EmptyStateView(
                    systemImage: "tent",
                    title: "Aucun camp",
                    message: "Sélectionne un camp."
                )
            }
        }
        .sheet(item: $formTarget) { target in
            if let camp = campStore.selectedCamp {
                ProgramSlotFormView(
                    viewModel: viewModel,
                    campId: camp.id,
                    campStartDate: camp.startDate,
                    campEndDate: camp.endDate,
                    initialDate: target.date,
                    existingSlot: target.slot
                )
            }
        }
        .task {
            if let camp = campStore.selectedCamp {
                await viewModel.load(campId: camp.id)
            }
        }
        .onChange(of: campStore.selectedCampID) { _, newID in
            guard let id = newID else { return }
            Task { await viewModel.load(campId: id) }
        }
    }

    // MARK: - Plan list

    private func planList(camp: Camp, days: [String]) -> some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                }
            }
            ForEach(days, id: \.self) { day in
                daySection(day: day)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isLoading { LoadingView() }
        }
    }

    private func daySection(day: String) -> some View {
        Section {
            dayRows(day: day)
            if session.canWrite {
                addSlotButton(day: day)
            }
        } header: {
            Text(dayLabel(day))
                .font(SGDFTheme.FontStyle.sectionTitle())
                .foregroundStyle(SGDFColors.violet)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private func dayRows(day: String) -> some View {
        let daySlots = viewModel.slots(on: day)
        if daySlots.isEmpty {
            Text("Aucun créneau")
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
        } else {
            ForEach(daySlots) { slot in
                SlotRow(slot: slot)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if session.canWrite {
                            formTarget = .edit(slot: slot, date: day)
                        }
                    }
            }
            .onDelete { indexSet in
                Task {
                    for i in indexSet {
                        await viewModel.delete(daySlots[i])
                    }
                }
            }
            .deleteDisabled(!session.canWrite)
        }
    }

    private func addSlotButton(day: String) -> some View {
        Button {
            formTarget = .new(date: day)
        } label: {
            Label("Ajouter un créneau", systemImage: "plus")
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.orange)
        }
    }

    // MARK: - Formatters

    private static let displayDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private func dayLabel(_ day: String) -> String {
        if let d = SGDFDate.day(from: day) {
            return Self.displayDF.string(from: d).capitalized
        }
        return day
    }
}

// MARK: - SlotRow (private subview — évite les expressions géantes)

private struct SlotRow: View {
    let slot: ProgramSlot

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            SlotRowHeader(slot: slot)
            Text(slot.title)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(SGDFColors.textPrimary)
        }
        .padding(.vertical, SGDFTheme.Spacing.xs)
    }
}

private struct SlotRowHeader: View {
    let slot: ProgramSlot

    private var timeRange: String {
        let start = slot.startTime.map { String($0.prefix(5)) } ?? ""
        let end   = slot.endTime.map   { String($0.prefix(5)) } ?? ""
        if !start.isEmpty && !end.isEmpty { return "\(start)–\(end)" }
        if !start.isEmpty { return start }
        return ""
    }

    var body: some View {
        HStack {
            if !timeRange.isEmpty {
                Text(timeRange)
                    .font(SGDFTheme.FontStyle.caption().weight(.medium))
                    .foregroundStyle(SGDFColors.violet)
            }
            Spacer()
            if let loc = slot.location {
                Text(loc)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
