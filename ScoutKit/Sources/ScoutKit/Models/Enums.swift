import Foundation

/// Statut d'un matériel. rawValue = valeur de l'enum Postgres `item_status` (backend
/// partagé avec CampManager). Valeurs anglaises en base, libellés FR à l'affichage.
/// `reserve` et `indisponible` sont ajoutés à l'enum par la migration SQL.
enum ItemStatus: String, Codable, CaseIterable {
    case disponible   = "available"
    case reserve      = "reserve"
    case sorti        = "checked_out"
    case aVerifier    = "cleaning_required"
    case aReparer     = "repair_required"
    case indisponible = "indisponible"
    case perdu        = "missing"
    case archive      = "archived"

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

/// État physique d'un matériel. rawValue = enum Postgres `condition` existant
/// (excellent/good/fair/damaged/broken), conservé tel quel ; libellés FR à l'affichage.
enum ItemCondition: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good      = "good"
    case fair      = "fair"
    case damaged   = "damaged"
    case broken    = "broken"

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good:      return "Bon"
        case .fair:      return "Correct"
        case .damaged:   return "Abîmé"
        case .broken:    return "Cassé"
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

/// Créneau de repas (meals.slot). rawValue = valeur stockée en base.
enum MealSlot: String, Codable, CaseIterable, Hashable {
    case petitDej = "petit_dej"
    case midi
    case gouter
    case diner

    var label: String {
        switch self {
        case .petitDej: return "Petit-déj"
        case .midi:     return "Midi"
        case .gouter:   return "Goûter"
        case .diner:    return "Dîner"
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
