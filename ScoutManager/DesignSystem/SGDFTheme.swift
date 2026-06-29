import SwiftUI

/// Constantes de style SGDF : espacements, rayons, typographies, tint global.
/// Usage terrain : boutons grands, lisibilité forte, beaucoup de blanc.
enum SGDFTheme {
    static let tint = SGDFColors.primaryBlue

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let badge: CGFloat = 8
    }

    /// Hauteur mini des boutons tactiles (usage gants/terrain).
    static let buttonMinHeight: CGFloat = 52

    enum FontStyle {
        static func screenTitle() -> Font { .system(.largeTitle, design: .rounded).weight(.bold) }
        static func sectionTitle() -> Font { .system(.title3, design: .rounded).weight(.semibold) }
        static func body() -> Font { .system(.body) }
        static func caption() -> Font { .system(.caption) }
    }
}
