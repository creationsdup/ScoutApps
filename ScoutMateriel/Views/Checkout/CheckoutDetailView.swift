import SwiftUI
import ScoutKit

struct CheckoutDetailView: View {
    let checkout: Checkout

    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = CheckoutDetailViewModel()
    @State private var confirmReturnAll = false

    private var statusColor: Color {
        checkout.status == .open ? SGDFColors.primaryBlue : SGDFColors.textSecondary
    }

    var body: some View {
        List {
            // MARK: Header card
            Section {
                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
                    Text(checkout.label)
                        .font(SGDFTheme.FontStyle.sectionTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                    HStack {
                        Text(checkout.status.label)
                            .font(SGDFTheme.FontStyle.caption().weight(.semibold))
                            .foregroundStyle(statusColor)
                        if let notes = checkout.notes, !notes.isEmpty {
                            Spacer()
                            Text(notes)
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, SGDFTheme.Spacing.xs)
            }

            // MARK: Error
            if let err = vm.errorMessage {
                Section {
                    Text(err)
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.red)
                }
            }

            // MARK: Lines
            if vm.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if vm.lines.isEmpty {
                Section {
                    Text("Aucune ligne.")
                        .font(SGDFTheme.FontStyle.body())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            } else {
                Section("Matériel") {
                    ForEach(vm.lines) { line in
                        CheckoutLineRow(
                            line: line,
                            checkout: checkout,
                            canWrite: session.canWrite,
                            onReturn: { qty in
                                Task { await vm.returnLine(line, qty: qty, checkoutId: checkout.id) }
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(SGDFColors.background)
        .navigationTitle("Bon de sortie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.canWrite && checkout.status == .open {
                ToolbarItem(placement: .primaryAction) {
                    Button("Tout rendre") {
                        confirmReturnAll = true
                    }
                    .foregroundStyle(SGDFColors.orange)
                }
            }
        }
        .confirmationDialog(
            "Rendre tout le matériel ?",
            isPresented: $confirmReturnAll,
            titleVisibility: .visible
        ) {
            Button("Tout rendre", role: .destructive) {
                Task { await vm.returnAll(checkoutId: checkout.id) }
            }
            Button("Annuler", role: .cancel) {}
        }
        .task { await vm.load(checkoutId: checkout.id) }
    }
}

// MARK: - Line row

private struct CheckoutLineRow: View {
    let line: CheckoutLine
    let checkout: Checkout
    let canWrite: Bool
    let onReturn: (Int) -> Void

    @State private var qty: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
            HStack {
                Text(line.item.name)
                    .font(SGDFTheme.FontStyle.body().weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Spacer()
                Text("\(line.quantityReturned) / \(line.quantity) rendu")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(
                        line.remaining == 0 ? SGDFColors.green : SGDFColors.textSecondary
                    )
            }

            if canWrite && line.remaining > 0 && checkout.status == .open {
                ReturnControl(
                    qty: $qty,
                    remaining: line.remaining,
                    onReturn: { onReturn(qty) }
                )
            }
        }
        .padding(.vertical, 2)
        .onAppear { qty = min(1, line.remaining) }
    }
}

// MARK: - Return control

private struct ReturnControl: View {
    @Binding var qty: Int
    let remaining: Int
    let onReturn: () -> Void

    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.sm) {
            Stepper(
                "Rendre : \(qty)",
                value: $qty,
                in: 1...max(1, remaining)
            )
            .font(SGDFTheme.FontStyle.caption())
            .foregroundStyle(SGDFColors.textPrimary)

            Button("Rendre") {
                onReturn()
            }
            .font(SGDFTheme.FontStyle.caption().weight(.semibold))
            .foregroundStyle(SGDFColors.green)
        }
    }
}
