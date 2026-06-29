import SwiftUI

/// Badge de statut. Couleur issue exclusivement de StatusColorMapper.
struct SGDFBadge: View {
    let status: SGDFItemStatus
    var body: some View {
        Text(status.label)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .padding(.horizontal, SGDFTheme.Spacing.sm)
            .padding(.vertical, SGDFTheme.Spacing.xs)
            .foregroundStyle(.white)
            .background(StatusColorMapper.color(for: status))
            .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.badge))
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(SGDFItemStatus.allCases, id: \.self) { SGDFBadge(status: $0) }
    }.padding().background(SGDFColors.background)
}
