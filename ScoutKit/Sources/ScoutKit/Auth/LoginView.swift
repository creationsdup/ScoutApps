import SwiftUI

/// Écran de connexion ScoutManager (Supabase Auth via le SDK).
struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: SGDFTheme.Spacing.lg) {
                Spacer()
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(SGDFColors.primaryBlue)
                Text("ScoutManager")
                    .font(SGDFTheme.FontStyle.screenTitle())
                    .foregroundStyle(SGDFColors.textPrimary)

                VStack(spacing: SGDFTheme.Spacing.md) {
                    SGDFTextField("Email", text: $email, systemImage: "envelope")
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureFieldRow(text: $password)
                }

                if let error = session.errorMessage {
                    Text(error)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                }

                SGDFButton(isLoggingIn ? "Connexion…" : "Se connecter",
                           kind: .primary, systemImage: "arrow.right.circle") {
                    Task {
                        isLoggingIn = true
                        await session.login(email: email, password: password)
                        isLoggingIn = false
                    }
                }
                .disabled(email.isEmpty || password.isEmpty || isLoggingIn)

                if !Config.isConfigured {
                    Text("Clé Supabase manquante : renseigne Secrets.xcconfig, puis relance.")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(SGDFTheme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SGDFColors.background)
        }
    }
}

/// Champ mot de passe au style SGDF (SecureField encadré comme SGDFTextField).
private struct SecureFieldRow: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.sm) {
            Image(systemName: "lock").foregroundStyle(SGDFColors.textSecondary)
            SecureField("Mot de passe", text: $text)
                .foregroundStyle(SGDFColors.textPrimary)
        }
        .padding(SGDFTheme.Spacing.md)
        .background(SGDFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button))
        .overlay(RoundedRectangle(cornerRadius: SGDFTheme.Radius.button)
            .stroke(SGDFColors.border, lineWidth: 1))
    }
}
