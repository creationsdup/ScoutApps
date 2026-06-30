import Foundation

/// Camp — entité pivot (table `camps`, ajoutée par ScoutManager, backend partagé).
/// Réutilisée par les modules Intendance et Programme. `eventId` = pont optionnel
/// vers `events` (jamais requis) ; le matériel d'un camp = items dont event_id == camp.eventId.
public struct Camp: Codable, Identifiable, Hashable {
    public let id: String
    public var eventId: String?
    public var name: String
    public var location: String?
    public var startDate: String?          // "yyyy-MM-dd"
    public var endDate: String?            // "yyyy-MM-dd"
    public var branch: Branch?
    public var participantsCount: Int?
    public var encadrantsCount: Int?
    public var createdBy: String?

    public init(
        id: String,
        eventId: String? = nil,
        name: String,
        location: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        branch: Branch? = nil,
        participantsCount: Int? = nil,
        encadrantsCount: Int? = nil,
        createdBy: String? = nil
    ) {
        self.id = id
        self.eventId = eventId
        self.name = name
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.branch = branch
        self.participantsCount = participantsCount
        self.encadrantsCount = encadrantsCount
        self.createdBy = createdBy
    }

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
