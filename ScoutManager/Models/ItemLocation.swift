import Foundation

/// Lieu de stockage — table `locations`.
struct ItemLocation: Codable, Identifiable, Hashable {
    let id: String
    var name: String
}
