import Foundation
import ScoutKit

@MainActor
final class ProgramPlanViewModel: ObservableObject {
    @Published var slots: [ProgramSlot] = []
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let programService = ProgramService()
    private let activityService = ActivityService()

    /// Jours du camp ["yyyy-MM-dd", …] de startDate à endDate inclus. Même logique que MealPlanViewModel.
    func days(of camp: Camp) -> [String] {
        guard let s = camp.startDate, let e = camp.endDate,
              let start = SGDFDate.day(from: s), let end = SGDFDate.day(from: e),
              start <= end else { return [] }
        var result: [String] = []
        var d = start
        let cal = Calendar(identifier: .gregorian)
        while d <= end {
            result.append(SGDFDate.string(from: d))
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return result
    }

    /// Créneaux d'une journée, triés par heure de début.
    func slots(on date: String) -> [ProgramSlot] {
        slots
            .filter { $0.date == date }
            .sorted { ($0.startTime ?? "") < ($1.startTime ?? "") }
    }

    func load(campId: String) async {
        isLoading = true; errorMessage = nil
        do {
            async let slotsTask = programService.list(campId: campId)
            async let activitiesTask = activityService.list()
            let (s, a) = try await (slotsTask, activitiesTask)
            slots = s
            activities = a
        } catch {
            errorMessage = "Impossible de charger le planning."
            slots = []
        }
        isLoading = false
    }

    @discardableResult
    func save(campId: String, date: String, existingId: String?,
              title: String, startTime: String?, endTime: String?,
              location: String?, notes: String?,
              activityId: String?) async throws -> ProgramSlot {
        let slot = ProgramSlot(
            id: existingId ?? UUID().uuidString,
            campId: campId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            title: title,
            activityId: activityId,
            location: location,
            notes: notes
        )
        if existingId != nil {
            try await programService.update(slot)
            if let i = slots.firstIndex(where: { $0.id == slot.id }) {
                slots[i] = slot
            }
            return slot
        } else {
            let created = try await programService.create(slot)
            slots.append(created)
            return created
        }
    }

    func delete(_ slot: ProgramSlot) async {
        do {
            try await programService.delete(id: slot.id)
            slots.removeAll { $0.id == slot.id }
        } catch {
            errorMessage = "Suppression impossible : \(error.localizedDescription)"
        }
    }
}
