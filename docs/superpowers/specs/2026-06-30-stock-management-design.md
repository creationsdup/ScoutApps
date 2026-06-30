# Stock Management — Design Spec

**Date:** 2026-06-30
**App:** ScoutMatériel (target `ScoutInventory`)
**Cycle:** 1 of 3 (Stock management → Dashboard alerts+sorties → Inventaire rapide)
**Status:** Approved for planning

## Context

A spec-vs-implementation gap audit found that the Matériel module has **no real stock
concept**: `inventory_items` carries `quantity` (total) and `quantity_available`, but there
is no minimum threshold, no unit, no manual stock adjustment, and no low-stock visibility.
Checkout RPCs already maintain `quantity_available` on out/return. This cycle adds genuine
quantity-tracked stock management for `global` items, additively, without breaking the
shared CampManager backend.

## Scope

In scope (this cycle):
- Stock fields on quantity-tracked items: **seuil minimum** (`minimum_threshold`) and
  **unité** (`unit`).
- Manual **+/- stock adjustment** on the detail screen: adjusts the **total**; disponible
  follows by the same delta, clamped to `[0, total]`. Status is never changed.
- Each adjustment is **recorded as a movement** (`item_movements`, action `adjustment`,
  signed `quantity`, optional `note`).
- Low-stock visibility on **detail + form + list row**.

Out of scope (explicit — handled in later cycles):
- Dashboard "stock faible" alert (cycle 2).
- The full horizontal filter-chip row, including a "Stock faible" filter.
- Haptics / VoiceOver polish.
- History **display** (adjustments are write-only for now).
- Auto code generation.

`specifique` (individual) items are unaffected: they stay qty-1 and show no stock section.
All stock UI/logic is gated on `trackingType == .global`.

## Section A — Data model (additive only)

### SQL migration: `supabase/migrations/20260701_stock_management.sql`
- `inventory_items`:
  - `add column if not exists minimum_threshold integer;`
  - `add column if not exists unit text;`
  - Add a **`NOT VALID` CHECK** constraint restricting `unit` to the allowed values,
    mirroring the existing `inventory_items_tracking_type_chk` / `inventory_items_branch_chk`
    pattern in `20260629_scoutmanager_mvp1.sql` (drop-if-exists then add; do not `VALIDATE`,
    to stay safe on the shared table with pre-existing rows).
- `item_movements`:
  - `add column if not exists quantity integer;`
  - `add column if not exists note text;`
- No enum changes (`item_movements.action` is plain `text`). No data mutation. Nothing
  CampManager or existing views depend on is altered.

### Swift (ScoutKit)
- New enum `ItemUnit: String, Codable, CaseIterable` with cases
  `piece / lot / boite / paquet / metre / litre / autre` and French labels
  (Pièce / Lot / Boîte / Paquet / Mètre / Litre / Autre). rawValues are the strings stored
  in `inventory_items.unit` and must match the SQL CHECK constraint exactly.
- `Item` gains:
  - `minimumThreshold: Int?` (CodingKey `minimum_threshold`)
  - `unit: ItemUnit?` (CodingKey `unit`)
  - Update `init` (with defaults `nil`) and `CodingKeys`.
  - Computed (non-stored) helpers:
    - `quantityOut: Int { max(0, quantity - (quantityAvailable ?? quantity)) }`
    - `isLowStock: Bool` — only meaningful for `global`:
      `if let t = minimumThreshold { (quantityAvailable ?? quantity) < t } else { false }`
- `MovementHistory` gains `quantity: Int?` and `note: String?` (CodingKeys `quantity`,
  `note`), with `init` defaults `nil` and `CodingKeys` updated.
- `MovementAction` gains case `.adjustment` (rawValue `adjustment`, label "Ajustement").
  **Invariant: an adjustment never changes item status.** The stock-adjust path sets
  quantities only and does not consult `nextStatus`. `nextStatus` is a non-optional switch,
  so its `.adjustment` branch must return *something*; since the value is never read for
  adjustments, it returns `.disponible` as an inert default. `.adjustment` is also excluded
  from the detail movement-action menu (Section C), so it never reaches `nextStatus` via the
  generic action UI.

## Section B — Services & business logic

`ItemService` gains:

```swift
@discardableResult
func adjustStock(itemId: String, delta: Int, note: String?) async throws -> Item
```

Behavior:
1. Fetch the item.
2. Compute `newTotal = max(0, quantity + delta)` and
   `newAvailable = clamp((quantityAvailable ?? quantity) + delta, 0, newTotal)`.
3. Update `inventory_items` with a **partial Encodable payload** (`quantity`,
   `quantity_available` only) — not the full `Item`. This also addresses the deferred
   "update sends full Item" tech-debt note for this write path.
4. Insert an `item_movements` row: `action: "adjustment"`, `quantity: delta` (signed),
   `note`, `user_id` (current session user).
5. Return the updated `Item` so the ViewModel refreshes without a re-fetch.

Guards:
- Valid only for `trackingType == .global` (caller enforces; method may assert/no-op
  defensively).
- Gated on `SessionStore.canWrite` (viewer = read-only), mirroring RLS.
- Errors surfaced to the user (no swallowed `try?`).
- Status is never modified by an adjustment.

## Section C — UI

### Detail — `MaterialDetailView`
For `global` items, add a "Stock" card:
- Rows: Total / Disponible / Sortie (`item.quantityOut`, computed) / Seuil + unité.
- A `−  [qty]  +` stepper that calls the ViewModel → `ItemService.adjustStock`.
- Optional note field for the adjustment.
- A low-stock warning row when `item.isLowStock`, colored via `StatusColorMapper`
  (red/orange tokens) — never a raw hex.
- The generic movement-action menu (currently `MovementAction.allCases`) is filtered to
  **exclude `.adjustment`** (adjustments come from the stepper, not the action list).

`specifique` items: no stock card (unchanged behavior).

### Form — `MaterialFormView` / `MaterialFormViewModel`
- When tracking = `global`: show a Seuil minimum stepper and an Unité picker, alongside the
  existing total/available inputs.
- When tracking = `specifique`: hide seuil/unité; pin total to 1 (existing behavior).
- Persist `minimumThreshold` and `unit` on create/update.

### List row — `MaterialRow`
- For `global` items: show "Dispo X / Y" and a low-stock badge (`SGDFBadge`) when
  `isLowStock`.
- No new filter chip this cycle.

## Design-system compliance
All colors via `SGDFColors` / `StatusColorMapper`; no raw hex or `Color(...)` in views.
Low-stock uses the red/orange status tokens per their roles. New shared symbols in ScoutKit
that the apps consume are `public`.

## Verification
No XCTest target exists.
- `xcodebuild build` must succeed for **both** schemes (`ScoutInventory` and `ScoutCamp`).
- Manual simulator check: open a `global` item, adjust stock up/down, confirm total +
  disponible update and persist, confirm low-stock badge/warning appears below threshold,
  confirm a `specifique` item shows no stock card.
- SQL migration run by the user in the Supabase SQL editor; runtime validation after that.

## Risks / notes
- Shared backend: every DB change is additive and `IF NOT EXISTS`; the `unit` CHECK is
  `NOT VALID` so it does not fail on pre-existing rows.
- `quantity_available` is also mutated by checkout RPCs; manual adjustment and checkout are
  independent paths over the same column — adjustment clamps to the current total, so the
  two cannot drive disponible out of `[0, total]`.
