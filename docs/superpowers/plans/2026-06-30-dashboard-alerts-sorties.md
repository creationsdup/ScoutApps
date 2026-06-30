# Dashboard Alerts + Sorties Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the ScoutMatériel dashboard's Alertes section, a "Sorties en cours" section unifying open checkouts and active ScoutCamp camps, and the missing quick actions — all as a read-only aggregation layer over existing data.

**Architecture:** A new `DashboardService` (ScoutKit) aggregates existing services into a `DashboardSnapshot` (counts + alerts + ongoing checkouts + ongoing camps). `DashboardViewModel` publishes the snapshot; `DashboardView` renders stat cards, alerts (each tapping into a self-contained item list), the sorties/camps section, and 5 quick actions. No schema changes, no writes.

**Tech Stack:** SwiftUI, ScoutKit local Swift package, supabase-swift SDK, Postgres (Supabase, shared with CampManager).

## Global Constraints

- **No XCTest target exists.** Verification = `xcodebuild build` succeeds (authoritative) + manual simulator run. Never claim tests pass.
- Build commands (generic simulator destination):
  - `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build`
- **Read-only / additive:** NO schema changes, NO write paths, NO new DB tables/columns. Zero risk to CampManager.
- **No new app-target files.** New `.swift` files in the app targets need Xcode target membership (not auto-compiled). Therefore: `DashboardService` and its types go in **ScoutKit** (folder-based, auto-compiled); ALL new SwiftUI subviews go **inside the existing `ScoutMateriel/Views/Dashboard/DashboardView.swift`** as `private`/`fileprivate` structs. Do not create new files in the app target. Do not edit `.xcodeproj`.
- **ScoutKit symbols consumed by apps must be `public`** (incl. `public init`).
- **Design system is the only source of color.** No raw hex / `Color(...)` / framework default accents in views. Use `SGDFColors` tokens / `StatusColorMapper`. Charted roles: red = error/repair/missing; orange = important/checked-out/low-stock/warning; violet = programme/camp; textSecondary = archived/neutral.
- UI copy is **French**. Match existing phrasing.
- `Checkout.createdAt` / camp timestamps: `created_at` is a full timestamptz string; parse only its date prefix via `String(createdAt.prefix(10))` then `SGDFDate.day(from:)` (the same pattern `CheckoutDetailView` already uses). Camp `startDate`/`endDate` are already `yyyy-MM-dd` → use `SGDFDate.displayShort(_:)` directly.
- Commit after each task. Commit message trailer:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

## File Map

- Modify: `ScoutKit/Sources/ScoutKit/Services/QRCodeService.swift` — add `assignedItemIds()`.
- Create: `ScoutKit/Sources/ScoutKit/Services/DashboardService.swift` — `DashboardService` + `DashboardSnapshot` / `DashboardAlert` / `OngoingCheckout` / `OngoingCamp`.
- Modify: `ScoutMateriel/ViewModels/DashboardViewModel.swift` — publish `DashboardSnapshot` via `DashboardService`.
- Modify: `ScoutMateriel/Views/Dashboard/DashboardView.swift` — stat cards read snapshot; add Alertes section + `AlertCard` + `AlertItemsListView`; add Sorties section + `OngoingCheckoutCard` + `OngoingCampCard`; rename header + add quick actions.

---

### Task 1: ScoutKit — DashboardService + QRCodeService.assignedItemIds

**Files:**
- Modify: `ScoutKit/Sources/ScoutKit/Services/QRCodeService.swift`
- Create: `ScoutKit/Sources/ScoutKit/Services/DashboardService.swift`

**Interfaces:**
- Consumes: `ItemService.list(includeArchived:)`, `CheckoutService.list()` + `lines(checkoutId:)`, `CampService.list()`, `CampMaterialService.items(campId:)`, `Item`, `Checkout`, `Camp`, `CheckoutLine`, `SGDFDate`.
- Produces:
  - `QRCodeService.assignedItemIds() async throws -> Set<String>`
  - `DashboardService()` with `func loadSnapshot() async throws -> DashboardSnapshot`
  - `DashboardSnapshot` (counts + `[DashboardAlert]` + `[OngoingCheckout]` + `[OngoingCamp]`)
  - `DashboardAlert` (`Kind` enum with `label`/`systemImage`, `items: [Item]`, `id`)
  - `OngoingCheckout` (`checkout`, `totalItems`, `returnedItems`, `returnRate`, `id`)
  - `OngoingCamp` (`camp`, `items`, `itemCount`, `id`)

