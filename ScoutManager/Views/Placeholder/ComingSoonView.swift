import SwiftUI

/// Écran « Bientôt » pour les onglets non encore livrés (Dashboard, Matériel, Scan,
/// Intendance, Camp en MVP-1).
struct ComingSoonView: View {
    let title: String
    var body: some View {
        NavigationStack {
            EmptyStateView(systemImage: "hammer.fill",
                           title: "Bientôt disponible",
                           message: "Ce module arrive dans une prochaine étape.")
                .navigationTitle(title)
        }
    }
}
