# Stock Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real quantity-tracked stock management (seuil minimum, unité, +/- adjustment with audit trail, low-stock visibility) to the ScoutMatériel app, additively over the shared Supabase backend.

**Architecture:** Additive Supabase columns on `inventory_items` (`minimum_threshold`, `unit`) and `item_movements` (`quantity`, `note`). New fields + computed helpers on the `Item` model in ScoutKit. A new `ItemService.adjustStock` that updates totals (disponible follows, clamped) and records an `adjustment` movement via `MovementService`. UI in the detail screen (stock card + stepper + low-stock warning), the add/edit form (seuil + unité fields for `global` items), and the list row (quantities + low-stock badge).

**Tech Stack:** SwiftUI, ScoutKit local Swift package, supabase-swift SDK, Postgres (Supabase).

## Global Constraints

- **No XCTest target exists.** Verification = `xcodebuild build` succeeds (authoritative) + manual simulator run. Never claim tests pass.
- Build commands (use a generic simulator destination):
  - `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build`
- **Shared backend** with CampManager: migrations are **additive only** (`add column if not exists`, `NOT VALID` checks). Never mutate existing data/columns/enum values.
- **ScoutKit symbols consumed by an app must be `public`** (incl. `public init` / `public var`).
- **Design system is the only source of color.** No raw hex / `Color(...)` / framework default accents in views. Use `SGDFColors` tokens and `StatusColorMapper`.
- UI copy is **French**. Match existing phrasing.
- Files in `ScoutKit/Sources/ScoutKit/` are folder-based (auto-compiled). New `.swift` files in the **app** targets would need Xcode target membership — this plan adds **no** new app-target files (only edits existing ones), so no `.xcodeproj` changes are required.
- Stock logic applies to `trackingType == .global` only. `specifique` items are unaffected (qty 1, no stock UI).
- Commit after each task. Commit message trailer:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

## File Map

- Create: `supabase/migrations/20260701_stock_management.sql` — additive DB columns.
- Modify: `ScoutKit/Sources/ScoutKit/Models/Enums.swift` — `ItemUnit` enum; `MovementAction.adjustment`.
- Modify: `ScoutKit/Sources/ScoutKit/Models/Item.swift` — `minimumThreshold`, `unit`, computed `quantityOut`/`isLowStock`.
- Modify: `ScoutKit/Sources/ScoutKit/Models/MovementHistory.swift` — `quantity`, `note`.
- Modify: `ScoutKit/Sources/ScoutKit/Services/MovementService.swift` — `recordAdjustment`.
- Modify: `ScoutKit/Sources/ScoutKit/Services/ItemService.swift` — `adjustStock`.
- Modify: `ScoutMateriel/Views/Material/MaterialDetailView.swift` — stock card + stepper + low-stock warning; exclude `.adjustment` from action menu.
- Modify: `ScoutMateriel/Views/Material/MaterialFormView.swift` + `ScoutMateriel/ViewModels/MaterialFormViewModel.swift` — seuil + unité fields.
- Modify: `ScoutMateriel/Views/Material/MaterialListView.swift` — list row quantities + low-stock badge.

---

### Task 1: SQL migration (additive columns)

**Files:**
- Create: `supabase/migrations/20260701_stock_management.sql`

**Interfaces:**
- Produces: DB columns `inventory_items.minimum_threshold (integer)`, `inventory_items.unit (text)`, `item_movements.quantity (integer)`, `item_movements.note (text)`. `unit` allowed values: `piece, lot, boite, paquet, metre, litre, autre`.

- [ ] **Step 1: Create the migration file**

```sql
-- 20260701_stock_management.sql
-- Gestion de stock (cycle 1/3) : colonnes ADDITIVES uniquement. Backend partagé
-- avec CampManager — aucune mutation de données/colonnes/enum existants.
-- À exécuter dans le SQL editor Supabase APRÈS les migrations précédentes.

-- 1. Stock sur inventory_items (nullables, additives) -------------------------
alter table public.inventory_items
  add column if not exists minimum_threshold integer,
  add column if not exists unit              text;

-- Contrainte de validation de l'unité (NOT VALID : n'invalide pas l'existant).
-- Valeurs = rawValues de l'enum Swift ItemUnit.
alter table public.inventory_items drop constraint if exists inventory_items_unit_chk;
alter table public.inventory_items
  add constraint inventory_items_unit_chk
  check (unit is null or unit in ('piece','lot','boite','paquet','metre','litre','autre')) not valid;
-- Après vérif des données existantes, tu peux valider :
--   alter table public.inventory_items validate constraint inventory_items_unit_chk;

-- 2. Journal des ajustements sur item_movements ------------------------------
--    `action` est un text libre : la valeur 'adjustment' ne nécessite aucune
--    migration d'enum. On ajoute la quantité (delta signé) et une note libre.
alter table public.item_movements
  add column if not exists quantity integer,
  add column if not exists note     text;
```

