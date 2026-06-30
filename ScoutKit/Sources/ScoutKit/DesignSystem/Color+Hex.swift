import SwiftUI

/// Parsing hex centralisé — réservé au Design System.
/// Aucune vue ne doit appeler ceci directement : les couleurs passent par SGDFColors.
public enum SGDFHex {
    /// Convertit "#RRGGBB" ou "RRGGBB" en composantes 0...1. nil si invalide.
    public static func rgb(from hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return (
            r: Double((value >> 16) & 0xff) / 255.0,
            g: Double((value >> 8) & 0xff) / 255.0,
            b: Double(value & 0xff) / 255.0
        )
    }
}

extension Color {
    /// Initialise une couleur depuis un hex SGDF. Fallback magenta visible si invalide
    /// (signale une erreur de charte en développement).
    public init(hex: String) {
        guard let c = SGDFHex.rgb(from: hex) else {
            self = Color(red: 1, green: 0, blue: 1)
            return
        }
        self = Color(red: c.r, green: c.g, blue: c.b)
    }
}
