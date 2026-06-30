# Inventaire Rapide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the ScoutMatériel "Inventaire rapide" flow — an ephemeral in-memory inventory session (scope by location or category, point items present, see Présent/Manquant/En trop, close) that writes only `last_checked_at` for present items — and enable its dashboard quick-action button.

**Architecture:** A new `InventoryViewModel` (app target) holds the ephemeral session as a `.scope → .scanning → .summary` state machine over data from `ItemService`. A new `InventoryView` (fullScreenCover, app target) renders the three phases using design-system components and manual TAG entry + a tappable checklist (no live camera this cycle). `ItemService.markChecked(itemIds:)` (ScoutKit) writes `last_checked_at = now` on close. The dashboard button presents the flow.

**Tech Stack:** SwiftUI, ScoutKit local Swift package, supabase-swift SDK, Postgres (Supabase, shared with CampManager), `xcodeproj` Ruby gem (1.27.0) for app-target file membership.

## Global Constraints

- **No XCTest target exists.** Verification = `xcodebuild build` succeeds (authoritative) + manual simulator run. Never claim tests pass.
- Build commands (generic simulator destination):
  - `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build`
- **No new DB tables/columns; ephemeral session.** The only DB write is `inventory_items.last_checked_at` (an existing additive column, unused by CampManager) for present items. Safe for the shared backend.
- **New app-target files must be added to the `ScoutInventory` target** via the `xcodeproj` Ruby gem (classic groups — files are NOT auto-compiled otherwise). The build proves membership by compiling them.
- **No live camera this cycle** (decided during planning): the shared `QRScannerController` is single-shot; reuse would scan one item only and modifying it risks the Scan tab. Inventory uses manual TAG entry + the checklist. Camera doesn't work in the Simulator regardless.
- **Design system is the only source of color.** No raw hex / `Color(...)` / framework default accents. Use `SGDFColors` / `StatusColorMapper`. Reuse `SGDFCard`, `SGDFButton`, `SGDFTextField`, `SGDFBadge`.
- **ScoutKit symbols consumed by apps must be `public`.**
- UI copy is **French**.
- Commit after each task. Trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## File Map

- Modify: `ScoutKit/Sources/ScoutKit/Services/ItemService.swift` — add `markChecked(itemIds:)`.
- Create: `ScoutMateriel/ViewModels/InventoryViewModel.swift` — `InventoryScope` + `InventoryViewModel` (added to ScoutInventory target).
- Create: `ScoutMateriel/Views/Inventory/InventoryView.swift` — the fullScreenCover flow (added to ScoutInventory target).
- Modify: `ScoutMateriel/Views/Dashboard/DashboardView.swift` — enable the Inventaire button + present the cover.

---

### Task 1: ItemService.markChecked

**Files:**
- Modify: `ScoutKit/Sources/ScoutKit/Services/ItemService.swift`

**Interfaces:**
- Consumes: `SupabaseService.shared.client`.
- Produces: `ItemService.markChecked(itemIds: [String]) async throws` — sets `last_checked_at = now` for the given ids; no-op when empty.

- [ ] **Step 1: Add the payload struct + method**

In `ItemService.swift`, add the payload near the other private payloads (after `StockPayload`, around line 18):

```swift
    private struct LastCheckedPayload: Encodable { let last_checked_at: String }
```

Add the method after `adjustStock(...)` (before `// MARK: - Referentials`):

```swift
    /// Marque une liste d'objets comme inventoriés (last_checked_at = maintenant).
    /// No-op si la liste est vide. Écrit une colonne existante additive.
    public func markChecked(itemIds: [String]) async throws {
        guard !itemIds.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("inventory_items")
            .update(LastCheckedPayload(last_checked_at: now))
            .in("id", values: itemIds)
            .execute()
    }
```

- [ ] **Step 2: Build both schemes**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected: both `** BUILD SUCCEEDED **`. (If the SDK rejects `.in("id", values:)`, the method is spelled `.in("id", values: itemIds)` in supabase-swift; if the compiler treats `in` as a keyword, backtick it: `` .`in`("id", values: itemIds) ``.)

- [ ] **Step 3: Commit**

