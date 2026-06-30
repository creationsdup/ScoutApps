import Foundation

enum ActivityType: String, Codable, CaseIterable, Hashable {
    case jeu
    case grandJeu = "grand_jeu"
    case veillee
    case tempsSpi = "temps_spi"
    case atelier
    case autre

    var label: String {
        switch self {
        case .jeu:      return "Jeu"
        case .grandJeu: return "Grand jeu"
        case .veillee:  return "Veillée"
        case .tempsSpi: return "Temps spi"
        case .atelier:  return "Atelier"
        case .autre:    return "Autre"
        }
    }
}

struct Activity: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: ActivityType?
    var durationMin: Int?
    var description: String?
    var branch: Branch?
    var materialNotes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case durationMin  = "duration_min"
        case description, branch
        case materialNotes = "material_notes"
    }
}
