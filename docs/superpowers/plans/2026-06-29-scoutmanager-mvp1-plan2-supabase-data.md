# ScoutManager MVP‑1 — Plan 2 : Supabase SDK + Auth + Données

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Migrer l'app du REST/URLSession maison vers le **SDK officiel supabase-swift** :
client SDK, authentification portée sur le SDK, retrait du legacy `ScoutInventory/`,
modèles ScoutManager, et services data (matériel, images, QR).

**Architecture:** `Views → ViewModels/Stores → Services (SDK) → SupabaseClient`. Un
seul `SupabaseService` expose le `SupabaseClient`. Les services métier (`ItemService`,
`ImageStorageService`, `QRCodeService`) l'utilisent. Schéma : **extension de l'existant**
(cf. `supabase/migrations/20260629_scoutmanager_mvp1.sql`), tables réutilisées
`inventory_items` / `qr_tags` / `item_movements` / `events`, + `categories` / `locations`.

**Tech Stack:** Swift 5, SwiftUI, supabase-swift 2.x (SPM), Supabase (Auth/PostgREST/Storage).

## Global Constraints

- iOS 17+, SwiftUI. Couleurs uniquement via le Design System (déjà en place).
- **Prérequis bloquant :** le package `supabase-swift` (2.x, produit `Supabase`) doit être
  ajouté à la cible dans Xcode avant toute task code. Vérif : `Package.resolved` présent +
  `xcodebuild -resolvePackageDependencies` OK.
- Accès Supabase : `Config.supabaseURL` + `Config.supabaseAnonKey` (déjà lu depuis
  `Secrets.xcconfig` via Info.plist).
- Sécurité par RLS Postgres (la clé anon est publique). Ne jamais committer de clé service.
- À la fin du Plan 2, le dossier `ScoutInventory/` doit être **vide** (tout porté sous
  `ScoutManager/`).
- Statuts/états/branches = charte ScoutManager (rawValues alignés sur le SQL) :
  - ItemStatus : `disponible, reserve, sorti, a_verifier, a_reparer, indisponible, perdu, archive`
  - ItemCondition : `neuf, bon, moyen, mauvais`
  - TrackingType : `global, specifique`
  - Branch : `LJ, SG, PC, Groupe`

---

## File Structure

Créés :
```
ScoutManager/
  App/Config.swift                 (déplacé depuis ScoutInventory/Config.swift)
  Services/
    SupabaseService.swift          singleton : SupabaseClient + helpers auth
    ItemService.swift              CRUD inventory_items + categories/locations
    ImageStorageService.swift      upload/download bucket item-images
    QRCodeService.swift            qr_tags : lookup, assign, generate (CoreImage)
  Stores/
    SessionStore.swift             @MainActor ObservableObject : session, rôle (remplace AppState)
  Models/
    Item.swift  ItemCategory.swift  ItemLocation.swift  QRCode.swift
    MovementHistory.swift  Enums.swift  (ItemStatus, ItemCondition, TrackingType, Branch, UserRole)
  Views/Auth/LoginView.swift       login SDK (remplace l'ancien)
supabase/migrations/20260629_scoutmanager_mvp1.sql   (déjà écrit)
```

Supprimés (retrait legacy) :
```
ScoutInventory/Services/AppState.swift
ScoutInventory/Services/SupabaseService.swift
ScoutInventory/Views/LoginView.swift
ScoutInventory/Models/Domain.swift
ScoutInventory/Config.swift            (déplacé → ScoutManager/App/Config.swift)
```

Modifiés : `ScoutManager/App/RootView.swift`, `ScoutManager/App/ScoutManagerApp.swift`
(passer de `AppState` à `SessionStore`), `ScoutManager/DesignSystem/StatusColorMapper.swift`
+ `Components/SGDFBadge.swift` (renommer `SGDFItemStatus` → `ItemStatus`).

