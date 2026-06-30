import SwiftUI
import ScoutKit

struct DashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = DashboardViewModel()
    @State private var initialLoadDone = false
    @State private var showInventory = false

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
                        StatCard(value: viewModel.snapshot.total, title: "Total",
                                 systemImage: "shippingbox.fill", accent: SGDFColors.primaryBlue)
                        StatCard(value: viewModel.snapshot.available, title: "Disponibles",
                                 systemImage: "checkmark.circle.fill", accent: StatusColorMapper.color(for: .disponible))
                        StatCard(value: viewModel.snapshot.checkedOut, title: "Sortis",
                                 systemImage: "arrow.up.right.circle.fill", accent: StatusColorMapper.color(for: .sorti))
                        StatCard(value: viewModel.snapshot.toRepair, title: "À réparer",
                                 systemImage: "wrench.adjustable.fill", accent: StatusColorMapper.color(for: .aReparer))
                    }

                    if !viewModel.snapshot.alerts.isEmpty {
                        Text("Alertes")
                            .font(SGDFTheme.FontStyle.sectionTitle())
                            .foregroundStyle(SGDFColors.textPrimary)
                        VStack(spacing: SGDFTheme.Spacing.sm) {
                            ForEach(viewModel.snapshot.alerts) { alert in
                                NavigationLink {
                                    AlertItemsListView(title: alert.kind.label, items: alert.items)
                                } label: {
                                    AlertCard(alert: alert)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !viewModel.snapshot.ongoingCheckouts.isEmpty || !viewModel.snapshot.ongoingCamps.isEmpty {
                        Text("Sorties en cours")
                            .font(SGDFTheme.FontStyle.sectionTitle())
                            .foregroundStyle(SGDFColors.textPrimary)
                        VStack(spacing: SGDFTheme.Spacing.sm) {
                            ForEach(viewModel.snapshot.ongoingCheckouts) { ongoing in
                                NavigationLink {
                                    CheckoutDetailView(checkout: ongoing.checkout)
                                } label: {
                                    OngoingCheckoutCard(ongoing: ongoing)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(viewModel.snapshot.ongoingCamps) { camp in
                                NavigationLink {
                                    AlertItemsListView(title: camp.camp.name, items: camp.items)
                                } label: {
                                    OngoingCampCard(ongoing: camp)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Actions rapides")
                        .font(SGDFTheme.FontStyle.sectionTitle())
                        .foregroundStyle(SGDFColors.textPrimary)

                    VStack(spacing: SGDFTheme.Spacing.md) {
                        SGDFButton("Ajouter matériel", kind: .quickAction, systemImage: "plus") {
                            router.selectedTab = .material
                        }
                        SGDFButton("Scanner un QR", kind: .primary, systemImage: "qrcode.viewfinder") {
                            router.selectedTab = .scan
                        }
                        SGDFButton("Préparer une sortie", kind: .secondary, systemImage: "arrow.up.bin") {
                            router.selectedTab = .sorties
                        }
                        SGDFButton("Inventaire rapide", kind: .secondary, systemImage: "checklist") {
                            showInventory = true
                        }
                        SGDFButton("Signaler une réparation", kind: .secondary, systemImage: "wrench.adjustable") {
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
            .fullScreenCover(isPresented: $showInventory) { InventoryView() }
        }
    }
}

/// Carte d'alerte : icône + libellé + nombre, couleur selon le type (rôle charte).
private struct AlertCard: View {
    let alert: DashboardAlert

    private var color: Color {
        switch alert.kind {
        case .checkedOutOver7d, .lowStock, .toVerify: return SGDFColors.orange
        case .toRepair, .missingQR:                   return SGDFColors.red
        case .missingPhoto:                           return SGDFColors.textSecondary
        }
    }

    var body: some View {
        SGDFCard {
            HStack(spacing: SGDFTheme.Spacing.md) {
                Image(systemName: alert.kind.systemImage)
                    .foregroundStyle(color)
                Text(alert.kind.label)
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textPrimary)
                Spacer()
                Text("\(alert.items.count)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(color)
                Image(systemName: "chevron.right")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
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

/// Carte d'un bon de sortie ouvert : libellé, date, nb objets, taux de retour, badge.
private struct OngoingCheckoutCard: View {
    let ongoing: OngoingCheckout

    private var rate: Int { Int((ongoing.returnRate * 100).rounded()) }

    var body: some View {
        SGDFCard {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                HStack {
                    Text(ongoing.checkout.label)
                        .font(SGDFTheme.FontStyle.body().weight(.semibold))
                        .foregroundStyle(SGDFColors.textPrimary)
                    Spacer()
                    Text("Ouvert")
                        .font(SGDFTheme.FontStyle.caption().weight(.semibold))
                        .foregroundStyle(SGDFColors.orange)
                }
                if let createdAt = ongoing.checkout.createdAt {
                    Text(SGDFDate.displayShort(String(createdAt.prefix(10))))
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
                Text("\(ongoing.returnedItems)/\(ongoing.totalItems) rendus — \(rate) %")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
    }
}

/// Carte d'un camp détenant du matériel (pont ScoutCamp).
private struct OngoingCampCard: View {
    let ongoing: OngoingCamp

    private var dateRange: String? {
        switch (ongoing.camp.startDate, ongoing.camp.endDate) {
        case let (start?, end?): return "\(SGDFDate.displayShort(start)) – \(SGDFDate.displayShort(end))"
        case let (start?, nil):  return SGDFDate.displayShort(start)
        case let (nil, end?):    return SGDFDate.displayShort(end)
        default:                 return nil
        }
    }

    var body: some View {
        SGDFCard {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                HStack {
                    Text(ongoing.camp.name)
                        .font(SGDFTheme.FontStyle.body().weight(.semibold))
                        .foregroundStyle(SGDFColors.textPrimary)
                    Spacer()
                    Text("Camp")
                        .font(SGDFTheme.FontStyle.caption().weight(.semibold))
                        .foregroundStyle(SGDFColors.violet)
                }
                HStack(spacing: SGDFTheme.Spacing.sm) {
                    if let dateRange {
                        Text(dateRange)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                    if let branch = ongoing.camp.branch {
                        Text(branch.label)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                }
                Text("\(ongoing.itemCount) objet\(ongoing.itemCount > 1 ? "s" : "")")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
    }
}

/// Liste auto-suffisante des objets d'une alerte ; chaque ligne pousse la fiche détail.
struct AlertItemsListView: View {
    let title: String
    let items: [Item]
    @StateObject private var materialVM = MaterialListViewModel()

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    MaterialDetailView(item: item, listViewModel: materialVM)
                } label: {
                    VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                        Text(item.name)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(SGDFColors.textPrimary)
                        HStack {
                            Text(item.inventoryCode)
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                            Spacer()
                            SGDFBadge(status: item.status)
                        }
                    }
                    .padding(.vertical, SGDFTheme.Spacing.xs)
                }
            }
        }
        .listStyle(.plain)
        .background(SGDFColors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await materialVM.loadReferentials() }
    }
}
