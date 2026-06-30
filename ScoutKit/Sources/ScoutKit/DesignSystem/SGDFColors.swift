import SwiftUI

/// Source UNIQUE de couleur de l'app. Aucune vue n'écrit un hex ou une Color système.
/// Charte SGDF — ne jamais ajouter une couleur forte hors palette.
public enum SGDFColors {
    // Couleur principale
    public static let primaryBlue = Color(hex: "#003a5d")

    // Secondaires
    public static let orange      = Color(hex: "#ff8300")
    public static let lightBlue   = Color(hex: "#0077b3")
    public static let red         = Color(hex: "#d03f15")
    public static let green       = Color(hex: "#007254")
    public static let lightGreen  = Color(hex: "#65bc99")
    public static let violet      = Color(hex: "#6e74aa")

    // Neutres interface
    public static let background    = Color(hex: "#F7F8FA")
    public static let surface       = Color(hex: "#FFFFFF")
    public static let border        = Color(hex: "#E3E6EB")
    public static let textPrimary   = Color(hex: "#003a5d")
    public static let textSecondary = Color(hex: "#5B6B7A")

    /// Texte/icône sur un fond coloré fort (bouton primaire, badge). Blanc charté.
    public static let onColor       = Color(hex: "#FFFFFF")

    /// Transparence totale (usage : listRowBackground, overlays vides).
    public static let clear         = Color.clear
}
