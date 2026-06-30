import SwiftUI
import ScoutKit

/// Affiche (et permet de partager) le QR correspondant à un code d'étiquette.
struct QRCodeGeneratorView: View {
    let code: String
    @Environment(\.dismiss) private var dismiss
    private let qrService = QRCodeService()

    var body: some View {
        NavigationStack {
            VStack(spacing: SGDFTheme.Spacing.lg) {
                if let uiImage = qrService.generateImage(for: code) {
                    Image(uiImage: uiImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                        .padding(SGDFTheme.Spacing.md)
                        .background(SGDFColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
                        .overlay(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card)
                            .stroke(SGDFColors.border, lineWidth: 1))

                    Text(code)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(SGDFColors.textPrimary)

                    ShareLink(item: Image(uiImage: uiImage),
                              preview: SharePreview(code, image: Image(uiImage: uiImage))) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(SGDFColors.onColor)
                            .frame(maxWidth: .infinity, minHeight: SGDFTheme.buttonMinHeight)
                            .background(SGDFColors.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button))
                    }
                } else {
                    EmptyStateView(systemImage: "qrcode",
                                   title: "QR indisponible",
                                   message: "Impossible de générer le code.")
                }
                Spacer()
            }
            .padding(SGDFTheme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SGDFColors.background)
            .navigationTitle("QR — \(code)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
