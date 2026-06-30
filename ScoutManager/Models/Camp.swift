import Foundation

/// Camp — entité pivot (table `camps`, ajoutée par ScoutManager, backend partagé).
/// Réutilisée par les modules Intendance et Programme. `eventId` = pont optionnel
/// vers `events` (jamais requis) ; le matériel d'un camp = items dont event_id == camp.eventId.
struct Camp: Codable, Identifiable, Hashable {
    let id: String
    var eventId: String?
    var name: String
    var location: String?
    var startDate: String?          // "yyyy-MM-dd"
    var endDate: String?            // "yyyy-MM-dd"
    var branch: Branch?
    var participantsCount: Int?
    var encadrantsCount: Int?
    var createdBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case name, location
        case startDate = "start_date"
        case endDate = "end_date"
        case branch
        case participantsCount = "participants_count"
        case encadrantsCount = "encadrants_count"
        case createdBy = "created_by"
    }
}