> Note plateforme : pas de cible XCTest tant que l'utilisateur ne l'a pas créée. Chaque
> task est vérifiée par `xcodebuild build` (+ run manuel pour l'auth). Les valeurs pures
> (mapping statut) restent testables si la cible apparaît.

---

## Task A : `SupabaseService` (client SDK) + déplacement de `Config`

**Prérequis :** package `supabase-swift` ajouté.

**Files:**
- Create: `ScoutManager/Services/SupabaseService.swift`
- Move: `ScoutInventory/Config.swift` → `ScoutManager/App/Config.swift` (contenu inchangé)

**Interfaces — Produces:**
- `final class SupabaseService` avec `static let shared: SupabaseService`,
  `let client: SupabaseClient` (init avec `Config.supabaseURL`, `Config.supabaseAnonKey`),
  `func signIn(email:String, password:String) async throws`,
  `func signOut() async throws`,
  `var currentUserID: UUID? { get }` (depuis `client.auth.currentUser`),
  `func currentUserRole() async throws -> UserRole?` (lit `profiles.role`).

- [ ] Step 1 : déplacer `Config.swift` (git mv) sous `ScoutManager/App/`. Build.
- [ ] Step 2 : créer `SupabaseService` (SDK). Esquisse :
```swift
import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()
    let client: SupabaseClient
    private init() {
        client = SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseAnonKey)
    }
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }
    func signOut() async throws { try await client.auth.signOut() }
    var currentUserID: UUID? { client.auth.currentUser?.id }
}
```
- [ ] Step 3 : `currentUserRole()` via `client.from("profiles").select("role").eq("id", value: uid).single()`. (signature exacte finalisée au moment de l'exécution selon la version résolue du SDK.)
- [ ] Step 4 : `xcodebuild build` → SUCCEEDED. Commit.

---

## Task B : Port de l'authentification (SessionStore + LoginView SDK), retrait de l'AppState legacy

**Files:**
- Create: `ScoutManager/Stores/SessionStore.swift`, `ScoutManager/Views/Auth/LoginView.swift`
- Modify: `ScoutManager/App/RootView.swift`, `ScoutManager/App/ScoutManagerApp.swift`
- Delete: `ScoutInventory/Services/AppState.swift`, `ScoutInventory/Views/LoginView.swift`,
  `ScoutInventory/Services/SupabaseService.swift`

**Interfaces — Produces:**
- `@MainActor final class SessionStore: ObservableObject` :
  `@Published var isAuthenticated: Bool`, `@Published var role: UserRole?`,
  `@Published var errorMessage: String?`, `var canWrite: Bool`,
  `func restore() async`, `func login(email:String, password:String) async`,
  `func logout() async`.
- `struct LoginView: View` (consomme `SessionStore` en `@EnvironmentObject`, design SGDF :
  `SGDFTextField`, `SGDFButton`).
- `RootView` et `ScoutManagerApp` utilisent `SessionStore` au lieu de `AppState`.

- [ ] Step 1 : `SessionStore` s'appuyant sur `SupabaseService.shared` (login/logout/role,
  `restore()` lit la session persistée du SDK au lancement).
- [ ] Step 2 : nouvelle `LoginView` SGDF (email + mot de passe → `store.login`).
- [ ] Step 3 : `RootView`/`ScoutManagerApp` : remplacer `@StateObject AppState` par
  `SessionStore`, `.task { await store.restore() }`.
- [ ] Step 4 : `git rm` legacy AppState + ancienne LoginView + ancien SupabaseService.
- [ ] Step 5 : build + run manuel (login réel sur la base). Commit.

---

## Task C : Modèles ScoutManager + retrait de `Domain.swift` + rename `ItemStatus`

**Files:**
- Create: `ScoutManager/Models/Enums.swift`, `Item.swift`, `ItemCategory.swift`,
  `ItemLocation.swift`, `QRCode.swift`, `MovementHistory.swift`
- Delete: `ScoutInventory/Models/Domain.swift`
- Modify: `ScoutManager/Models/ItemStatus.swift` (supprimé/fusionné dans Enums.swift),
  `StatusColorMapper.swift`, `Components/SGDFBadge.swift` (`SGDFItemStatus` → `ItemStatus`)

**Interfaces — Produces (mapping snake_case ↔ colonnes) :**
- `enum ItemStatus` (rename de `SGDFItemStatus`), `enum ItemCondition`, `enum TrackingType`,
  `enum Branch`, `enum UserRole` (admin/manager/member/viewer, `var canWrite`).
- `struct Item: Codable, Identifiable, Hashable` mappé sur `inventory_items` :
  id, inventory_code, name, description, category_id, location_id, tracking_type,
  quantity (total), quantity_available, status, condition, branch, event_id, image_path,
  notes, last_checked_at.
- `struct ItemCategory` (categories), `struct ItemLocation` (locations),
  `struct QRCode` mappé sur `qr_tags` (id, tag_code, status, assigned_item_id),
  `struct MovementHistory` mappé sur `item_movements`.

- [ ] Step 1 : `Enums.swift` (déplacer ItemStatus ici, renommé ; ajouter les autres enums).
- [ ] Step 2 : remplacer `SGDFItemStatus` → `ItemStatus` dans StatusColorMapper + SGDFBadge.
- [ ] Step 3 : créer les structs modèles avec `CodingKeys`.
- [ ] Step 4 : `git rm ScoutInventory/Models/Domain.swift` (plus aucune référence après Task B).
- [ ] Step 5 : build → SUCCEEDED (ScoutInventory/ doit être vide ; supprimer le groupe
  synchronisé `ScoutInventory` du projet est hors-scope code — le signaler pour un nettoyage
  pbxproj contrôleur). Commit.

---

## Task D : Migrations SQL (schéma) — exécution utilisateur

**Files:** `supabase/migrations/20260629_scoutmanager_mvp1.sql` (déjà écrit).

- [ ] Step 1 : l'utilisateur **relit** le SQL (sections 3/4 modifient des données ; RLS à
  aligner sur ses politiques).
