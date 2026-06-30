# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**ScoutManager** (SGDF scout-group management) was split into **two native SwiftUI iOS apps
sharing one local Swift package**, all in the single `ScoutInventory.xcodeproj`:
- **ScoutMatériel** — the original app (target `ScoutInventory`, scheme `ScoutInventory`,
  product `ScoutInventory.app`, bundle id `com.scout.manager`). Tabs: Dashboard, Matériel,
  Scan. Source under `ScoutMateriel/`.
- **ScoutCamp** — the camp app (target/scheme `ScoutCamp`, bundle id `com.scout.camp`).
  Tabs: Intendance, Programme. Source under `ScoutCamp/`.
- **ScoutKit** — local Swift package (`ScoutKit/`, `import ScoutKit`) holding ALL shared code:
  Models, Services (incl. the single `SupabaseService.shared`), Stores (`SessionStore`,
  `CampStore`), DesignSystem, Components, Config, `LoginView`. Its public API is `public`.
  Depends on **supabase-swift** (SPM).

The **Supabase backend is shared with CampManager** (a separate web project; ScoutCamp is the
mobile-first replacement of its camp features for this group). This is the single most
important constraint — see "Shared backend" below.

---

## Build / run

One Xcode project, **two app schemes** (`ScoutInventory` = ScoutMatériel, `ScoutCamp`) +
the local **ScoutKit** package. Dependency: **supabase-swift** (SPM, via ScoutKit).

```bash
# Build each app (use a simulator that exists — list with: xcrun simctl list devices)
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'generic/platform=iOS Simulator' build      # ScoutMatériel
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp \
  -destination 'generic/platform=iOS Simulator' build      # ScoutCamp

# Resolve SPM packages
xcodebuild -resolvePackageDependencies -project ScoutInventory.xcodeproj -scheme ScoutInventory
```

- **First-time setup — Supabase anon key is required and not in git:**
  `cp Secrets.example.xcconfig Secrets.xcconfig` then paste the anon key. Without it an
  app builds but shows "clé Supabase manquante". Chain: `Secrets.xcconfig`
  (`SUPABASE_ANON_KEY`, gitignored) → base config of Debug/Release of **both targets** →
  each app's Info.plist (`ScoutInventory/Info.plist` for ScoutMatériel, `ScoutCamp/App/Info.plist`
  for ScoutCamp) carries `SupabaseAnonKey = $(SUPABASE_ANON_KEY)` → `Config.swift` (in ScoutKit)
  reads `Bundle.main` at runtime.
- **No XCTest target exists** — don't claim tests pass; verify by `xcodebuild build` (both
  schemes) and by running the apps.
- **Project edits:** both apps use **classic groups** (not synchronized folders), so a NEW
  `.swift` file must be added to its target in Xcode (or via the `xcodeproj` Ruby gem) — it is
  NOT auto-compiled. The shared package `ScoutKit/Sources/ScoutKit/` IS folder-based (any file
  added there is part of the module). SourceKit shows stale "Cannot find X / No such module
  'ScoutKit'/'Supabase'" diagnostics constantly; only `xcodebuild` is authoritative.
- **Shared code must be `public`:** a symbol used by an app from ScoutKit must be `public`
  (incl. a `public init` to construct shared structs). A missing one shows
  "inaccessible due to 'internal' protection level" at build.
- **Camera scan does not work in the Simulator** — use manual code entry (`TAG-000001`).
- Git is **local only** (no remote). UI copy is in **French** — match it.

---

## Architecture (MVVM)

```
ScoutManager/
  App/            ScoutManagerApp (@main), RootView (login ↔ tabs), MainTabView (5 tabs),
                  AppRouter (tab selection), Config, Info.plist
  DesignSystem/   SGDFColors, SGDFTheme, StatusColorMapper, Color+Hex (see charter below)
  Components/     SGDFButton, SGDFCard, SGDFBadge, SGDFTextField, EmptyStateView, LoadingView
  Models/         Enums (ItemStatus/ItemCondition/TrackingType/Branch/UserRole), Item,
                  ItemCategory, ItemLocation, QRCode, MovementHistory
  Services/       SupabaseService (SDK client + auth), ItemService, ImageStorageService,
                  QRCodeService
  Stores/         SessionStore (@MainActor: auth session + role)
  ViewModels/     DashboardViewModel, MaterialListViewModel, MaterialFormViewModel, ScannerViewModel
  Views/          Dashboard/, Material/, Scan/, Placeholder/ (Intendance & Camp tabs are
                  ComingSoonView until built)
supabase/migrations/   SQL run by the user in the Supabase SQL editor
docs/superpowers/specs|plans/   design spec + per-increment implementation plans
```

