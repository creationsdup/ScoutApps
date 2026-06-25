import Foundation

/// Configuration Supabase. Le même backend que CampManager (web/mobile Expo).
///
/// La clé `anon` est conçue pour être embarquée dans un client : la sécurité
/// est assurée par les politiques RLS côté Postgres, pas par le secret de la clé.
/// Récupère-la depuis `CampManager/apps/web/.env.local`
/// (`NEXT_PUBLIC_SUPABASE_ANON_KEY`) et colle-la ci-dessous.
enum Config {
    /// URL du projet Supabase (déjà renseignée depuis ton .env.local).
    static let supabaseURL = URL(string: "https://vxzlluzkxygjofwgbjzu.supabase.co")!

    /// Clé publique `anon`. À coller depuis NEXT_PUBLIC_SUPABASE_ANON_KEY.
    static let supabaseAnonKey = "PASTE_YOUR_ANON_KEY_HERE"

    /// Indique si la clé a été renseignée (sinon l'app affiche un message clair).
    static var isConfigured: Bool {
        supabaseAnonKey != "PASTE_YOUR_ANON_KEY_HERE" && !supabaseAnonKey.isEmpty
    }
}