```bash
git add ScoutKit/Sources/ScoutKit/Services/ItemService.swift
git commit -m "feat(service): ItemService.markChecked writes last_checked_at for inventoried items

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: InventoryViewModel

**Files:**
- Create: `ScoutMateriel/ViewModels/InventoryViewModel.swift` (add to `ScoutInventory` target)

**Interfaces:**
- Consumes: `ItemService.list(categoryId:locationId:)`, `ItemService.listCategories()`, `ItemService.listLocations()`, `ItemService.get(id:)`, `ItemService.markChecked(itemIds:)` (Task 1), `QRCodeService.tag(byCode:)`, `TagCode.parse`, `Item`, `ItemCategory`, `ItemLocation`.
- Produces: `enum InventoryScope`; `InventoryViewModel` with `phase`/`useLocation`/`selectedLocationId`/`selectedCategoryId`/`expected`/`pointedIds`/`extras`/`manualCode`/`categories`/`locations`/`isLoading`/`errorMessage`/`scanMessage`/`closed`; computed `present`/`missing`/`remaining`/`canStart`; methods `loadReferentials()`/`start()`/`resolve(_:)`/`toggle(_:)`/`finish()`/`close()`.

- [ ] **Step 1: Create the file**

Create `ScoutMateriel/ViewModels/InventoryViewModel.swift`:

```swift
import Foundation
import ScoutKit

/// Périmètre d'une session d'inventaire : un seul axe (localisation OU catégorie).
enum InventoryScope: Hashable {
    case location(ItemLocation)
    case category(ItemCategory)
}

@MainActor
final class InventoryViewModel: ObservableObject {
    enum Phase { case scope, scanning, summary }

    @Published var phase: Phase = .scope
    @Published var useLocation = true
    @Published var selectedLocationId: String?
    @Published var selectedCategoryId: String?
    @Published var expected: [Item] = []
    @Published var pointedIds: Set<String> = []
    @Published var extras: [Item] = []
    @Published var manualCode = ""
    @Published var categories: [ItemCategory] = []
    @Published var locations: [ItemLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var scanMessage: String?
    @Published var closed = false

    private let itemService = ItemService()
    private let qrService = QRCodeService()

    var present: [Item] { expected.filter { pointedIds.contains($0.id) } }
    var missing: [Item] { expected.filter { !pointedIds.contains($0.id) } }
    var remaining: Int { missing.count }
    var canStart: Bool { useLocation ? selectedLocationId != nil : selectedCategoryId != nil }

    func loadReferentials() async {
        let cats = try? await itemService.listCategories()
        let locs = try? await itemService.listLocations()
        categories = cats ?? []
        locations = locs ?? []
        if cats == nil && locs == nil {
            errorMessage = "Impossible de charger catégories/localisations."
        }
    }

    func start() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let items = useLocation
                ? try await itemService.list(locationId: selectedLocationId)
                : try await itemService.list(categoryId: selectedCategoryId)
            expected = items
            pointedIds = []
            extras = []
            scanMessage = nil
            phase = .scanning
        } catch {
            errorMessage = "Impossible de charger le matériel du périmètre."
        }
    }

    func resolve(_ raw: String) {
        manualCode = ""
        guard let code = TagCode.parse(raw) else {
            scanMessage = "Code invalide. Format attendu : TAG-000001."
            return
        }
        Task {
            do {
                guard let tag = try await qrService.tag(byCode: code) else {
                    scanMessage = "QR inconnu."
                    return
                }
                guard tag.status == .assigned, let itemId = tag.assignedItemId else {
                    scanMessage = "Étiquette non associée à un objet."
                    return
                }
                if let item = expected.first(where: { $0.id == itemId }) {
                    pointedIds.insert(item.id)
                    scanMessage = "✓ \(item.name)"
                } else if let item = try await itemService.get(id: itemId) {
                    if !extras.contains(where: { $0.id == item.id }) { extras.append(item) }
                    scanMessage = "En trop : \(item.name) (hors périmètre)"
                } else {
                    scanMessage = "Objet associé introuvable."
                }
            } catch {
                scanMessage = "Erreur de lecture. Réessaie."
            }
        }
    }

    func toggle(_ item: Item) {
        if pointedIds.contains(item.id) { pointedIds.remove(item.id) }
        else { pointedIds.insert(item.id) }
    }

    func finish() { phase = .summary }

    func close() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await itemService.markChecked(itemIds: present.map(\.id))
            closed = true
        } catch {
            errorMessage = "Impossible d'enregistrer l'inventaire. Réessaie."
        }
    }
}
```

- [ ] **Step 2: Add the file to the ScoutInventory target**

Run (from the repo root) — adds the file to the target via the `xcodeproj` gem:

```bash
ruby - <<'RUBY'
require 'xcodeproj'
rel = 'ScoutMateriel/ViewModels/InventoryViewModel.swift'
proj = Xcodeproj::Project.open('ScoutInventory.xcodeproj')
target = proj.targets.find { |t| t.name == 'ScoutInventory' } or abort 'target ScoutInventory not found'
abs = File.expand_path(rel)
if proj.files.any? { |f| f.real_path.to_s == abs }
  puts "already referenced: #{rel}"