**Strict layering:** `Views → ViewModels/Stores → Services → SupabaseClient`. Views never
touch the network. `SupabaseService.shared.client` is the **only** `SupabaseClient` — all
services reuse it. ViewModels/Stores are `@MainActor ObservableObject`.

**What's built (MVP-1):** design system, 5-tab shell, SDK auth (login), Dashboard (stats),
Material module (list/search/filters/detail/add/edit/image/archive), Scan core (resolve
tag → fiche). **Not yet:** blank-QR assign/generate, quick status change + movements,
Intendance, Camp program.

---

## Shared backend (the critical constraint)

The Supabase project is shared with CampManager. **Never mutate existing data, column
types, or enum values** — it would break CampManager and existing DB views (e.g.
`dashboard_stats` depends on `inventory_items.status`). Migrations must be **additive
only** (new tables/columns, `ADD VALUE` to enums, new RLS, buckets).

Consequences baked into the code:
- `ItemStatus` rawValues are the **existing English DB enum values** (`available`,
  `checked_out`, `cleaning_required`, `repair_required`, `missing`, `archived`) plus the two
  additively-added (`reserve`, `indisponible`). The French is only the `.label`. Same for
  `ItemCondition` (`excellent/good/fair/damaged/broken` with French labels).
- The app reuses existing tables: `inventory_items`, `qr_tags`, `item_movements`, `events`,
  `profiles`; and adds `categories`, `locations`, the `item-images` Storage bucket, and
  additive columns on `inventory_items`.

## Things easy to get wrong

- **Codable ↔ snake_case columns** via explicit `CodingKeys` (`inventory_code`,
  `assigned_item_id`, `category_id`, …). A new field needs its key or decoding breaks.
- **Tag format**: `TagCode.parse` → `^TAG-\d{6}$`. `ScannerViewModel.resolve` branches on
  `QRCode.status` (assigned/unassigned/disabled).
- **Item id on create**: generate a client `UUID().uuidString` (Postgres accepts a provided
  uuid). On **edit**, preserve `quantityAvailable` (don't reset it to `quantity`).
- **Role guard** (future write paths): gate on `SessionStore.canWrite` (viewer = read-only),
  mirroring the SQL `can_write_inventory` / RLS.
- Surface errors to the user (no swallowed `try?` on user-triggered writes like archive).

---

## Design authority — SGDF color charter (implemented)

The app must be immediately identifiable as SGDF: sober, legible, field-ready. **`#003a5d`
is dominant** (nav/tab tint, titles, primary buttons, scan identity).

**The Design System is the single source of color.** No view writes `Color.blue`, `.white`,
a hex, or `Color(red:…)`. The `Color(hex:)` helper is confined to `DesignSystem/`. Colors
come from `SGDFColors`; status colors from `StatusColorMapper`; spacing/radius/typography
from `SGDFTheme`; `SGDFColors.onColor` is the white-on-strong-fill token.

| Token | Hex | Role |
|-------|-----|------|
| `primaryBlue` | `#003a5d` | navigation, titles, primary buttons, scan, identity |
| `orange` | `#ff8300` | important/quick actions, creation, checked-out |
| `lightBlue` | `#0077b3` | information, events |
| `red` | `#d03f15` | error, deletion, broken/repair/missing |
| `green` | `#007254` | validation, returns, OK |
| `lightGreen` | `#65bc99` | available, light success |
| `violet` | `#6e74aa` | program, reserved |
| neutrals | `background #F7F8FA`, `surface #FFFFFF`, `border #E3E6EB`, `textPrimary #003a5d`, `textSecondary #5B6B7A`, `onColor #FFFFFF` |

Status mapping lives once in `StatusColorMapper`: disponible→lightGreen, réservé→violet,
sorti/à vérifier→orange, à réparer/indisponible/perdu→red, archivé→textSecondary. A color
must never be used outside its role.

**Forbidden:** non-SGDF pastels, unsanctioned gradients, framework default accents, hardcoded
hex/`Color(...)` in views, a color used outside its role.

---

## Workflow notes

This branch (`feature/scoutmanager-mvp1`) was built via the superpowers
subagent-driven-development flow: specs in `docs/superpowers/specs/`, per-increment plans in
`docs/superpowers/plans/`, a progress ledger in `.superpowers/sdd/progress.md`. Each task is
build-verified and reviewed before the next.