- [ ] Step 2 : l'utilisateur l'exécute dans le SQL editor Supabase.
- [ ] Step 3 : vérif rapide : `categories`/`locations` créées, colonnes ajoutées à
  `inventory_items`, valeurs status/condition converties, bucket `item-images` présent.

> Cette task est un prérequis données pour Task E (les services lisent/écrivent ces colonnes),
> mais n'est pas bloquante pour A/B/C (auth + modèles).

---

## Task E : Services data (Item / Image / QRCode)

**Prérequis :** Task D exécutée.

**Files:**
- Create: `ScoutManager/Services/ItemService.swift`, `ImageStorageService.swift`,
  `QRCodeService.swift`

**Interfaces — Produces:**
- `struct ItemService` : `list(filter:) async throws -> [Item]`,
  `get(id:) async throws -> Item?`, `create(_:) async throws -> Item`,
  `update(_:) async throws`, `archive(id:) async throws`,
  `listCategories()/listLocations() async throws`, via `client.from(...)`.
- `struct ImageStorageService` : `upload(data:Data, path:String) async throws -> String`
  (retourne image_path), `publicURL(for path:String) -> URL` (bucket item-images).
- `struct QRCodeService` : `tag(byCode:) async throws -> QRCode?`,
  `assign(tagCode:toItem:) async throws`, `generateImage(for code:String) -> UIImage?`
  (CoreImage CIQRCodeGenerator).

- [ ] Step 1 : `ItemService` (list/get/create/update/archive + categories/locations).
- [ ] Step 2 : `ImageStorageService` (Storage upload + publicURL).
- [ ] Step 3 : `QRCodeService` (lookup/assign + génération CoreImage).
- [ ] Step 4 : build → SUCCEEDED. Commit. (Aucune vue ne consomme encore ces services — ils
  seront branchés dans Plan 3 Dashboard / Plan 4 Matériel.)

---

## Self‑Review (couverture)

- SDK client + auth port → A, B. ✅
- Retrait complet du legacy `ScoutInventory/` → A (Config), B (auth), C (Domain). ✅
- Résolution dette `SGDFItemStatus` → `ItemStatus` → C. ✅
- Schéma (extension) + bucket images → D (SQL fourni). ✅
- Services data matériel/image/QR → E. ✅
- Hors périmètre (plans suivants) : Dashboard (Plan 3), Matériel UI (Plan 4), Scan UI (Plan 5).

> Le code SDK exact (signatures `client.from(...).select(...).execute()`, décodage) est
> finalisé dans les briefs au moment de l'exécution, contre la version 2.x réellement
> résolue, pour éviter toute dérive d'API.
