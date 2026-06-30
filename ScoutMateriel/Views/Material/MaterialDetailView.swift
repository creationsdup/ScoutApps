import SwiftUI
import ScoutKit

struct MaterialDetailView: View {
    let item: Item
    @ObservedObject var listViewModel: MaterialListViewModel
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var confirmArchive = false
    @State private var archiveError: String?
    @State private var qrCode: String?
    @State private var qrError: String?
    @State private var displayStatus: ItemStatus?
    @State private var actionError: String?
    @State private var runningAction = false
    @State private var campLabel: String?
    @State private var openCheckoutLabel: String?
    @State private var liveTotal: Int?
    @State private var liveAvailable: Int?
    @State private var adjustNote = ""

    private func showQRCode() {
        qrCode = item.inventoryCode
    }

    private func perform(_ action: MovementAction) {
        guard !runningAction else { return }
        runningAction = true
        Task {
            do {
                try await MovementService().record(itemId: item.id, action: action)
                displayStatus = action.nextStatus
                await listViewModel.load()
            } catch {
                actionError = "Action impossible. Réessaie."
            }
            runningAction = false
        }
    }

    private var currentTotal: Int { liveTotal ?? item.quantity }
    private var currentAvailable: Int { liveAvailable ?? (item.quantityAvailable ?? item.quantity) }
    private var currentOut: Int { max(0, currentTotal - currentAvailable) }
    private var currentLowStock: Bool {
        guard item.trackingType == .global, let threshold = item.minimumThreshold else { return false }
        return currentAvailable < threshold
    }

    private func adjustStock(by delta: Int) {
        guard !runningAction else { return }
        runningAction = true
        Task {
            do {
                let note = adjustNote.trimmingCharacters(in: .whitespaces)
                let updated = try await ItemService().adjustStock(
                    itemId: item.id, delta: delta, note: note.isEmpty ? nil : note)
                liveTotal = updated.quantity
                liveAvailable = updated.quantityAvailable
                adjustNote = ""
                await listViewModel.load()
            } catch {
                actionError = "Ajustement impossible. Réessaie."
            }
            runningAction = false
        }
    }

    /// Sortir = orange (à préparer) ; Retour = vert (validation) ; sinon bleu.
    private func buttonKind(for action: MovementAction) -> SGDFButtonStyleKind {
        switch action {
        case .checkout: return .quickAction
        case .return:   return .primary
        default:        return .secondary
        }
    }

    private func icon(for action: MovementAction) -> String {
        switch action {
        case .checkout:   return "arrow.up.right.circle"
        case .return:     return "arrow.down.left.circle"
        case .cleaning:   return "sparkles"
        case .repair:     return "wrench.adjustable"
        case .transfer:   return "arrow.left.arrow.right"
        case .adjustment: return "plusminus.circle"
        }
    }

