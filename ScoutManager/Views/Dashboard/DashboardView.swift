import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = DashboardViewModel()
    @State private var initialLoadDone = false

    private let columns = [GridItem(.flexible(), spacing: SGDFTheme.Spacing.md),
                           GridItem(.flexible(), spacing: SGDFTheme.Spacing.md)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.lg) {
                    if let error = viewModel.errorMessage {
                        SGDFCard {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(SGDFColors.red)
                                .font(SGDFTheme.FontStyle.body())
                        }
                    }

                    LazyVGrid(columns: columns, spacing: SGDFTheme.Spacing.md) {
                        StatCard(value: viewModel.stats.total, title: "Total",
                                 systemImage: "shippingbox.fill", accent: SGDFColors.primaryBlue)
                        StatCard(value: viewModel.stats.available, title: "Disponibles",
                                 systemImage: "checkmark.circle.fill", accent: StatusColorMapper.color(for: .disponible))
                        StatCard(value: viewModel.stats.checkedOut, title: "Sortis",
                                 systemImage: "arrow.up.right.circle.fill", accent: StatusColorMapper.color(for: .sorti))
                        StatCard(value: viewModel.stats.toRepair, title: "À réparer",
                                 systemImage: "wrench.adjustable.fill", accent: StatusColorMapper.color(for: .aReparer))
                    }

                    Text("Raccourcis")
                        .font(SGDFTheme.FontStyle.sectionTitle())
                        .foregroundStyle(SGDFColors.textPrimary)

                    VStack(spacing: SGDFTheme.Spacing.md) {
                        SGDFButton("Ajouter matériel", kind: .quickAction, systemImage: "plus") {
                            router.selectedTab = .material
                        }
                        SGDFButton("Scanner un QR", kind: .primary, systemImage: "qrcode.viewfinder") {
                            router.selectedTab = .scan
                        }
                    }
                }
                .padding(SGDFTheme.Spacing.md)
            }
            .background(SGDFColors.background)
            .navigationTitle("Tableau de bord")
            // Overlay plein écran seulement au premier chargement ; le pull-to-refresh
            // a déjà son propre indicateur natif.
            .overlay { if viewModel.isLoading && !initialLoadDone { LoadingView() } }
            .task {
                await viewModel.load()
                initialLoadDone = true
            }
            .refreshable { await viewModel.load() }
        }
    }
}

/// Carte statistique : grand chiffre + libellé + accent coloré.
private struct StatCard: View {
    let value: Int
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        SGDFCard {
            HStack {
                Image(systemName: systemImage).foregroundStyle(accent)
                Spacer()
                Text("\(value)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(SGDFColors.textPrimary)
            }
            Text(title)
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(SGDFColors.textSecondary)
        }
    }
}
