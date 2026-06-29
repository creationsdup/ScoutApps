# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**ScoutInventory-iOS** — native SwiftUI iOS app for the scout (SGDF) field inventory
flow: **scan a QR tag → object sheet → field action**. It is a thin native client
over the same Supabase backend as the **CampManager** monorepo (a *separate* sibling
repo at `../CampManager`, Next.js web + Expo mobile + `packages/shared`). This repo
contains only the iOS app; there is no TypeScript here.

---

## Build / run

Single Xcode project, single scheme `ScoutInventory`, single target. No package
manager — **zero external dependencies**.

```bash
# Build for a simulator
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# List schemes / destinations
xcodebuild -list -project ScoutInventory.xcodeproj
```

Normal workflow is to open `ScoutInventory.xcodeproj` in Xcode (16+, tested on 26),
pick a simulator or device, and run (⌘R). iOS 17+.

**First-time setup — the Supabase key is required and not in git:**

```bash
cp Secrets.example.xcconfig Secrets.xcconfig   # then paste the anon key into it
```

Without `Secrets.xcconfig` the app builds but shows "clé Supabase manquante" instead
of connecting (Xcode also emits a base-config warning). The key comes from
CampManager's `apps/web/.env.local` → `NEXT_PUBLIC_SUPABASE_ANON_KEY`.

- There is **no test target** yet — don't claim tests pass; there are none to run.
- The **camera scanner does not work in the Simulator**. Use manual code entry
  (`TAG-000001`); real device for camera scan.

### Supabase credentials (key is out of source control)

The `anon` key is a public client key (security is enforced by Postgres RLS, not key
secrecy) but is still kept out of git so the repo carries no project credential. The
wiring, if you touch it:

- `Secrets.xcconfig` (**gitignored**) defines `SUPABASE_ANON_KEY`. `Secrets.example.xcconfig`
  is the committed template.
- It is the **base configuration** of both Debug/Release, so `$(SUPABASE_ANON_KEY)`
  is available as a build setting.
- `ScoutInventory/Info.plist` carries `SupabaseAnonKey = $(SUPABASE_ANON_KEY)`, which
  the build substitutes. (A custom `INFOPLIST_KEY_*` build setting does **not** work —
  Xcode only injects its own allowlisted keys into the generated plist, so a real
  `Info.plist` with `INFOPLIST_FILE` set is required. It's excluded from the
  synchronized-folder resource membership to avoid a duplicate-output build error.)
- `Config.swift` reads it at runtime via `Bundle.main.object(forInfoDictionaryKey:)`.
- The project **URL** is not secret and stays hardcoded in `Config.swift`.

To add another secret, follow the same chain: xcconfig var → `Info.plist` key → read
in `Config.swift`. Don't reintroduce hardcoded credentials in Swift.

---

## Architecture

```
ScoutInventory/
  ScoutInventoryApp.swift     @main; injects a single AppState into the environment
  Config.swift                Supabase URL + anon key (key read from Info.plist, see below)
  Info.plist                  carries SupabaseAnonKey = $(SUPABASE_ANON_KEY) for injection
  Models/Domain.swift         domain enums/structs — Swift mirror of CampManager's shared TS package
  Services/
    SupabaseService.swift     all network I/O: GoTrue auth + PostgREST REST (the only place URLSession lives)
    AppState.swift            @MainActor ObservableObject: session, role, selected event; facade over the service
  Views/
    RootView.swift            login ↔ MainTabView switch on isAuthenticated
    LoginView.swift           email + password
    MainTabView.swift         tabs: Scan / Matériel / Évènements
    ScanView.swift            VisionKit DataScanner + manual entry → resolveTag
    ItemDetailView.swift      object sheet + field action buttons
    MaterialListView.swift    browse inventory
    EventsListView.swift      browse / create events
```

**Layering is strict and worth preserving:**
`Views → AppState → SupabaseService → Supabase REST`. Views never touch the network
or `URLSession`; they call `AppState`. `AppState` is the only consumer of
`SupabaseService`. All HTTP lives in `SupabaseService` (one point of contact).