else
  group = proj.main_group.find_subpath(File.dirname(rel), true)
  ref = group.new_file(abs)
  target.add_file_references([ref])
  puts "added: #{rel}"
end
proj.save
RUBY
```
Expected: prints `added: ScoutMateriel/ViewModels/InventoryViewModel.swift`.

- [ ] **Step 3: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **` (proves the file is compiled into the target). If it builds without compiling the new file, the membership step failed — re-run Step 2.

- [ ] **Step 4: Commit**

```bash
git add ScoutMateriel/ViewModels/InventoryViewModel.swift ScoutInventory.xcodeproj/project.pbxproj
git commit -m "feat(inventory): InventoryViewModel ephemeral session state machine

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: InventoryView (fullScreenCover flow)

**Files:**
- Create: `ScoutMateriel/Views/Inventory/InventoryView.swift` (add to `ScoutInventory` target)

**Interfaces:**
- Consumes: `InventoryViewModel` (Task 2), `SGDFColors`, `SGDFTheme`, `SGDFTextField`, `SGDFButton`, `Item`.
- Produces: `struct InventoryView: View` (no-arg init).

- [ ] **Step 1: Create the file**

Create `ScoutMateriel/Views/Inventory/InventoryView.swift`:

```swift
import SwiftUI
import ScoutKit

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .scope:    scopePhase
                case .scanning: scanningPhase
                case .summary:  summaryPhase
                }
            }
            .background(SGDFColors.background)
            .navigationTitle("Inventaire rapide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task { await viewModel.loadReferentials() }
            .onChange(of: viewModel.closed) { _, isClosed in if isClosed { dismiss() } }
            .alert("Erreur", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "") }
        }
    }

    // MARK: - Phase 1 : périmètre
    private var scopePhase: some View {
        Form {
            Section("Périmètre") {
                Picker("Filtrer par", selection: $viewModel.useLocation) {
                    Text("Localisation").tag(true)
                    Text("Catégorie").tag(false)
                }
                .pickerStyle(.segmented)
                if viewModel.useLocation {
                    Picker("Localisation", selection: $viewModel.selectedLocationId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(viewModel.locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                } else {
                    Picker("Catégorie", selection: $viewModel.selectedCategoryId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(viewModel.categories) { Text($0.name).tag(String?.some($0.id)) }
                    }
                }
            }
            Section {
                SGDFButton("Démarrer l'inventaire", kind: .primary, systemImage: "play.fill") {
                    Task { await viewModel.start() }
                }
                .disabled(!viewModel.canStart || viewModel.isLoading)
            }
        }
    }

    // MARK: - Phase 2 : scan / pointage
    private var scanningPhase: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Présent \(viewModel.present.count)/\(viewModel.expected.count)")
                    .foregroundStyle(SGDFColors.green)
                Spacer()
                Text("Non scanné \(viewModel.remaining)")
                    .foregroundStyle(SGDFColors.textSecondary)
                Spacer()
                Text("En trop \(viewModel.extras.count)")
                    .foregroundStyle(SGDFColors.orange)
            }
            .font(SGDFTheme.FontStyle.caption().weight(.semibold))
            .padding(SGDFTheme.Spacing.md)

            List {
                Section {
                    SGDFTextField("TAG-000001", text: $viewModel.manualCode, systemImage: "qrcode")
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    SGDFButton("Valider le code", kind: .secondary, systemImage: "checkmark") {
                        viewModel.resolve(viewModel.manualCode)
                    }
                    if let msg = viewModel.scanMessage {
                        Text(msg)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                }
                Section("À pointer") {
                    ForEach(viewModel.expected) { item in
                        Button { viewModel.toggle(item) } label: {
                            HStack(spacing: SGDFTheme.Spacing.md) {
                                Image(systemName: viewModel.pointedIds.contains(item.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.pointedIds.contains(item.id)
                                      ? SGDFColors.green : SGDFColors.textSecondary)
                                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                                    Text(item.name).foregroundStyle(SGDFColors.textPrimary)
                                    Text(item.inventoryCode)
                                        .font(SGDFTheme.FontStyle.caption())
                                        .foregroundStyle(SGDFColors.textSecondary)
                                }
                            }
                        }
                    }
                }
                if !viewModel.extras.isEmpty {
                    Section("En trop") {
                        ForEach(viewModel.extras) { item in
                            Text("\(item.name) — \(item.inventoryCode)")
                                .foregroundStyle(SGDFColors.orange)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            SGDFButton("Terminer", kind: .primary, systemImage: "flag.checkered") {
                viewModel.finish()
            }
            .padding(SGDFTheme.Spacing.md)
        }
    }

    // MARK: - Phase 3 : résumé
    private var summaryPhase: some View {
        List {
            Section {
                summaryRow("Présent", viewModel.present.count, SGDFColors.lightGreen)
                summaryRow("Manquant", viewModel.missing.count, SGDFColors.red)
                summaryRow("En trop", viewModel.extras.count, SGDFColors.orange)
            }
            if !viewModel.missing.isEmpty {
                Section("Manquants") {
                    ForEach(viewModel.missing) { item in
                        Text("\(item.name) — \(item.inventoryCode)")
                            .foregroundStyle(SGDFColors.textPrimary)
                    }
                }
            }
            if !viewModel.extras.isEmpty {
                Section("En trop") {
                    ForEach(viewModel.extras) { item in
                        Text("\(item.name) — \(item.inventoryCode)")
                            .foregroundStyle(SGDFColors.textPrimary)
                    }
                }
            }
            Section {
                SGDFButton("Clôturer l'inventaire", kind: .primary, systemImage: "checkmark.seal.fill") {
                    Task { await viewModel.close() }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func summaryRow(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(SGDFColors.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
        }
    }
}
```

- [ ] **Step 2: Add the file to the ScoutInventory target**

Run:
```bash
ruby - <<'RUBY'
require 'xcodeproj'
rel = 'ScoutMateriel/Views/Inventory/InventoryView.swift'
proj = Xcodeproj::Project.open('ScoutInventory.xcodeproj')
target = proj.targets.find { |t| t.name == 'ScoutInventory' } or abort 'target ScoutInventory not found'
abs = File.expand_path(rel)
if proj.files.any? { |f| f.real_path.to_s == abs }
  puts "already referenced: #{rel}"
else
  group = proj.main_group.find_subpath(File.dirname(rel), true)
  ref = group.new_file(abs)
  target.add_file_references([ref])
  puts "added: #{rel}"
end
proj.save
RUBY
```
Expected: prints `added: ScoutMateriel/Views/Inventory/InventoryView.swift`.

- [ ] **Step 3: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`. If the new file's symbols (`InventoryView`) are reported as unknown elsewhere, membership failed — re-run Step 2.

- [ ] **Step 4: Commit**

```bash
git add ScoutMateriel/Views/Inventory/InventoryView.swift ScoutInventory.xcodeproj/project.pbxproj
git commit -m "feat(inventory): InventoryView scope/scan/summary flow

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Enable the dashboard Inventaire button

**Files:**
- Modify: `ScoutMateriel/Views/Dashboard/DashboardView.swift`

**Interfaces:**
- Consumes: `InventoryView` (Task 3).
- Produces: nothing downstream.

- [ ] **Step 1: Add presentation state**

In `DashboardView` (the top-level view struct), add a state property after `@State private var initialLoadDone = false`:

```swift
    @State private var showInventory = false
```

- [ ] **Step 2: Enable the button**

Replace the disabled Inventaire button block (currently):

```swift
                        SGDFButton("Inventaire rapide (bientôt)", kind: .secondary, systemImage: "checklist") {
                        }
                        .disabled(true)
```
with:
```swift
                        SGDFButton("Inventaire rapide", kind: .secondary, systemImage: "checklist") {
                            showInventory = true
                        }
```

- [ ] **Step 3: Present the cover**

Attach a `.fullScreenCover` to the `ScrollView` — add it next to the existing `.refreshable { await viewModel.load() }` modifier (same modifier chain on the ScrollView):

```swift
            .fullScreenCover(isPresented: $showInventory) { InventoryView() }
```

- [ ] **Step 4: Build the ScoutInventory scheme**

Run:
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual simulator check (whole feature)**

Run the app: on the Dashboard, "Inventaire rapide" is enabled → tap it → the inventory cover appears. Pick a localisation → Démarrer → the expected items list shows; tap rows to mark present and/or type a valid `TAG-######` + Valider (a present item gets ✓; a TAG from another scope lands in "En trop"); the header counts update. Terminer → the summary shows Présent / Manquant / En trop; Clôturer → the cover dismisses. Reopen a present item from Matériel and confirm its last-inventory date updated. (Requires real items + assigned tags in the shared backend; camera is intentionally absent.)

- [ ] **Step 6: Commit**

```bash
git add ScoutMateriel/Views/Dashboard/DashboardView.swift
git commit -m "feat(dashboard): enable Inventaire rapide quick action (presents InventoryView)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Definition of done

- All 4 tasks committed; ScoutInventory builds clean (Task 1 also builds ScoutCamp).
- Manual runtime: scope → point present (checklist + manual TAG) → summary (Présent/Manquant/En trop) → close writes `last_checked_at`.
- No new tables; only `last_checked_at` written. Out of scope (deferred): live camera scanning, persistent inventory history, status changes for missing/extra items.