- [ ] **Step 2: Sanity-check the SQL**

Run: `grep -n "add column if not exists\|not valid" supabase/migrations/20260701_stock_management.sql`
Expected: 4 `add column if not exists` lines and 1 `not valid` line. (Cannot execute against the DB here — the user runs it in the Supabase SQL editor.)

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260701_stock_management.sql
git commit -m "feat(sql): additive stock columns (minimum_threshold, unit, movement quantity/note)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: ScoutKit model changes

**Files:**
- Modify: `ScoutKit/Sources/ScoutKit/Models/Enums.swift`
- Modify: `ScoutKit/Sources/ScoutKit/Models/Item.swift`
- Modify: `ScoutKit/Sources/ScoutKit/Models/MovementHistory.swift`

**Interfaces:**
- Consumes: nothing (foundation task).
- Produces:
  - `public enum ItemUnit: String, Codable, CaseIterable { case piece, lot, boite, paquet, metre, litre, autre; var label: String }`
  - `MovementAction.adjustment` (rawValue `"adjustment"`, label `"Ajustement"`).
  - `Item.minimumThreshold: Int?`, `Item.unit: ItemUnit?`, `Item.init(... minimumThreshold: Int? = nil, unit: ItemUnit? = nil)`, computed `Item.quantityOut: Int`, `Item.isLowStock: Bool`.
  - `MovementHistory.quantity: Int?`, `MovementHistory.note: String?`, with defaults `nil` in `init`.

- [ ] **Step 1: Add `ItemUnit` enum to `Enums.swift`**

Add after the `TrackingType` enum (around line 54):

```swift
/// Unité de quantité pour un matériel en suivi global (inventory_items.unit).
/// rawValue = valeur stockée en base (cf. contrainte inventory_items_unit_chk).
public enum ItemUnit: String, Codable, CaseIterable {
    case piece, lot, boite, paquet, metre, litre, autre
    public var label: String {
        switch self {
        case .piece:  return "Pièce"
        case .lot:    return "Lot"
        case .boite:  return "Boîte"
        case .paquet: return "Paquet"
        case .metre:  return "Mètre"
        case .litre:  return "Litre"
        case .autre:  return "Autre"
        }
    }
}
```

- [ ] **Step 2: Add `.adjustment` to `MovementAction` in `MovementHistory.swift`**

Change the case list (line 5) from:

```swift
    case checkout, `return`, cleaning, repair, transfer
```
to:
```swift
    case checkout, `return`, cleaning, repair, transfer, adjustment
```

Add to the `label` switch (after the `.transfer` case):

```swift
        case .adjustment: return "Ajustement"
```

Add to the `nextStatus` switch (after the `.transfer` case). An adjustment never changes status; this branch is never read (the adjust path does not call `nextStatus`, and `.adjustment` is excluded from the action menu) — `.disponible` is an inert default:

```swift
        case .adjustment: return .disponible
```

- [ ] **Step 3: Add `quantity` and `note` to `MovementHistory` in `MovementHistory.swift`**

Add the stored properties (after `createdAt`, line 34):

```swift
    public var quantity: Int?
    public var note: String?
```

Update the `init` signature (add two params with defaults, before the closing paren) and body:

```swift
    public init(
        id: String,
        itemId: String,
        action: MovementAction,
        userId: String? = nil,
        eventId: String? = nil,
        createdAt: String? = nil,
        quantity: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.action = action
        self.userId = userId
        self.eventId = eventId
        self.createdAt = createdAt
        self.quantity = quantity
        self.note = note
    }
```

Add to `CodingKeys` (after `case createdAt = "created_at"`):

```swift
        case quantity
        case note
```

- [ ] **Step 4: Add stock fields + computed helpers to `Item.swift`**

Add stored properties after `lastCheckedAt` (line 20):

