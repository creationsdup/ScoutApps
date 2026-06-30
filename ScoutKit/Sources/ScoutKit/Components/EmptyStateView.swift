import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var body: some View {
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
