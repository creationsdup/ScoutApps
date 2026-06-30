import Foundation

// Conformance partagée : permet `.sheet(item:)` sur une `String?` (ex. code de tag QR).
// Définie une seule fois dans ScoutKit, disponible aux deux apps.
extension String: @retroactive Identifiable {
    public var id: String { self }
}
