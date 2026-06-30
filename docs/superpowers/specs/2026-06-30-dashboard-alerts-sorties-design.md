# Dashboard Alerts + Sorties — Design Spec

**Date:** 2026-06-30
**App:** ScoutMatériel (target `ScoutInventory`)
**Cycle:** 2 of 3 (Stock management ✓ → **Dashboard alerts + sorties** → Inventaire rapide)
**Status:** Approved for planning

## Context

The gap audit found the Dashboard implements the 4 stat cards but **0 of 6 alerts**, **no
"sorties en cours" section**, and only 2 of 5 quick actions (under a mislabeled "Raccourcis"
header). It also found no `DashboardService`. Separately, ScoutCamp manages **camps** (table
`camps`) that hold material via `camp_materials`, but those active camps never surface in
ScoutMatériel's dashboard — the two apps' view of "what material is out and where" is
disconnected.

This cycle builds the dashboard as a **read-only aggregation layer** over existing data: no
schema changes, no new write paths. The richer loan-event model (responsable, dates,
overdue) is explicitly deferred to a future cycle.

## Scope

In scope:
- A `DashboardService` in ScoutKit producing a `DashboardSnapshot` (counts + alerts +
  ongoing checkouts + ongoing camps).
- An **Alertes** section: 6 alert types, each clickable to a self-contained list of the
  offending items.
- A **Sorties en cours** section showing both open **checkouts** (bons de sortie) and active
  **camps** (from ScoutCamp) that hold material.
- **Actions rapides**: rename the "Raccourcis" header; add the 3 missing quick actions.

Out of scope (deferred):
- Any schema change. Specifically: `responsable`, start/end dates, expected-return-date, and
  the "En retard" (overdue) badge on checkouts — they require extending the `checkouts`
  table, which is a future "loan events" cycle.
- Cross-tab filtered navigation / new Matériel filters (Sans QR / Sans photo / Stock faible
  filter chips) — alerts use a self-contained list instead.
- The Inventaire rapide screen (cycle 3): its quick-action button ships disabled.
- A dedicated repair subsystem: "Signaler une réparation" is only a shortcut to Scan.

## Section A — Architecture & data

Introduce `DashboardService` (public, ScoutKit). Today the aggregation lives ad hoc in
`DashboardViewModel` over `ItemService` alone; moving it into a service matches the project's
layering (Views → ViewModels → Services → SupabaseClient) and the original spec.

`DashboardService.loadSnapshot()` aggregates, **without any schema change**, from existing
services:
- `ItemService.list(includeArchived: false)` → all active items.
- A **new read-only** `QRCodeService.assignedItemIds() -> Set<String>` — a single
  `select assigned_item_id from qr_tags where assigned_item_id is not null` — to know which
  items have a tag.
- `CheckoutService` (open checkouts + their lines) → "sorti >7j" alert + ongoing checkouts.
- `CampService.list()` + `CampMaterialService.items(campId:)` per camp → ongoing camps.

Returned types (all `public`):
```swift
public struct DashboardSnapshot {
    public var total: Int
    public var available: Int
    public var checkedOut: Int
    public var toRepair: Int
    public var alerts: [DashboardAlert]          // only those with a non-empty item list
    public var ongoingCheckouts: [OngoingCheckout]
    public var ongoingCamps: [OngoingCamp]
}

public struct DashboardAlert: Identifiable {     // id = kind
    public enum Kind: String { case checkedOutOver7d, toRepair, missingQR, missingPhoto, lowStock, toVerify }
    public let kind: Kind
    public let items: [Item]                     // count = items.count
    public var id: String { kind.rawValue }
}

public struct OngoingCheckout: Identifiable {    // id = checkout.id
    public let checkout: Checkout
    public let totalItems: Int                   // Σ line.quantity
    public let returnedItems: Int                // Σ line.quantityReturned
    public var id: String { checkout.id }
    public var returnRate: Double                // totalItems == 0 ? 0 : returnedItems / totalItems
}

public struct OngoingCamp: Identifiable {        // id = camp.id
    public let camp: Camp
    public let items: [Item]                     // assigned material (for the tap-through list)
    public var id: String { camp.id }
    public var itemCount: Int { items.count }
}
```

`DashboardViewModel` is refactored to call `DashboardService.loadSnapshot()` and publish the
`DashboardSnapshot`. The 4 stat cards read `snapshot.total/available/checkedOut/toRepair`
(same values as today: total = items.count; available = status `.disponible`; checkedOut =
status `.sorti`; toRepair = status `.aReparer`). Errors continue to surface via the existing
`errorMessage` path.

**Performance note:** ongoing-camps computation is N+1 (one `items(campId:)` query per camp).
The number of camps is small, so this is acceptable; documented as a known minor cost.

