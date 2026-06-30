import Foundation
import Supabase
import CoreImage.CIFilterBuiltins
import UIKit

/// Lookup / association d'étiquettes (table qr_tags) + génération d'images QR.
struct QRCodeService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Assign update payload

    private struct AssignPayload: Encodable {
        let assigned_item_id: String
        let status: String
    }

    // MARK: - Tag lookup / assignment

    /// Recherche une étiquette par code (TAG-000001).
    func tag(byCode code: String) async throws -> QRCode? {
        let rows: [QRCode] = try await client.from("qr_tags")
            .select().eq("tag_code", value: code).limit(1).execute().value
        return rows.first
    }

    /// Étiquette associée à un matériel (qr_tags.assigned_item_id), si elle existe.
    func tag(forItemId id: String) async throws -> QRCode? {
        let rows: [QRCode] = try await client.from("qr_tags")
            .select().eq("assigned_item_id", value: id).limit(1).execute().value
        return rows.first
    }

    /// Associe une étiquette vierge à un matériel.
    func assign(tagCode: String, toItem itemId: String) async throws {
        let payload = AssignPayload(
            assigned_item_id: itemId,
            status: QRCodeStatus.assigned.rawValue
        )
        try await client.from("qr_tags")
            .update(payload).eq("tag_code", value: tagCode).execute()
    }

    // MARK: - QR image generation

    /// Génère une image QR (CoreImage) pour un code donné.
    func generateImage(for code: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(code.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