### Things that are easy to get wrong

- **`SupabaseService.createMovement` ordering is deliberate.** It PATCHes the item
  status (idempotent) *before* inserting the movement row (append-only journal), so a
  retry/replay is safe. Don't reorder these to "insert then update."

- **`MovementStatusMapping.nextStatus(for:)` in `Domain.swift` is the single source of
  truth** for action → resulting status. `AppState.runMovement` and
  `SupabaseService.createMovement` both derive the next status from it — never hardcode
  a status string for an action; extend the mapping.

- **Role guard.** Writes go through `AppState.runMovement`, which checks `canWrite`
  (`role.canWrite`; a `viewer` is read-only) before calling the service. Keep new
  write paths behind this guard. This mirrors `can_write_inventory` in the SQL/RLS.

- **Codable ↔ Postgres column names.** Domain structs use explicit `CodingKeys` to map
  camelCase Swift to snake_case columns (`tag_code`, `assigned_item_id`,
  `inventory_code`, …). New fields need their `CodingKeys` entry or decoding breaks.

- **Tag format** is validated by `TagCode.parse` — `^TAG-\d{6}$`, uppercased/trimmed.
  This mirrors `parseTagCode` in shared. `resolveTag` then branches on
  `QrTagStatus` (assigned / unassigned / disabled) and returns a `TagResolution`
  the view renders.

- **v1 is online-first.** There is no offline queue / action replay yet. Reads use
  `try?`-swallow-to-empty in `AppState`; writes surface errors via `AppError`.

The domain layer is intentionally a faithful mirror of CampManager's `shared` package.
When the backend contract changes (statuses, actions, columns), keep `Domain.swift`
in sync with that package rather than improvising.

---

## Design authority — SGDF color charter

ScoutInventory must be **immediately identifiable** as an SGDF app: sober, legible,
field-ready, professional. The institutional blue **`#003a5d`** is the visual anchor —
navigation, identity, primary buttons — and should stay dominant.

> Status today: the SwiftUI app does **not** yet define a theme or use chart colors
> (it relies on system defaults). When you introduce color, **centralize it** — a
> single Swift theme source (e.g. `ScoutInventory/Theme/`) defining these tokens and a
> status→color mapping — and import from there. **Never scatter hardcoded hex /
> `Color(red:…)` literals across views.** If a color isn't in the palette below, it
> doesn't exist in the app.

### Allowed palette

| Role | Hex | Usage |
|------|-----|-------|
| **Primary** — institutional blue | `#003a5d` | navigation, titles, primary buttons, QR scan, global identity |
| Orange | `#ff8300` | important actions, creation, checked-out, items to prepare |
| Light blue | `#0077b3` | information, availability, links, active filters |
| Red | `#d03f15` | error, deletion, broken / to-repair / missing |
| Dark green | `#007254` | validation, returns, OK status, completed checklist |
| Light green | `#65bc99` | light success, available, secondary confirmation |
| Violet | `#6e74aa` | program, activities, pedagogical organisation |

Neutrals (text/surfaces) stay sober — not "strong" colors. A color must **never** be
used outside its role (no orange for validation, no red for a filter).

### Status → color mapping (when implemented)

Map `ItemStatus` once, in the theme layer, not per-view:
`available → lightGreen`, `checked_out` / `cleaning_required → orange`,
`repair_required` / `missing → red`, `archived → neutral/textSecondary`.

### Forbidden

- ❌ Non-SGDF pastels, unsanctioned gradients, auto-generated / derived hues
- ❌ Framework-default accent colors left unchart­ed
- ❌ Hardcoded hex / `Color(...)` literals scattered in views
- ❌ Using a color outside its section role

---

## Notes

- Git is **local only** — no remote configured. Don't assume `git push` works.
- No app icon / asset catalog yet (dev placeholder).
- UI copy is in **French**; match it.