## Section B — Alertes

A new "Alertes" section under the stat cards, rendered only if at least one alert has a
non-empty item list. Each alert is an `AlertCard` (private Dashboard view): SF Symbol icon +
French label + count, colored via `SGDFColors` tokens per role. The 6 kinds, all computed in
`DashboardService.loadSnapshot()`:

| Kind | Label | Computation | Color token |
|---|---|---|---|
| `checkedOutOver7d` | Sortis depuis +7 jours | items on lines of **open** checkouts whose `createdAt` < today−7d and `quantity > quantityReturned` | `orange` |
| `toRepair` | À réparer | `status == .aReparer` | `red` |
| `missingQR` | Sans QR code | `id ∉ assignedItemIds` | `red` |
| `missingPhoto` | Sans photo | `imagePath == nil` | `textSecondary` |
| `lowStock` | Stock faible | `item.isLowStock` (from cycle 1) | `orange` |
| `toVerify` | À vérifier | `status == .aVerifier` | `orange` |

- `Checkout.createdAt` (ISO String) is parsed with the existing `DateFormatters`; the "−7
  days" comparison uses the current runtime date.
- For `checkedOutOver7d`, items are resolved from the open checkouts' `CheckoutLine.item`
  (lines already join `inventory_items(*)`), deduplicated by item id.

**Click behavior:** each `AlertCard` is a `NavigationLink` (inside the Dashboard's
`NavigationStack`) to a self-contained `AlertItemsListView(title: String, items: [Item])`
that lists the offending items (a simplified row showing name + code + status badge), each row
pushing the existing `MaterialDetailView`. No cross-tab plumbing, no new Matériel filters.

## Section C — Sorties en cours, camps, quick actions, header

### Sorties en cours (checkouts + camps)
Under the alerts, a "Sorties en cours" section renders two kinds of cards:

- **`OngoingCheckoutCard`** (one per `snapshot.ongoingCheckouts`): label, creation date
  (formatted FR via `DateFormatters`), item count, **return rate** (e.g. "3/8 rendus — 38 %"),
  badge "Ouvert" (`orange`). Tapping pushes the existing `CheckoutDetailView`.
- **`OngoingCampCard`** (one per `snapshot.ongoingCamps`): camp name, dates `start–end`
  (FR; omit if nil), branch label (if set), item count, badge "Camp" (`violet` — the
  charter's programme/camp role). Tapping pushes `AlertItemsListView(title: camp.name,
  items: camp.items)` — the same item-list view as alerts (ScoutMatériel has no camp detail
  screen; the camp's material list is the useful destination).

A camp qualifies as ongoing when it holds ≥ 1 assigned item (material still out). If both
`ongoingCheckouts` and `ongoingCamps` are empty, the section is omitted (or shows a light
`EmptyStateView`).

### Actions rapides
The "Raccourcis" header is renamed **"Actions rapides"** (spec compliance). The 5 buttons:
1. Ajouter matériel → `router.selectedTab = .material` *(existing)*
2. Scanner un QR → `router.selectedTab = .scan` *(existing)*
3. **Préparer une sortie** → `router.selectedTab = .sorties`
4. **Inventaire rapide** → button **disabled**, label "Inventaire rapide (bientôt)"
   (enabled in cycle 3)
5. **Signaler une réparation** → `router.selectedTab = .scan` (shortcut: scan the item, then
   use the existing "Réparation" movement action on its detail screen)

## Design-system compliance
All colors via `SGDFColors` / `StatusColorMapper` — no raw hex, no `Color(...)`, no framework
default accents. Alert/camp/checkout badge colors use the charted role tokens (red, orange,
violet, textSecondary). New shared ScoutKit symbols are `public`.

## Verification
No XCTest target exists.
- `xcodebuild build` must succeed for **both** schemes (`DashboardService` lives in ScoutKit
  consumed by ScoutMatériel; ScoutCamp must still compile).
- Manual simulator check: alerts appear with correct counts; tapping an alert pushes the
  item list → detail; ongoing checkouts show return rate; active camps appear with their
  dates/branch/item count and tap to the camp's item list; the 5 quick actions navigate
  correctly (Inventaire rapide is visibly disabled). Runtime depends on real data
  (items / checkouts / camps in the shared backend).

## Risks / notes
- Read-only over a **shared backend**: no writes, no schema changes — zero risk to
  CampManager.
- N+1 query for ongoing camps (one `items(campId:)` per camp) — acceptable at the expected
  small camp count; revisit if camp volume grows.
- "Sorti >7j" relies on `Checkout.createdAt`; items taken out only via `camp_materials`
  (no checkout) are covered by the camps section, not this alert — intentional, since the
  alert is about un-returned bons de sortie.
