import Foundation

/// Statut d'un matériel. rawValue = valeur en base (inventory_items.status).
enum ItemStatus: String, Codable, CaseIterable {
    case disponible   = "disponible"
    case reserve      = "reserve"
    case sorti        = "sorti"
    case aVerifier    = "a_verifier"
    case aReparer     = "a_reparer"
    case indisponible = "indisponible"
    case perdu        = "perdu"
    case archive      = "archive"

    var label: String {
        switch self {
        case .disponible:   return "Disponible"
        case .reserve:      return "Réservé"
        case .sorti:        return "Sorti"
        case .aVerifier:    return "À vérifier"
        case .aReparer:     return "À réparer"
        case .indisponible: return "Indisponible"
        case .perdu:        return "Perdu"
        case .archive:      return "Archivé"
        }
    }
}

/// État physique d'un matériel (inventory_items.condition).
enum ItemCondition: String, Codable, CaseIterable {
    case neuf, bon, moyen, mauvais
    var label: String {
        switch self {
        case .neuf: return "Neuf"
        case .bon: return "Bon"
        case .moyen: return "Moyen"
        case .mauvais: return "Mauvais"
        }
    }
}

/// Type de suivi (inventory_items.tracking_type).
enum TrackingType: String, Codable, CaseIterable {
    case global, specifique
    var label: String { self == .global ? "Global (quantité)" : "Spécifique (individuel)" }
}

/// Branche SGDF (inventory_items.branch).
enum Branch: String, Codable, CaseIterable {
    case lj = "LJ", sg = "SG", pc = "PC", groupe = "Groupe"
    var label: String {
        switch self {
        case .lj: return "Louveteaux / Jeannettes"
        case .sg: return "Scouts / Guides"
        case .pc: return "Pionniers / Caravelles"
        case .groupe: return "Groupe"
        }
    }
}

/// Rôle utilisateur (profiles.role). Repris du legacy Domain.swift.
enum UserRole: String, Codable {
    case admin, manager, member, viewer
    /// Rôles autorisés à écrire l'inventaire (cf. RLS can_write_inventory).
    var canWrite: Bool {
        switch self {
        case .admin, .manager, .member: return true
        case .viewer: return false
        }
    }
}
