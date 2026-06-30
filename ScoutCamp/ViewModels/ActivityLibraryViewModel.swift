import Foundation
import ScoutKit

@MainActor
final class ActivityLibraryViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var typeFilter: ActivityType?
    @Published var branchFilter: Branch?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = ActivityService()

    var filtered: [Activity] {
        activities.filter { activity in
            if let t = typeFilter, activity.type != t { return false }
            if let b = branchFilter, activity.branch != b { return false }
            return true
        }
    }

    func load() async {
        isLoading = true; errorMessage = nil
        do { activities = try await service.list() }
        catch { errorMessage = "Impossible de charger les activités."; activities = [] }
        isLoading = false
    }

    func delete(_ activity: Activity) async {
        do {
            try await service.delete(id: activity.id)
            activities.removeAll { $0.id == activity.id }
        } catch {
            errorMessage = "Suppression impossible : \(error.localizedDescription)"
        }
    }
}
