import SwiftUI

struct SGDFTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil

    init(_ placeholder: String, text: Binding<String>, systemImage: String? = nil) {
        self.placeholder = placeholder; self._text = text; self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(SGDFColors.textSecondary)
            }
            TextField(placeholder, text: $text)
                .foregroundStyle(SGDFColors.textPrimary)
        }
        .padding(SGDFTheme.Spacing.md)
        .background(SGDFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button))
        .overlay(
            RoundedRectangle(cornerRadius: SGDFTheme.Radius.button)
                .stroke(SGDFColors.border, lineWidth: 1)
        )
    }
}
