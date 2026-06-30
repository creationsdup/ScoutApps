import SwiftUI

/// Carte arrondie : surface blanche, bordure très claire, coins arrondis.
public struct SGDFCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm, content: content)
            .padding(SGDFTheme.Spacing.md)
            .background(SGDFColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SGDFTheme.Radius.card)
                    .stroke(SGDFColors.border, lineWidth: 1)
            )
    }
}