```swift
    public var minimumThreshold: Int?
    public var unit: ItemUnit?
```

Update the `init` signature — add two params with defaults right before the closing paren (after `lastCheckedAt: String? = nil`):

```swift
        lastCheckedAt: String? = nil,
        minimumThreshold: Int? = nil,
        unit: ItemUnit? = nil
```

Add to the `init` body (after `self.lastCheckedAt = lastCheckedAt`):

```swift
        self.minimumThreshold = minimumThreshold
        self.unit = unit
```

Add to `CodingKeys` (after `case lastCheckedAt = "last_checked_at"`):

```swift
        case minimumThreshold = "minimum_threshold"
        case unit
```

Add computed helpers just before the `enum CodingKeys` declaration:

```swift
    /// Quantité actuellement sortie (dérivée, non stockée).
    public var quantityOut: Int { max(0, quantity - (quantityAvailable ?? quantity)) }

    /// Stock faible : disponible sous le seuil. N'a de sens que pour le suivi global.
    public var isLowStock: Bool {
        guard trackingType == .global, let threshold = minimumThreshold else { return false }
        return (quantityAvailable ?? quantity) < threshold
    }
```

- [ ] **Step 5: Build both schemes**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected: both end with `** BUILD SUCCEEDED **`. (Existing `Item(...)` / `MovementHistory(...)` call sites still compile because the new params have `nil` defaults.)

- [ ] **Step 6: Commit**

```bash
git add ScoutKit/Sources/ScoutKit/Models/Enums.swift ScoutKit/Sources/ScoutKit/Models/Item.swift ScoutKit/Sources/ScoutKit/Models/MovementHistory.swift
git commit -m "feat(model): stock fields (minimumThreshold, unit, ItemUnit), adjustment movement

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Service layer — `adjustStock` + `recordAdjustment`

**Files:**
- Modify: `ScoutKit/Sources/ScoutKit/Services/MovementService.swift`
- Modify: `ScoutKit/Sources/ScoutKit/Services/ItemService.swift`

**Interfaces:**
- Consumes: `Item` (Task 2), `MovementAction.adjustment` (Task 2), `SupabaseService.shared`.
- Produces:
  - `MovementService.recordAdjustment(itemId: String, quantity: Int, note: String?) async throws` — inserts an `adjustment` movement (with `quantity` + `note`), does **not** touch item status.
  - `ItemService.adjustStock(itemId: String, delta: Int, note: String?) async throws -> Item` (`@discardableResult`) — updates `quantity` + `quantity_available` (partial payload), records the adjustment movement, returns the updated `Item`.

- [ ] **Step 1: Extend `MovementService` to carry quantity/note and add `recordAdjustment`**

In `MovementService.swift`, replace the `MovementPayload` struct (lines 12-17) with one that carries optional quantity/note:

```swift
    private struct MovementPayload: Encodable {
        let item_id: String
        let action: String
        let user_id: String
        let event_id: String?
        let quantity: Int?
        let note: String?
    }
```

Update the existing `record(...)` insert (the `.insert(MovementPayload(...))` call around line 31) to pass the new fields as `nil`:

```swift
        try await client.from("item_movements")
            .insert(MovementPayload(item_id: itemId, action: action.rawValue,
                                    user_id: userId, event_id: eventId,
                                    quantity: nil, note: nil))
            .execute()
```

Add a new method after `record(...)` (before the closing brace of the struct):

```swift
    /// Enregistre un ajustement de stock dans le journal. NE modifie PAS le statut.
    public func recordAdjustment(itemId: String, quantity: Int, note: String?) async throws {
        guard let userId = SupabaseService.shared.currentUserID?.uuidString else {
            throw NSError(domain: "ScoutManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Utilisateur non authentifié."])
        }
        try await client.from("item_movements")
            .insert(MovementPayload(item_id: itemId, action: MovementAction.adjustment.rawValue,
                                    user_id: userId, event_id: nil,
                                    quantity: quantity, note: note))
            .execute()
    }
```

- [ ] **Step 2: Add `adjustStock` to `ItemService`**

In `ItemService.swift`, add a payload struct in the "Archive update payload" MARK area (after `ArchivePayload`, around line 14):

```swift
    private struct StockPayload: Encodable {
        let quantity: Int
        let quantity_available: Int
    }
