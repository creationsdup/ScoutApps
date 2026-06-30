import SwiftUI
import ScoutKit

struct CheckoutListView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = CheckoutListViewModel()
    @State private var showCart = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    LoadingView()
                } else if let err = vm.errorMessage {
                    Text(err)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                        .padding()
                } else if vm.checkouts.isEmpty {
                    EmptyStateView(
                        systemImage: "arrow.up.bin",
                        title: "Aucune sortie",
                        message: "Crée un bon de sortie."
                    )
                } else {
                    checkoutList
                }
            }
            .navigationTitle("Sorties")
            .toolbar {
                if session.canWrite {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCart = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(SGDFColors.primaryBlue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCart) {
                CheckoutCartView {
                    Task { await vm.load() }
                }
            }
            .task { await vm.load() }
        }
    }

    // MARK: - List

    private var checkoutList: some View {
        List(vm.checkouts) { checkout in
            NavigationLink(destination: CheckoutDetailView(checkout: checkout)) {
                CheckoutRow(checkout: checkout)
            }
        }
        .listStyle(.insetGrouped)
        .background(SGDFColors.background)
    }
}

// MARK: - Row

private struct CheckoutRow: View {
    let checkout: Checkout

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var formattedDate: String? {
        guard let str = checkout.createdAt else { return nil }
        // ISO8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: str) {
            return Self.dateFormatter.string(from: date)
        }
        // fallback without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: str) {
            return Self.dateFormatter.string(from: date)
        }
        return str
    }

    private var statusColor: Color {
        checkout.status == .open ? SGDFColors.primaryBlue : SGDFColors.textSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            HStack {
                Text(checkout.label)
                    .font(SGDFTheme.FontStyle.body().weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Spacer()
                Text(checkout.status.label)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(statusColor)
            }
            if let date = formattedDate {
                Text(date)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}
