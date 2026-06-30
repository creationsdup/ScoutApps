import SwiftUI

/// Mapping statut → couleur SGDF. Source unique pour badges/cartes/indicateurs.
/// Ne jamais colorer un statut à la main dans une vue.
public enum StatusColorMapper {
    public static func color(for status: ItemStatus) -> Color {
        switch status {
        case .disponible:   return SGDFColors.lightGreen
        case .reserve:      return SGDFColors.violet
        case .sorti:        return SGDFColors.orange
        case .aVerifier:    return SGDFColors.orange
        case .aReparer:     return SGDFColors.red
        case .indisponible: return SGDFColors.red
        case .perdu:        return SGDFColors.red
        case .archive:      return SGDFColors.textSecondary
        }
    }
}