    private var imageURL: URL? {
        guard let path = item.imagePath else { return nil }
        return try? ImageStorageService().publicURL(for: path)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.lg) {
                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(SGDFColors.border)
                                .overlay(Image(systemName: "photo")
                                    .foregroundStyle(SGDFColors.textSecondary))
                        }
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
                }

                HStack {
                    Text(item.name)
                        .font(SGDFTheme.FontStyle.screenTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                    Spacer()
                    SGDFBadge(status: displayStatus ?? item.status)
                }
                Text(item.inventoryCode)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)

                if let campLabel {
                    Label("Sorti pour : \(campLabel)", systemImage: "tent")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }

                if let openCheckoutLabel {
                    Label("Dans la sortie : \(openCheckoutLabel)", systemImage: "arrow.up.bin")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }

                if let description = item.description, !description.isEmpty {
                    Text(description).foregroundStyle(SGDFColors.textPrimary)
                }

                SGDFCard {
                    DetailRow(label: "État", value: item.condition.label)
                    DetailRow(label: "Suivi", value: item.trackingType.label)
                    if item.trackingType != .global {
                        DetailRow(label: "Quantité",
                                  value: "\(item.quantityAvailable ?? item.quantity) / \(item.quantity)")
                    }
                    if let branch = item.branch { DetailRow(label: "Branche", value: branch.label) }
                    if let cat = listViewModel.categoryName(item.categoryId) {
                        DetailRow(label: "Catégorie", value: cat)
                    }
                    if let loc = listViewModel.locationName(item.locationId) {
                        DetailRow(label: "Localisation", value: loc)
                    }
                }

                if item.trackingType == .global {
                    StockCard(
                        total: currentTotal,
                        available: currentAvailable,
                        out: currentOut,
                        threshold: item.minimumThreshold,
                        unit: item.unit,
                        lowStock: currentLowStock,
                        canWrite: session.canWrite,
                        running: runningAction,
                        note: $adjustNote,
                        adjust: adjustStock
                    )
                }

                FieldActionsSection(
                    session: session,
                    runningAction: runningAction,
                    buttonKind: buttonKind,
                    icon: icon,
                    perform: perform
                )

                if let notes = item.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                        Text("Notes").font(SGDFTheme.FontStyle.sectionTitle())
                            .foregroundStyle(SGDFColors.textPrimary)
                        Text(notes).foregroundStyle(SGDFColors.textSecondary)
                    }
                }
            }
            .padding(SGDFTheme.Spacing.md)
        }
        .task { campLabel = try? await CampMaterialService().campLabel(forItemId: item.id) }
        .task { openCheckoutLabel = try? await CheckoutService().openCheckoutLabel(forItemId: item.id) }
        .background(SGDFColors.background)
        .navigationTitle("Fiche matériel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showQRCode() } label: { Label("QR code", systemImage: "qrcode") }
                    if session.canWrite {
                        Button { showEdit = true } label: { Label("Modifier", systemImage: "pencil") }
                        Button(role: .destructive) { confirmArchive = true } label: {
                            Label("Archiver", systemImage: "archivebox")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(item: $qrCode) { code in QRCodeGeneratorView(code: code) }
        .alert("Aucune étiquette", isPresented: Binding(
            get: { qrError != nil }, set: { if !$0 { qrError = nil } })
        ) { Button("OK", role: .cancel) {} } message: { Text(qrError ?? "") }
        .sheet(isPresented: $showEdit) {
            MaterialFormView(item: item) {
                Task { await listViewModel.load() }
                dismiss()
            }
        }
        .confirmationDialog("Archiver ce matériel ?", isPresented: $confirmArchive, titleVisibility: .visible) {
            Button("Archiver", role: .destructive) {
                Task {
                    do {
                        try await ItemService().archive(id: item.id)
                        await listViewModel.load()
                        dismiss()
                    } catch {
                        archiveError = "Échec de l'archivage. Réessaie."
                    }
                }
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { archiveError != nil },
            set: { if !$0 { archiveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(archiveError ?? "")
        }
        .alert("Erreur", isPresented: Binding(
            get: { actionError != nil }, set: { if !$0 { actionError = nil } })
        ) { Button("OK", role: .cancel) {} } message: { Text(actionError ?? "") }
    }
}

// MARK: - Field Actions Section (extracted to help type inference)

private struct FieldActionsSection: View {
    let session: SessionStore
    let runningAction: Bool
    let buttonKind: (MovementAction) -> SGDFButtonStyleKind
    let icon: (MovementAction) -> String
    let perform: (MovementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
            Text("Actions terrain")
                .font(SGDFTheme.FontStyle.sectionTitle())
                .foregroundStyle(SGDFColors.textPrimary)

            if session.canWrite {
                ForEach(MovementAction.allCases.filter { $0 != .adjustment }, id: \.self) { action in
                    SGDFButton(action.label, kind: buttonKind(action),
                               systemImage: icon(action)) {
                        perform(action)
                    }
                    .disabled(runningAction)
                }
            } else {
                SGDFCard {
                    Label("Lecture seule — ton rôle ne permet pas d'agir.",
                          systemImage: "lock")
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            }
        }
    }
}

/// Ligne label/valeur dans la fiche.
private struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(SGDFColors.textSecondary)
            Spacer()
            Text(value).foregroundStyle(SGDFColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(SGDFTheme.FontStyle.body())
    }
}

/// Carte de stock pour un matériel en suivi global.
private struct StockCard: View {
    let total: Int
    let available: Int
    let out: Int
    let threshold: Int?
    let unit: ItemUnit?
    let lowStock: Bool
    let canWrite: Bool
    let running: Bool
    @Binding var note: String
    let adjust: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.sm) {
            Text("Stock")
                .font(SGDFTheme.FontStyle.sectionTitle())
                .foregroundStyle(SGDFColors.textPrimary)
            SGDFCard {
                DetailRow(label: "Total", value: "\(total)\(unitSuffix)")
                DetailRow(label: "Disponible", value: "\(available)\(unitSuffix)")
                DetailRow(label: "Sortie", value: "\(out)\(unitSuffix)")
                if let threshold {
                    DetailRow(label: "Seuil minimum", value: "\(threshold)\(unitSuffix)")
                }
                if lowStock {
                    Label("Stock faible", systemImage: "exclamationmark.triangle.fill")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.orange)
                }
            }
            if canWrite {
                HStack(spacing: SGDFTheme.Spacing.md) {
                    Button { adjust(-1) } label: {
                        Image(systemName: "minus.circle.fill").font(.title2)
                    }
                    .disabled(running || total == 0)
                    Text("\(total)")
                        .font(SGDFTheme.FontStyle.screenTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                        .frame(minWidth: 44)
                    Button { adjust(1) } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .disabled(running)
                }
                .tint(SGDFColors.primaryBlue)
                .frame(maxWidth: .infinity)
                TextField("Note (optionnel)", text: $note)
                    .font(SGDFTheme.FontStyle.caption())
            }
        }
    }

    private var unitSuffix: String { unit.map { " \($0.label.lowercased())" } ?? "" }
}
