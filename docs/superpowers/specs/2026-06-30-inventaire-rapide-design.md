# Inventaire Rapide — Design Spec

**Date:** 2026-06-30
**App:** ScoutMatériel (target `ScoutInventory`)
**Cycle:** 3 of 3 (Stock management ✓ → Dashboard alerts + sorties ✓ → **Inventaire rapide**)
**Status:** Approved for planning

## Context

The gap audit found the entire "Inventaire rapide" screen (spec Screen 8) unbuilt: no
session, no present/missing/extra logic, no summary, no last-inventory-date update. This
cycle builds it as an **ephemeral, in-memory** flow that, on close, writes only
`inventory_items.last_checked_at` for the items found present. No new tables. It also enables
the "Inventaire rapide" quick-action button that cycle 2 shipped disabled.

`Item` already carries `lastCheckedAt` (`last_checked_at`, additive column from earlier
work, unused by CampManager). The QR scanning infrastructure exists: `QRCameraView` (a
top-level reusable `struct`), `TagCode.parse` (`^TAG-\d{6}$`), and
`QRCodeService.tag(byCode:)` → tag → `assignedItemId`. The camera does not work in the
Simulator, so manual code entry + a manual checklist are first-class.

## Scope

In scope:
- An ephemeral inventory session: pick a scope (one location OR one category), point items
  present (camera scan, manual TAG entry, or manual checklist tap), see live counts, get a
  summary (Présent / Manquant / En trop), and close.
- On close: write `last_checked_at = now` for present items only.
- Enable the dashboard "Inventaire rapide" quick action → presents the flow in a
  `fullScreenCover`.

Out of scope (deferred / not built):
- Persistent inventory sessions/history (no `inventory_sessions` / `inventory_checks`
  tables). Decided: ephemeral only.
- Combining location AND category (scope is exactly one of the two).
- An explicit "mark missing" gesture (missing = expected-and-not-pointed at close).
- Changing item status for missing/extra items (only `last_checked_at` of present items is
  written).
- A new permanent tab (the flow is presented modally from the dashboard).

## Section A — Architecture & data

No new tables. An ephemeral session driven by a ViewModel, plus one targeted write method.

**Scope type:**
```swift
enum InventoryScope: Hashable {
    case location(ItemLocation)
    case category(ItemCategory)
}
```

**`InventoryViewModel`** (`@MainActor final class … : ObservableObject`, in
`ScoutMateriel/ViewModels/InventoryViewModel.swift`):
- Phase machine: `enum Phase { case scope, scanning, summary }`, `@Published var phase = .scope`.
- State: `@Published var scope: InventoryScope?`, `expected: [Item] = []`,
  `pointedIds: Set<String> = []`, `extras: [Item] = []` (en trop, deduped by id),
  `manualCode = ""`, `categories: [ItemCategory] = []`, `locations: [ItemLocation] = []`,
  `isLoading = false`, `errorMessage: String?`, `scanMessage: String?`, `closed = false`.
- Derived (computed): `present: [Item] { expected.filter { pointedIds.contains($0.id) } }`,
  `missing: [Item] { expected.filter { !pointedIds.contains($0.id) } }`,
  `remaining: Int { missing.count }` (the live "Non scanné" count).
- Methods:
  - `loadReferentials() async` — loads categories + locations via `ItemService`.
  - `start(scope: InventoryScope) async` — sets scope, loads `expected` via
    `ItemService.list(categoryId:locationId:)` (the matching axis; the other nil), resets
    `pointedIds`/`extras`, `phase = .scanning`. Surfaces `errorMessage` on failure.
  - `resolve(_ rawCode: String)` — `TagCode.parse` → `QRCodeService.tag(byCode:)`. If the tag
    resolves to an item id that is in `expected`: `pointedIds.insert(id)`, success
    `scanMessage`. If it resolves to a known item NOT in `expected`: append the item to
    `extras` (deduped), "en trop" `scanMessage`. If the tag is unknown/unassigned or the code
    is malformed: `scanMessage` error. Clears `manualCode` after a manual submit.
  - `toggle(_ item: Item)` — manual check/uncheck of an expected item
    (insert/remove in `pointedIds`).
  - `finish()` — `phase = .summary`.
  - `close() async` — `try ItemService().markChecked(itemIds: present.map(\.id))`, on success
    `closed = true`; on failure set `errorMessage` (no swallowed `try?`).

