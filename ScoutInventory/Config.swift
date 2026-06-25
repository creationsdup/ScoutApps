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
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4emxsdXpreHlnam9md2dianp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzMTE4MzIsImV4cCI6MjA5Nzg4NzgzMn0.V6UIWzD--UwHM-9eA6JllSSWLe_cvnq5c6Y7YlCpuPs"

    /// Indique si la clé a été renseignée (sinon l'app affiche un message clair).
    static var isConfigured: Bool {
        supabaseAnonKey != "PASTE_YOUR_ANON_KEY_HERE" && !supabaseAnonKey.isEmpty
    }
}
