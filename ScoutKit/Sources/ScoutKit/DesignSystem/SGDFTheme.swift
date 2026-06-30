import SwiftUI

/// Constantes de style SGDF : espacements, rayons, typographies, tint global.
/// Usage terrain : boutons grands, lisibilité forte, beaucoup de blanc.
public enum SGDFTheme {
    public static let tint = SGDFColors.primaryBlue

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum Radius {
        public static let card: CGFloat = 16
        public static let button: CGFloat = 12
        public static let badge: CGFloat = 8
    }

    /// Hauteur mini des boutons tactiles (usage gants/terrain).
    public static let buttonMinHeight: CGFloat = 52

    public enum FontStyle {
        public static func screenTitle() -> Font { .system(.largeTitle, design: .rounded).weight(.bold) }
        public static func sectionTitle() -> Font { .system(.title3, design: .rounded).weight(.semibold) }
        public static func body() -> Font { .system(.body) }
        public static func caption() -> Font { .system(.caption) }
    }
}
