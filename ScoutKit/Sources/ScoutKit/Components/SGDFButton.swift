import SwiftUI

public enum SGDFButtonStyleKind { case primary, quickAction, secondary }

/// Bouton SGDF. primary = bleu, quickAction = orange (actions rapides), secondary = contour.
public struct SGDFButton: View {
    let title: String
    var kind: SGDFButtonStyleKind = .primary
    var systemImage: String? = nil
    let action: () -> Void

    public init(_ title: String, kind: SGDFButtonStyleKind = .primary,
         systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.kind = kind; self.systemImage = systemImage; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SGDFTheme.Spacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.system(.body, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: SGDFTheme.buttonMinHeight)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: SGDFTheme.Radius.button)
                    .stroke(SGDFColors.primaryBlue, lineWidth: kind == .secondary ? 1.5 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button))
        }
    }

    private var background: Color {
        switch kind {
        case .primary:     return SGDFColors.primaryBlue
        case .quickAction: return SGDFColors.orange
        case .secondary:   return SGDFColors.surface
        }
    }
    private var foreground: Color {
        switch kind {
        case .primary, .quickAction: return SGDFColors.onColor
        case .secondary:             return SGDFColors.primaryBlue
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SGDFButton("Ajouter matériel", kind: .quickAction, systemImage: "plus") {}
        SGDFButton("Scanner", kind: .primary, systemImage: "qrcode.viewfinder") {}
        SGDFButton("Annuler", kind: .secondary) {}
    }.padding().background(SGDFColors.background)
}
