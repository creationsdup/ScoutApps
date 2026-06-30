import Foundation

/// Créneau du planning d'un camp.
/// `startTime`/`endTime` : Postgres `time` renvoie "HH:MM:SS" — tronque à 5 chars pour affichage.
/// On envoie "HH:mm" à l'insert (Postgres l'accepte).
public struct ProgramSlot: Codable, Identifiable, Hashable {
    public let id: String
    public var campId: String
    public var date: String        // "yyyy-MM-dd"
    public var startTime: String?  // "HH:mm" (ou "HH:MM:SS" retourné par Postgres)
    public var endTime: String?    // "HH:mm" (ou "HH:MM:SS" retourné par Postgres)
    public var title: String
    public var activityId: String?
    public var location: String?
    public var notes: String?

    public init(
        id: String,
        campId: String,
        date: String,
        startTime: String? = nil,
        endTime: String? = nil,
        title: String,
        activityId: String? = nil,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.campId = campId
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.activityId = activityId
        self.location = location
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case campId     = "camp_id"
        case date
        case startTime  = "start_time"
        case endTime    = "end_time"
        case title
        case activityId = "activity_id"
        case location, notes
    }
}