- [ ] **Step 1: Add `assignedItemIds()` to `QRCodeService.swift`**

Add this method inside `QRCodeService` (e.g. after `tag(forItemId:)`, around line 33):

```swift
    /// Ensemble des item ids ayant une étiquette QR associée (qr_tags.assigned_item_id).
    public func assignedItemIds() async throws -> Set<String> {
        struct Row: Decodable { let assigned_item_id: String? }
        let rows: [Row] = try await client.from("qr_tags")
            .select("assigned_item_id").execute().value
        return Set(rows.compactMap { $0.assigned_item_id })
    }
```

- [ ] **Step 2: Create `DashboardService.swift` with the snapshot types**

Create `ScoutKit/Sources/ScoutKit/Services/DashboardService.swift`:

```swift
import Foundation

/// Instantané agrégé du tableau de bord ScoutMatériel (lecture seule).
public struct DashboardSnapshot {
    public var total = 0
    public var available = 0
    public var checkedOut = 0
    public var toRepair = 0
    public var alerts: [DashboardAlert] = []
    public var ongoingCheckouts: [OngoingCheckout] = []
    public var ongoingCamps: [OngoingCamp] = []
    public init() {}
}

/// Une alerte du tableau de bord : un type + les objets concernés.
public struct DashboardAlert: Identifiable {
    public enum Kind: String, CaseIterable {
        case checkedOutOver7d, toRepair, missingQR, missingPhoto, lowStock, toVerify
        public var label: String {
            switch self {
            case .checkedOutOver7d: return "Sortis depuis +7 jours"
            case .toRepair:         return "À réparer"
            case .missingQR:        return "Sans QR code"
            case .missingPhoto:     return "Sans photo"
            case .lowStock:         return "Stock faible"
            case .toVerify:         return "À vérifier"
            }
        }
        public var systemImage: String {
            switch self {
            case .checkedOutOver7d: return "calendar.badge.exclamationmark"
            case .toRepair:         return "wrench.adjustable"
            case .missingQR:        return "qrcode"
            case .missingPhoto:     return "photo"
            case .lowStock:         return "exclamationmark.triangle.fill"
            case .toVerify:         return "sparkles"
            }
        }
    }
    public let kind: Kind
    public let items: [Item]
    public var id: String { kind.rawValue }
    public init(kind: Kind, items: [Item]) {
        self.kind = kind
        self.items = items
    }
}

/// Un bon de sortie ouvert et son avancement de retour.
public struct OngoingCheckout: Identifiable {
    public let checkout: Checkout
    public let totalItems: Int
    public let returnedItems: Int
    public var id: String { checkout.id }
    public var returnRate: Double { totalItems == 0 ? 0 : Double(returnedItems) / Double(totalItems) }
    public init(checkout: Checkout, totalItems: Int, returnedItems: Int) {
        self.checkout = checkout
        self.totalItems = totalItems
        self.returnedItems = returnedItems
    }
}

/// Un camp détenant du matériel (pont ScoutCamp -> ScoutMatériel).
public struct OngoingCamp: Identifiable {
    public let camp: Camp
    public let items: [Item]
    public var id: String { camp.id }
    public var itemCount: Int { items.count }
    public init(camp: Camp, items: [Item]) {
        self.camp = camp
        self.items = items
    }
}

/// Agrège les données existantes pour le tableau de bord. Lecture seule.
public struct DashboardService {
    public init() {}

    public func loadSnapshot() async throws -> DashboardSnapshot {
        let items = try await ItemService().list(includeArchived: false)
        let assigned = try await QRCodeService().assignedItemIds()

        var snap = DashboardSnapshot()
        snap.total = items.count
        snap.available = items.filter { $0.status == .disponible }.count
        snap.checkedOut = items.filter { $0.status == .sorti }.count
        snap.toRepair = items.filter { $0.status == .aReparer }.count

        // Bons de sortie ouverts + objets sortis depuis +7 jours.
        let checkoutService = CheckoutService()
        let openCheckouts = try await checkoutService.list().filter { $0.status == .open }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var ongoingCheckouts: [OngoingCheckout] = []
        var over7d: [Item] = []
        for co in openCheckouts {
            let lines = try await checkoutService.lines(checkoutId: co.id)
            let total = lines.reduce(0) { $0 + $1.quantity }
            let returned = lines.reduce(0) { $0 + $1.quantityReturned }
            ongoingCheckouts.append(OngoingCheckout(checkout: co, totalItems: total, returnedItems: returned))
            if let createdAt = co.createdAt,
               let day = SGDFDate.day(from: String(createdAt.prefix(10))),
               day < cutoff {
                for line in lines where line.remaining > 0 { over7d.append(line.item) }
            }
        }
        var seen = Set<String>()
        let over7dUnique = over7d.filter { seen.insert($0.id).inserted }

        // Camps détenant du matériel (ScoutCamp).
        let campMaterial = CampMaterialService()
        var ongoingCamps: [OngoingCamp] = []
        for camp in try await CampService().list() {
            let campItems = try await campMaterial.items(campId: camp.id)
            if !campItems.isEmpty { ongoingCamps.append(OngoingCamp(camp: camp, items: campItems)) }
        }

        // Alertes (uniquement celles non vides), dans l'ordre d'affichage.
        var alerts: [DashboardAlert] = []
        func add(_ kind: DashboardAlert.Kind, _ list: [Item]) {
            if !list.isEmpty { alerts.append(DashboardAlert(kind: kind, items: list)) }
        }
        add(.checkedOutOver7d, over7dUnique)
        add(.toRepair, items.filter { $0.status == .aReparer })
        add(.missingQR, items.filter { !assigned.contains($0.id) })
        add(.missingPhoto, items.filter { $0.imagePath == nil })
        add(.lowStock, items.filter { $0.isLowStock })
        add(.toVerify, items.filter { $0.status == .aVerifier })

        snap.alerts = alerts
        snap.ongoingCheckouts = ongoingCheckouts
        snap.ongoingCamps = ongoingCamps
        return snap
    }
}
```