```

Add the method after `archive(...)` (around line 54, before the `// MARK: - Referentials`):

```swift
    /// Ajuste le stock total d'un matériel global. Le disponible suit le même delta,
    /// borné à [0, total]. Enregistre un mouvement d'ajustement. Le statut est inchangé.
    @discardableResult
    public func adjustStock(itemId: String, delta: Int, note: String?) async throws -> Item {
        guard let item = try await get(id: itemId) else {
            throw NSError(domain: "ScoutManager", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Matériel introuvable."])
        }
        let newTotal = max(0, item.quantity + delta)
        let currentAvailable = item.quantityAvailable ?? item.quantity
        let newAvailable = min(max(0, currentAvailable + delta), newTotal)
        try await client.from("inventory_items")
            .update(StockPayload(quantity: newTotal, quantity_available: newAvailable))
            .eq("id", value: itemId)
            .execute()
        try await MovementService().recordAdjustment(itemId: itemId, quantity: delta, note: note)
        var updated = item
        updated.quantity = newTotal
        updated.quantityAvailable = newAvailable
        return updated
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
git add ScoutKit/Sources/ScoutKit/Services/MovementService.swift ScoutKit/Sources/ScoutKit/Services/ItemService.swift
git commit -m "feat(service): ItemService.adjustStock + MovementService.recordAdjustment

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Detail screen — stock card, stepper, low-stock warning

**Files:**
- Modify: `ScoutMateriel/Views/Material/MaterialDetailView.swift`

**Interfaces:**
- Consumes: `ItemService.adjustStock` (Task 3), `Item.quantityOut`/`isLowStock`/`unit`/`minimumThreshold` (Task 2), `MovementAction.adjustment` (Task 2).
- Produces: nothing downstream.

- [ ] **Step 1: Add `.adjustment` to the `icon(for:)` switch**

The `icon(for:)` switch (lines 58-66) is exhaustive with no `default`. Add a branch after `.transfer`:

```swift
        case .adjustment: return "plusminus.circle"
