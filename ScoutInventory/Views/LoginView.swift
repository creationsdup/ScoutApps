import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Mot de passe", text: $password)
                        .textContentType(.password)
                }

                if let error = appState.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task {
                            isLoggingIn = true
                            await appState.login(email: email, password: password)
                            isLoggingIn = false
                        }
                    } label: {
                        HStack {
                            if isLoggingIn { ProgressView() }
                            Text("Se connecter")
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                }

                if !Config.isConfigured {
                    Section {
                        Text("Clé Supabase manquante : renseigne Config.supabaseAnonKey, puis relance.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Scout Inventaire")
        }
    }
}
