import Foundation

/// Statut d'une étiquette QR (qr_tags.status).
enum QRCodeStatus: String, Codable {
    case unassigned, assigned, disabled
}

/// Étiquette QR — mappée sur la table `qr_tags` existante.
struct QRCode: Codable, Identifiable, Hashable {
    let id: String
    var tagCode: String
    var status: QRCodeStatus
    var assignedItemId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tagCode = "tag_code"
        case status
        case assignedItemId = "assigned_item_id"
    }
}

/// Validation du format d'étiquette (TAG-000001) — miroir de l'ancien parseTagCode.
enum TagCode {
    static func parse(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.range(of: "^TAG-\\d{6}$", options: .regularExpression) != nil else { return nil }
        return trimmed
    }
}