- [ ] **Step 3: Build both schemes**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected: both `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ScoutKit/Sources/ScoutKit/Services/QRCodeService.swift ScoutKit/Sources/ScoutKit/Services/DashboardService.swift
git commit -m "feat(service): DashboardService snapshot (counts/alerts/ongoing) + QRCodeService.assignedItemIds

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: DashboardViewModel publishes the snapshot; stat cards read it

**Files:**
- Modify: `ScoutMateriel/ViewModels/DashboardViewModel.swift`
- Modify: `ScoutMateriel/Views/Dashboard/DashboardView.swift`

**Interfaces:**
- Consumes: `DashboardService.loadSnapshot()`, `DashboardSnapshot` (Task 1).
- Produces: `DashboardViewModel.snapshot: DashboardSnapshot` (published). Removes the old `DashboardStats` type.

- [ ] **Step 1: Replace `DashboardViewModel.swift` contents**

Replace the whole file with:

```swift
import Foundation
import ScoutKit

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var snapshot = DashboardSnapshot()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = DashboardService()

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            snapshot = try await service.loadSnapshot()
        } catch {
            errorMessage = "Impossible de charger le tableau de bord. Vérifie la connexion ou la base."
        }
        isLoading = false
    }
}
```

- [ ] **Step 2: Point the stat cards at the snapshot in `DashboardView.swift`**

In the `LazyVGrid` (currently reading `viewModel.stats.*`), change the four `StatCard` value arguments:

```swift
                        StatCard(value: viewModel.snapshot.total, title: "Total",
                                 systemImage: "shippingbox.fill", accent: SGDFColors.primaryBlue)
                        StatCard(value: viewModel.snapshot.available, title: "Disponibles",
                                 systemImage: "checkmark.circle.fill", accent: StatusColorMapper.color(for: .disponible))
                        StatCard(value: viewModel.snapshot.checkedOut, title: "Sortis",
                                 systemImage: "arrow.up.right.circle.fill", accent: StatusColorMapper.color(for: .sorti))
                        StatCard(value: viewModel.snapshot.toRepair, title: "À réparer",
                                 systemImage: "wrench.adjustable.fill", accent: StatusColorMapper.color(for: .aReparer))
```

- [ ] **Step 3: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`. (No reference to `viewModel.stats` or `DashboardStats` remains.)

- [ ] **Step 4: Commit**

