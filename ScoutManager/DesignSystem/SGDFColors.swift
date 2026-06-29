import SwiftUI

/// Source UNIQUE de couleur de l'app. Aucune vue n'écrit un hex ou une Color système.
/// Charte SGDF — ne jamais ajouter une couleur forte hors palette.
enum SGDFColors {
    // Couleur principale
    static let primaryBlue = Color(hex: "#003a5d")

    // Secondaires
    static let orange      = Color(hex: "#ff8300")
    static let lightBlue   = Color(hex: "#0077b3")
    static let red         = Color(hex: "#d03f15")
    static let green       = Color(hex: "#007254")
    static let lightGreen  = Color(hex: "#65bc99")
    static let violet      = Color(hex: "#6e74aa")

    // Neutres interface
    static let background    = Color(hex: "#F7F8FA")
    static let surface       = Color(hex: "#FFFFFF")
    static let border        = Color(hex: "#E3E6EB")
    static let textPrimary   = Color(hex: "#003a5d")
    static let textSecondary = Color(hex: "#5B6B7A")
}
