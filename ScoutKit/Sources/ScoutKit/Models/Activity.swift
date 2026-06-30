import Foundation

public enum ActivityType: String, Codable, CaseIterable, Hashable {
    case jeu
    case grandJeu = "grand_jeu"
    case veillee
    case tempsSpi = "temps_spi"
    case atelier
    case autre

    public var label: String {
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

public struct Activity: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var type: ActivityType?
    public var durationMin: Int?
    public var description: String?
    public var branch: Branch?
    public var materialNotes: String?

    public init(
        id: String,
        name: String,
        type: ActivityType? = nil,
        durationMin: Int? = nil,
        description: String? = nil,
        branch: Branch? = nil,
        materialNotes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.durationMin = durationMin
        self.description = description
        self.branch = branch
        self.materialNotes = materialNotes
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case durationMin  = "duration_min"
        case description, branch
        case materialNotes = "material_notes"
    }
}