```
(`buttonKind(for:)` already has a `default:` branch, so it needs no change.)

- [ ] **Step 2: Exclude `.adjustment` from the field-action menu**

In `FieldActionsSection.body`, change the `ForEach` (line 222) from:

```swift
                ForEach(MovementAction.allCases, id: \.self) { action in
```
to:
```swift
                ForEach(MovementAction.allCases.filter { $0 != .adjustment }, id: \.self) { action in
```

- [ ] **Step 3: Add live-quantity state and the adjust action to `MaterialDetailView`**

Add state properties after `openCheckoutLabel` (line 18):

```swift
    @State private var liveTotal: Int?
    @State private var liveAvailable: Int?
    @State private var adjustNote = ""
```

Add computed accessors and an adjust function after the `perform(_:)` function (after line 47):

```swift
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
```

- [ ] **Step 4: Render the stock card for `global` items**

Insert the stock card after the existing `SGDFCard { ... }` detail block (after line 131, before `FieldActionsSection`):

```swift
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
```

- [ ] **Step 5: Add the `StockCard` subview**

Add at the end of the file (after the `DetailRow` struct, line 253):

```swift
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
```

- [ ] **Step 6: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Manual simulator check**

Run the app on a simulator, open a `global` item: the Stock card shows Total/Disponible/Sortie/Seuil; `+`/`−` adjust the total and disponible follows; the values persist after pulling to refresh the list and reopening; a `specifique` item shows **no** Stock card. (If no `global` item exists, set one's tracking type to "Global" via the form first.)

- [ ] **Step 8: Commit**

```bash
git add ScoutMateriel/Views/Material/MaterialDetailView.swift
git commit -m "feat(material): stock card with +/- adjustment and low-stock warning

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Add/edit form — seuil + unité fields

**Files:**
- Modify: `ScoutMateriel/ViewModels/MaterialFormViewModel.swift`
- Modify: `ScoutMateriel/Views/Material/MaterialFormView.swift`

**Interfaces:**
- Consumes: `Item(... minimumThreshold:unit:)` (Task 2), `ItemUnit` (Task 2).
- Produces: nothing downstream.

- [ ] **Step 1: Add stock state to `MaterialFormViewModel`**

Add published properties after `branch` (line 16):

```swift
    @Published var minimumThreshold = 0   // 0 = pas de seuil
    @Published var unit: ItemUnit = .piece
```

In `init(item:)`, inside the `if let item {` block (after `branch = item.branch`, line 48), seed them:

```swift
            minimumThreshold = item.minimumThreshold ?? 0
            unit = item.unit ?? .piece
```

- [ ] **Step 2: Persist the stock fields in `save()`**

In `save()`, update the `Item(...)` construction (lines 81-98) by appending the two new arguments after `lastCheckedAt: nil` (only meaningful for `global`; `nil` for `specifique`):

```swift
                lastCheckedAt: nil,
                minimumThreshold: trackingType == .global && minimumThreshold > 0 ? minimumThreshold : nil,
                unit: trackingType == .global ? unit : nil
```

- [ ] **Step 3: Show seuil + unité in the form, gated on `global`**

In `MaterialFormView.swift`, inside the `Section("Suivi")` block, replace the unconditional `Quantité` stepper (line 44) with a `global`-gated group that also shows seuil + unité:

```swift
                    if viewModel.trackingType == .global {
                        Stepper("Quantité : \(viewModel.quantity)", value: $viewModel.quantity, in: 1...9999)
                        Stepper(viewModel.minimumThreshold == 0
                                ? "Seuil minimum : aucun"
                                : "Seuil minimum : \(viewModel.minimumThreshold)",
                                value: $viewModel.minimumThreshold, in: 0...9999)
                        Picker("Unité", selection: $viewModel.unit) {
                            ForEach(ItemUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
```

Add an `.onChange` on the form's `Form` (e.g. after `.task { await viewModel.loadReferentials() }`, line 80) to pin quantity to 1 for `specifique`:

```swift
            .onChange(of: viewModel.trackingType) { _, newValue in
                if newValue == .specifique { viewModel.quantity = 1 }
            }
```

- [ ] **Step 4: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual simulator check**

Add/edit a material: switching "Type de suivi" to **Global** reveals Quantité + Seuil minimum + Unité; switching to **Spécifique** hides them and forces quantité to 1. Save a `global` item with a seuil and reopen it — the seuil + unité persist (visible in the detail Stock card from Task 4).

- [ ] **Step 6: Commit**

```bash
git add ScoutMateriel/Views/Material/MaterialFormView.swift ScoutMateriel/ViewModels/MaterialFormViewModel.swift
git commit -m "feat(material): seuil minimum + unité fields in add/edit form

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: List row — quantities + low-stock badge

**Files:**
- Modify: `ScoutMateriel/Views/Material/MaterialListView.swift`

**Interfaces:**
- Consumes: `Item.isLowStock` (Task 2), `Item.quantityAvailable`/`quantity`/`trackingType` (existing).
- Produces: nothing downstream.

- [ ] **Step 1: Show disponible/total and a low-stock badge in `MaterialRow`**

In `MaterialListView.swift`, replace the `MaterialRow` body's `VStack` (lines 72-79) with a version that adds a stock line for `global` items, and add a low-stock badge before the status badge.

Replace:
```swift
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                Text(item.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Text(item.inventoryCode)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
            Spacer()
            SGDFBadge(status: item.status)
```
with:
```swift
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                Text(item.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Text(item.inventoryCode)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
                if item.trackingType == .global {
                    Text("Dispo \(item.quantityAvailable ?? item.quantity) / \(item.quantity)")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            }
            Spacer()
            if item.isLowStock {
                Label("Stock faible", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(SGDFColors.orange)
                    .accessibilityLabel("Stock faible")
            }
            SGDFBadge(status: item.status)
```

- [ ] **Step 2: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual simulator check**

In the Matériel list, a `global` item shows "Dispo X / Y" under its code; an item whose disponible is below its seuil shows the orange warning icon next to the status badge. `specifique` items show no quantity line.

- [ ] **Step 4: Commit**

```bash
git add ScoutMateriel/Views/Material/MaterialListView.swift
git commit -m "feat(material): list row shows disponible/total + low-stock indicator

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Definition of done

- All 6 tasks committed; both schemes build clean.
- User has run `20260701_stock_management.sql` in the Supabase SQL editor.
- Manual runtime: stock card adjusts and persists; seuil/unité save from the form; low-stock surfaces on detail + list; `specifique` items unaffected.
- Out of scope (next cycles): dashboard "stock faible" alert, filter chips, haptics/VoiceOver, history display, code generation.
