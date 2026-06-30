import SwiftUI

public struct LoadingView: View {
    public let message: String

    public init(_ message: String = "Chargement…") { self.message = message }

    public var body: some View {
        VStack(spacing: SGDFTheme.Spacing.md) {
            ProgressView().tint(SGDFColors.primaryBlue)
            Text(message)
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGDFColors.background)
    }
}