**`ItemService.markChecked(itemIds: [String]) async throws`** (ScoutKit, additive):
- No-op when `itemIds` is empty.
- Bulk partial update: `update(LastCheckedPayload(last_checked_at: <ISO-8601 now>))
  .in("id", values: itemIds)`, using a `private struct LastCheckedPayload: Encodable { let last_checked_at: String }`
  (mirrors the existing `StockPayload`/`ArchivePayload` partial-update pattern). The service
  computes the timestamp (`ISO8601DateFormatter().string(from: Date())`); the ViewModel does
  not deal with dates.
- Writes only the existing additive `last_checked_at` column — safe on the shared backend.

**New app-target files** (added to the `ScoutInventory` target via the `xcodeproj` Ruby gem,
already available at 1.27.0): `ScoutMateriel/ViewModels/InventoryViewModel.swift` and
`ScoutMateriel/Views/Inventory/InventoryView.swift`. `ItemService.swift` (ScoutKit,
folder-based) gains `markChecked` with no project change.

## Section B — UI flow (`InventoryView`, presented in a `fullScreenCover`)

`InventoryView` is a `NavigationStack` with a **Fermer** toolbar button (dismisses the
cover). It switches on `viewModel.phase`:

**1. Scope (`.scope`):** a segmented `Picker` Localisation / Catégorie, then a `Picker`
listing the loaded locations or categories. A **Démarrer l'inventaire** button (disabled
until a value is chosen) → `start(scope:)`.

**2. Scanning (`.scanning`):** a progress header — "Présent X / N attendus · Non scanné R ·
En trop E". Below:
- **Camera:** `QRCameraView { code in viewModel.resolve(code) }` (reused). Inoperative in
  the Simulator.
- **Manual entry:** `SGDFTextField` placeholder "TAG-000001" + a Valider button →
  `resolve(manualCode)`. `scanMessage` shows the outcome (present ✓ / en trop / inconnu).
- **Checklist of expected items:** a list of `expected`; each row (name + code + status
  badge) has a check indicator; tap → `toggle(item)`. Present items render checked.
- **En trop:** a small section listing `extras`, colored `SGDFColors.orange`.
- A **Terminer** button → `finish()` (`phase = .summary`).

**3. Summary (`.summary`):** three `SGDFCard` counters — **Présent** (`SGDFColors.lightGreen`),
**Manquant** (`SGDFColors.red`), **En trop** (`SGDFColors.orange`), each expandable to the
list of items. A **Clôturer l'inventaire** button → `close()`.

All colors via `SGDFColors` / `StatusColorMapper` (no raw hex / `Color(...)` / default
accents). French UI copy throughout.

## Section C — Closure & dashboard activation

- `close()` calls `ItemService.markChecked(itemIds: present.map(\.id))` (writes
  `last_checked_at = now`), handles errors via `errorMessage` (no swallowed `try?`), then
  sets `closed = true`; `InventoryView` observes `closed` and dismisses the cover.
- **Missing and extra items change no status** — only present items' `last_checked_at` is
  written.
- **Dashboard:** the cycle-2 "Inventaire rapide (bientôt)" button becomes "**Inventaire
  rapide**", enabled. Targeted edit in `DashboardView.swift`: drop `.disabled(true)` and the
  "(bientôt)" suffix; add a `@State private var showInventory = false`; the button sets it
  true; attach `.fullScreenCover(isPresented: $showInventory) { InventoryView() }`.

## Design-system compliance
Colors only via `SGDFColors` / `StatusColorMapper`; no raw hex, no `Color(...)`, no framework
default accents. Reuse `SGDFCard`, `SGDFButton`, `SGDFTextField`, `SGDFBadge`,
`EmptyStateView`. New ScoutKit symbols (`markChecked`) are `public`.

## Verification
No XCTest target exists.
- `xcodebuild build` must succeed for the **ScoutInventory** scheme (the new files must be
  members of the target — proven by the build compiling them) and for **ScoutCamp** (ScoutKit
  changed via `markChecked`).
- Manual simulator check (camera unavailable → use manual paths): start an inventory scoped
  to a location, mark some expected items present via the checklist and by typing a valid
  `TAG-######`, type a TAG belonging to another scope to see it land in "En trop", finish →
  the summary shows consistent Présent / Manquant / En trop, close → reopening a present item
  shows an updated last-inventory date.

## Risks / notes
- The only write is `last_checked_at` on present items (existing additive column) — safe for
  the shared CampManager backend; no schema change.
- `resolve` reuses the established tag-parse / `tag(byCode:)` lookup; an unassigned or unknown
  tag yields a user-facing `scanMessage`, never a silent failure.
- New app-target files require `xcodeproj`-gem target membership; if the gem step fails the
  files won't compile into the app — the implementation task must verify the build picks them
  up.
