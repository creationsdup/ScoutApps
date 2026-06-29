import Foundation

/// Statut d'un matériel (domaine SGDF). rawValue = valeur stockée en base (snake_case).
/// Renommé SGDFItemStatus pour éviter le conflit avec ItemStatus de ScoutInventory/Models/Domain.swift
/// (même cible Xcode, même module).
enum SGDFItemStatus: String, Codable, CaseIterable {
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
