import Foundation

/// Configuration Supabase. Le même backend que CampManager (web/mobile Expo).
///
/// La clé `anon` est conçue pour être embarquée dans un client : la sécurité
/// est assurée par les politiques RLS côté Postgres, pas par le secret de la clé.
/// Elle est néanmoins gardée hors du dépôt git : on la renseigne dans
/// `Secrets.xcconfig` (cf. `Secrets.example.xcconfig`), injectée dans l'Info.plist
/// à la compilation et lue ici à l'exécution.
public enum Config {
    /// URL du projet Supabase.
    public static let supabaseURL = URL(string: "https://vxzlluzkxygjofwgbjzu.supabase.co")!

    /// Clé publique `anon`, injectée depuis `Secrets.xcconfig` via l'Info.plist.
    public static let supabaseAnonKey: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        return value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }()

    /// Indique si la clé a été renseignée (sinon l'app affiche un message clair).
    public static var isConfigured: Bool {
        !supabaseAnonKey.isEmpty && supabaseAnonKey != "PASTE_YOUR_ANON_KEY_HERE"
    }
}
