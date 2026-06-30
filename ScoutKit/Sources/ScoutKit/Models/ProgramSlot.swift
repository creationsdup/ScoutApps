import Foundation

/// Créneau du planning d'un camp.
/// `startTime`/`endTime` : Postgres `time` renvoie "HH:MM:SS" — tronque à 5 chars pour affichage.
/// On envoie "HH:mm" à l'insert (Postgres l'accepte).
struct ProgramSlot: Codable, Identifiable, Hashable {
    let id: String
    var campId: String
    var date: String        // "yyyy-MM-dd"
    var startTime: String?  // "HH:mm" (ou "HH:MM:SS" retourné par Postgres)
    var endTime: String?    // "HH:mm" (ou "HH:MM:SS" retourné par Postgres)
    var title: String
    var activityId: String?
    var location: String?
    var notes: String?

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
