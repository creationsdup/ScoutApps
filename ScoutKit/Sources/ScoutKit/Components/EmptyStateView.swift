import SwiftUI

public struct EmptyStateView: View {
    public let systemImage: String
    public let title: String
    public let message: String

    public init(systemImage: String, title: String, message: String) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: SGDFTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(SGDFColors.primaryBlue)
            Text(title)
                .font(SGDFTheme.FontStyle.sectionTitle())
                .foregroundStyle(SGDFColors.textPrimary)
            Text(message)
                .font(SGDFTheme.FontStyle.body())
                .foregroundStyle(SGDFColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(SGDFTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGDFColors.background)
    }
}