```bash
git add ScoutMateriel/ViewModels/DashboardViewModel.swift ScoutMateriel/Views/Dashboard/DashboardView.swift
git commit -m "refactor(dashboard): VM publishes DashboardSnapshot via DashboardService

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Alertes section + AlertCard + AlertItemsListView

**Files:**
- Modify: `ScoutMateriel/Views/Dashboard/DashboardView.swift`

**Interfaces:**
- Consumes: `viewModel.snapshot.alerts: [DashboardAlert]` (Task 1), `MaterialListViewModel` (existing: `loadReferentials()`, `categoryName(_:)`, `locationName(_:)`), `MaterialDetailView(item:listViewModel:)` (existing), `SGDFBadge`, `SGDFCard`.
- Produces: `private struct AlertCard`, `struct AlertItemsListView` (file-private to DashboardView.swift).

- [ ] **Step 1: Insert the Alertes section in the dashboard body**

In `DashboardView.body`, between the `LazyVGrid` (stat cards) and the `Text("Raccourcis")` line, insert:

```swift
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
```

- [ ] **Step 2: Add the `AlertCard` private view**

Add at the end of `DashboardView.swift` (after the `StatCard` struct):

```swift
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
```

- [ ] **Step 3: Add the `AlertItemsListView`**

Add at the end of `DashboardView.swift`:

```swift
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
```

- [ ] **Step 4: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ScoutMateriel/Views/Dashboard/DashboardView.swift
git commit -m "feat(dashboard): Alertes section with clickable per-type item lists

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Sorties en cours (checkouts + camps)

**Files:**
- Modify: `ScoutMateriel/Views/Dashboard/DashboardView.swift`

**Interfaces:**
- Consumes: `viewModel.snapshot.ongoingCheckouts: [OngoingCheckout]`, `viewModel.snapshot.ongoingCamps: [OngoingCamp]` (Task 1); `CheckoutDetailView(checkout:)` (existing); `AlertItemsListView(title:items:)` (Task 3); `SGDFDate.displayShort(_:)`; `SGDFCard`.
- Produces: `private struct OngoingCheckoutCard`, `private struct OngoingCampCard`.

- [ ] **Step 1: Insert the Sorties section in the dashboard body**

In `DashboardView.body`, immediately AFTER the Alertes section block (from Task 3) and BEFORE `Text("Raccourcis")`, insert:

```swift
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
```

- [ ] **Step 2: Add the `OngoingCheckoutCard` private view**

Add at the end of `DashboardView.swift`:

```swift
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
```

- [ ] **Step 3: Add the `OngoingCampCard` private view**

Add at the end of `DashboardView.swift`:

```swift
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
```

- [ ] **Step 4: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ScoutMateriel/Views/Dashboard/DashboardView.swift
git commit -m "feat(dashboard): Sorties en cours — open checkouts + active ScoutCamp camps

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Actions rapides — rename header + 3 quick actions

**Files:**
- Modify: `ScoutMateriel/Views/Dashboard/DashboardView.swift`

**Interfaces:**
- Consumes: `router.selectedTab` (`AppRouter.Tab`: `.material`, `.scan`, `.sorties`), `SGDFButton`.
- Produces: nothing downstream.

- [ ] **Step 1: Rename the header and add the three quick-action buttons**

Replace the `Text("Raccourcis")` line and the `VStack(spacing: SGDFTheme.Spacing.md) { ... }` block (the two existing buttons) with:

```swift
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
                        SGDFButton("Inventaire rapide (bientôt)", kind: .secondary, systemImage: "checklist") {
                        }
                        .disabled(true)
                        SGDFButton("Signaler une réparation", kind: .secondary, systemImage: "wrench.adjustable") {
                            router.selectedTab = .scan
                        }
                    }
```

- [ ] **Step 2: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual simulator check (whole feature)**

Run the app: the dashboard shows stat cards; an "Alertes" section (if any alert is non-empty) whose cards tap into a per-type item list → material detail; a "Sorties en cours" section listing open checkouts (with return rate) and active camps (name/dates/branch/count) tapping to the checkout detail / camp item list; an "Actions rapides" section with 5 buttons, "Inventaire rapide (bientôt)" disabled, the others switching tabs. (Requires real items/checkouts/camps in the shared backend to populate.)

- [ ] **Step 4: Commit**

```bash
git add ScoutMateriel/Views/Dashboard/DashboardView.swift
git commit -m "feat(dashboard): rename to Actions rapides + add 3 quick actions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Definition of done

- All 5 tasks committed; ScoutInventory builds clean (Task 1 also builds ScoutCamp).
- Manual runtime: alerts surface with correct counts and tap-through; sorties section unifies checkouts + camps; 5 quick actions behave (Inventaire disabled).
- No schema changes, no writes. Out of scope (next/other cycles): Inventaire rapide screen (cycle 3), checkout `responsable`/dates/overdue, Matériel filter chips.
