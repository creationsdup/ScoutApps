import Foundation

/// Statut d'une étiquette QR (qr_tags.status).
public enum QRCodeStatus: String, Codable {
    case unassigned, assigned, disabled
}

/// Étiquette QR — mappée sur la table `qr_tags` existante.
public struct QRCode: Codable, Identifiable, Hashable {
    public let id: String
    public var tagCode: String
    public var status: QRCodeStatus
    public var assignedItemId: String?

    public init(
        id: String,
        tagCode: String,
        status: QRCodeStatus,
        assignedItemId: String? = nil
    ) {
        self.id = id
        self.tagCode = tagCode
        self.status = status
        self.assignedItemId = assignedItemId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tagCode = "tag_code"
        case status
        case assignedItemId = "assigned_item_id"
    }
}

/// Validation du format de code inventaire / tag : PRÉFIXE (2-4 lettres) + "-" + 4 chiffres.
/// Ex. "TEN-0001". Le préfixe est le code de la catégorie.
public enum TagCode {
    public static func parse(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.range(of: "^[A-Z]{2,4}-\\d{4}$", options: .regularExpression) != nil else { return nil }
        return trimmed
    }
}
