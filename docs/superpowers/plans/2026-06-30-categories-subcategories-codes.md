# Catégories / sous-catégories, codes auto-générés, vignettes liste — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dans le module Matériel : classer par catégorie/sous-catégorie (sections + filtres), unifier le code inventaire en tag auto-généré `<CODECAT>-NNNN`, et afficher la vignette du produit à gauche du titre dans la liste.

**Architecture:** Migration Supabase additive (colonne `categories.code`, table `subcategories`, colonne `inventory_items.subcategory_id`, fonction `next_inventory_code`). Couche ScoutKit étendue (modèles + `ItemService`). Côté app ScoutMatériel : scanner résout désormais sur `inventory_code`, formulaire génère le code automatiquement, liste groupée en sections avec vignette.

**Tech Stack:** SwiftUI, Swift Package (ScoutKit), supabase-swift (PostgREST + RPC), Supabase Postgres + RLS.

## Global Constraints

- **Backend partagé avec CampManager — migrations ADDITIVES uniquement.** Jamais modifier/renommer/supprimer une table, colonne, type d'enum ou valeur existante. La table `qr_tags` est conservée.
- **Pas de cible XCTest.** « Vérifier » = `xcodebuild build` des DEUX schémas (`ScoutInventory` et `ScoutCamp`) sans erreur, puis vérification manuelle dans l'app. Ne jamais prétendre que des tests passent.
- **Couleurs uniquement via le Design System.** Aucune vue n'écrit `Color.blue`, `.white`, un hex, ou `Color(red:…)`. Couleurs via `SGDFColors` / `StatusColorMapper` ; `Color(hex:)` confiné à `DesignSystem/`.
- **Symboles partagés `public`.** Tout symbole de ScoutKit utilisé par une app (struct, propriété, init) doit être `public`.
- **UI en français.** Toute copie d'interface en français.
- **Fichiers app classiques.** Un NOUVEAU fichier `.swift` sous `ScoutMateriel/` doit être ajouté à la cible `ScoutInventory` dans `project.pbxproj`. Les fichiers sous `ScoutKit/Sources/ScoutKit/` sont auto-inclus (dossier). **Ce plan ne crée aucun nouveau fichier app** (seulement un nouveau fichier ScoutKit) → pas d'édition de `project.pbxproj`.
- **Erreurs remontées à l'UI** sur les écritures utilisateur (pas de `try?` silencieux).
- **Commande de build** (simulateur générique) :
  ```bash
  xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
  xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
  ```

---

### Task 1: Migration SQL (codes catégorie, sous-catégories, fonction de numérotation)

**Files:**
- Create: `supabase/migrations/20260702_categories_subcategories_codes.sql`

**Interfaces:**
- Produces (côté DB, consommé par les tasks suivantes) :
  - colonne `public.categories.code text`
  - table `public.subcategories (id uuid, category_id uuid, name text, created_at timestamptz)`
  - colonne `public.inventory_items.subcategory_id uuid`
  - fonction `public.next_inventory_code(p_category_id uuid) returns text`

Cette task est purement SQL (exécutée par l'utilisateur dans le SQL editor Supabase). Pas de build Swift. Le « test » est une relecture + exécution manuelle.

- [ ] **Step 1: Écrire le fichier de migration**

Créer `supabase/migrations/20260702_categories_subcategories_codes.sql` avec ce contenu exact :

```sql
-- ScoutManager — Catégories : code de préfixe, sous-catégories, codes inventaire auto.
-- À EXÉCUTER dans le SQL editor Supabase, APRÈS RELECTURE.
-- ADDITIF UNIQUEMENT (backend partagé avec CampManager). Idempotent.
-- ============================================================================

-- 1. Code de catégorie (préfixe de tag), additif & nullable -------------------
alter table public.categories
  add column if not exists code text;

-- Unicité insensible à la casse sur les codes renseignés
create unique index if not exists categories_code_key
  on public.categories (upper(code)) where code is not null;

-- 2. Sous-catégories (niveau 2) ----------------------------------------------
create table if not exists public.subcategories (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now()
);

-- 3. Lien item -> sous-catégorie (nullable) ----------------------------------
alter table public.inventory_items
  add column if not exists subcategory_id uuid references public.subcategories(id) on delete set null;

-- 4. RLS sous-catégories : lecture authentifiée, écriture admin/manager/member
alter table public.subcategories enable row level security;

drop policy if exists subcategories_select_auth on public.subcategories;
create policy subcategories_select_auth on public.subcategories
  for select to authenticated using (true);

drop policy if exists subcategories_write_roles on public.subcategories;
create policy subcategories_write_roles on public.subcategories
  for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- 5. Génération atomique du prochain code inventaire pour une catégorie -------
create or replace function public.next_inventory_code(p_category_id uuid)
returns text
language plpgsql
as $$
declare
  v_code text;
  v_seq  int;
begin
  select upper(code) into v_code from public.categories where id = p_category_id;
  if v_code is null then
    raise exception 'Catégorie % sans code', p_category_id;
  end if;
  -- verrou par catégorie (durée transaction) pour éviter les collisions
  perform pg_advisory_xact_lock(hashtext(v_code));
  select coalesce(max(
           (regexp_replace(inventory_code, '^' || v_code || '-', ''))::int
         ), 0) + 1
    into v_seq
    from public.inventory_items
   where inventory_code ~ ('^' || v_code || '-[0-9]+$');
  return v_code || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

-- 6. Seed d'exemple (à adapter / remplacer par tes vraies catégories) ---------
-- Décommente et ajuste si tu veux des données de démo :
-- insert into public.categories (name, code) values ('Tentes', 'TEN')
--   on conflict do nothing;
-- insert into public.categories (name, code) values ('Cuisine', 'CUI')
--   on conflict do nothing;
```

- [ ] **Step 2: Relire le fichier**

Vérifier visuellement :
- Toutes les opérations sont `add column if not exists` / `create table if not exists` / `create or replace` / `drop policy if exists` → idempotent.
- Aucune opération ne touche une colonne ou un type existant.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260702_categories_subcategories_codes.sql
git commit -m "feat(db): category code, subcategories table, next_inventory_code fn"
```

- [ ] **Step 4: Note pour l'utilisateur**

Signaler à l'utilisateur qu'il doit exécuter cette migration dans le SQL editor Supabase, puis créer au moins une catégorie avec un `code` (ex. `update public.categories set code='TEN' where name='Tentes';`) avant de tester la création d'items.

---

### Task 2: Modèles ScoutKit (code catégorie, sous-catégorie, lien item)

**Files:**
- Modify: `ScoutKit/Sources/ScoutKit/Models/ItemCategory.swift`
- Create: `ScoutKit/Sources/ScoutKit/Models/Subcategory.swift`
- Modify: `ScoutKit/Sources/ScoutKit/Models/Item.swift`

**Interfaces:**
- Produces :
  - `ItemCategory.code: String?` (CodingKey `code`)
  - `struct Subcategory { let id: String; var categoryId: String; var name: String }` (CodingKeys `category_id`)
  - `Item.subcategoryId: String?` (CodingKey `subcategory_id`), nouveau paramètre `subcategoryId` dans `Item.init` (après `categoryId`, valeur défaut `nil`)

- [ ] **Step 1: Ajouter `code` à `ItemCategory`**

Remplacer le contenu de `ScoutKit/Sources/ScoutKit/Models/ItemCategory.swift` par :

```swift
import Foundation

/// Catégorie de matériel — table `categories`.
public struct ItemCategory: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    /// Code de préfixe de tag (ex. "TEN"). Saisi en base.
    public var code: String?

    public init(id: String, name: String, code: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
    }
}
```

> `ItemCategory` n'a pas de `CodingKeys` explicite ; `code` correspond déjà à la colonne `code`. Pas de clé custom nécessaire.

- [ ] **Step 2: Créer le modèle `Subcategory`**

Créer `ScoutKit/Sources/ScoutKit/Models/Subcategory.swift` :

```swift
import Foundation

/// Sous-catégorie de matériel — table `subcategories` (niveau 2, rattachée à une catégorie).
public struct Subcategory: Codable, Identifiable, Hashable {
    public let id: String
    public var categoryId: String
    public var name: String

    public init(id: String, categoryId: String, name: String) {
        self.id = id
        self.categoryId = categoryId
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
    }
}
```

- [ ] **Step 3: Ajouter `subcategoryId` à `Item`**

Dans `ScoutKit/Sources/ScoutKit/Models/Item.swift` :

(a) Ajouter la propriété stockée juste après `categoryId` :

```swift
    public var categoryId: String?
    public var subcategoryId: String?
    public var locationId: String?
```

(b) Ajouter le paramètre d'init juste après `categoryId:` dans la signature de `init` :

```swift
        categoryId: String? = nil,
        subcategoryId: String? = nil,
        locationId: String? = nil,
```

(c) Ajouter l'assignation dans le corps de l'init, après `self.categoryId = categoryId` :

```swift
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.locationId = locationId
```

(d) Ajouter la clé dans `CodingKeys`, après `case categoryId = "category_id"` :

```swift
        case categoryId = "category_id"
        case subcategoryId = "subcategory_id"
        case locationId = "location_id"
```

- [ ] **Step 4: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED** pour les deux. (Aucun appelant existant de `Item.init` ne casse : `subcategoryId` a une valeur par défaut. `ItemCategory.init` aussi.)

- [ ] **Step 5: Commit**

```bash
git add ScoutKit/Sources/ScoutKit/Models/
git commit -m "feat(model): category code, Subcategory model, item subcategory_id"
```

---

### Task 3: Services ScoutKit (sous-catégories, code auto, lookup par code, format)

**Files:**
- Modify: `ScoutKit/Sources/ScoutKit/Services/ItemService.swift`
- Modify: `ScoutKit/Sources/ScoutKit/Models/QRCode.swift`

**Interfaces:**
- Consumes : `Subcategory`, `Item.subcategoryId`, `ItemCategory.code` (Task 2).
- Produces (signatures exactes utilisées par les tasks 4–6) :
  - `ItemService.listSubcategories() async throws -> [Subcategory]`
  - `ItemService.nextInventoryCode(categoryId: String) async throws -> String`
  - `ItemService.item(byCode code: String) async throws -> Item?`
  - `ItemService.list(..., subcategoryId: String? = nil, ...)` — nouveau paramètre optionnel
  - `TagCode.parse` accepte désormais `^[A-Z]{2,4}-\d{4}$`

- [ ] **Step 1: Mettre à jour le format dans `TagCode.parse`**

Dans `ScoutKit/Sources/ScoutKit/Models/QRCode.swift`, remplacer le commentaire et le corps de `TagCode` :

```swift
/// Validation du format de code inventaire / tag : PRÉFIXE (2-4 lettres) + "-" + 4 chiffres.
/// Ex. "TEN-0001". Le préfixe est le code de la catégorie.
public enum TagCode {
    public static func parse(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.range(of: "^[A-Z]{2,4}-\\d{4}$", options: .regularExpression) != nil else { return nil }
        return trimmed
    }
}
```

- [ ] **Step 2: Ajouter `subcategoryId` au filtre `list(...)` de `ItemService`**

Dans `ScoutKit/Sources/ScoutKit/Services/ItemService.swift`, remplacer la signature et le corps de `list` :

```swift
    /// Liste filtrée. Exclut l'archivé par défaut.
    public func list(search: String? = nil,
              status: ItemStatus? = nil,
              categoryId: String? = nil,
              subcategoryId: String? = nil,
              locationId: String? = nil,
              includeArchived: Bool = false) async throws -> [Item] {
        var query = client.from("inventory_items").select()
        if !includeArchived { query = query.neq("status", value: ItemStatus.archive.rawValue) }
        if let status { query = query.eq("status", value: status.rawValue) }
        if let categoryId { query = query.eq("category_id", value: categoryId) }
        if let subcategoryId { query = query.eq("subcategory_id", value: subcategoryId) }
        if let locationId { query = query.eq("location_id", value: locationId) }
        if let search, !search.isEmpty { query = query.ilike("name", value: "%\(search)%") }
        return try await query.order("inventory_code").execute().value
    }
```

- [ ] **Step 3: Ajouter `item(byCode:)` (résolution scan sur inventory_code)**

Dans `ItemService.swift`, juste après la méthode `get(id:)`, ajouter :

```swift
    /// Recherche un matériel par son code inventaire (= code scanné). Insensible à la casse via match exact uppercase.
    public func item(byCode code: String) async throws -> Item? {
        let rows: [Item] = try await client.from("inventory_items")
            .select().eq("inventory_code", value: code).limit(1).execute().value
        return rows.first
    }
```

- [ ] **Step 4: Ajouter `listSubcategories()` et `nextInventoryCode(categoryId:)`**

Dans `ItemService.swift`, dans la section `// MARK: - Referentials`, après `listLocations()`, ajouter :

```swift
    public func listSubcategories() async throws -> [Subcategory] {
        try await client.from("subcategories").select().order("name").execute().value
    }

    /// Génère le prochain code inventaire pour une catégorie (RPC atomique). Ex. "TEN-0001".
    public func nextInventoryCode(categoryId: String) async throws -> String {
        try await client.rpc("next_inventory_code",
                             params: ["p_category_id": categoryId]).execute().value
    }
```

- [ ] **Step 5: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED**. (Les appelants existants de `list(...)` utilisent des arguments nommés et ne passent pas `subcategoryId` → inchangés.)

- [ ] **Step 6: Commit**

```bash
git add ScoutKit/Sources/ScoutKit/Services/ItemService.swift ScoutKit/Sources/ScoutKit/Models/QRCode.swift
git commit -m "feat(service): subcategories, next_inventory_code, item(byCode:), new tag format"
```

---

### Task 4: Scanner & inventaire résolvent sur `inventory_code`

**Files:**
- Modify: `ScoutMateriel/ViewModels/ScannerViewModel.swift`
- Modify: `ScoutMateriel/ViewModels/InventoryViewModel.swift`
- Modify: `ScoutMateriel/Views/Material/MaterialDetailView.swift`
- Modify: `ScoutMateriel/Views/Scan/QRScannerView.swift`
- Modify: `ScoutMateriel/Views/Inventory/InventoryView.swift`

**Interfaces:**
- Consumes : `ItemService.item(byCode:)`, `Item.inventoryCode`, `QRCodeService.generateImage(for:)`, `TagCode.parse` (Tasks 2–3).

> Le scan ne passe plus par `qr_tags`. Le code scanné EST le `inventory_code` de l'item.

- [ ] **Step 1: `ScannerViewModel.resolve` résout sur l'item**

Dans `ScoutMateriel/ViewModels/ScannerViewModel.swift`, remplacer le corps de `resolve(_:)` (garder l'enum `ScanResolution` tel quel) :

```swift
    func resolve(_ raw: String) async -> ScanResolution {
        guard let code = TagCode.parse(raw) else {
            return .invalid("Code invalide. Format attendu : TEN-0001.")
        }
        isResolving = true
        defer { isResolving = false }
        do {
            guard let item = try await itemService.item(byCode: code) else {
                return .unknown("Code inconnu. Aucun matériel ne porte ce code.")
            }
            return .item(item)
        } catch {
            return .invalid("Erreur de lecture. Réessaie.")
        }
    }
```

Puis supprimer la propriété devenue inutile `private let qrService = QRCodeService()` (la ligne `private let itemService = ItemService()` reste).

- [ ] **Step 2: `InventoryViewModel.resolve` résout sur l'item**

Dans `ScoutMateriel/ViewModels/InventoryViewModel.swift`, remplacer le corps de `resolve(_:)` :

```swift
    func resolve(_ raw: String) {
        manualCode = ""
        guard let code = TagCode.parse(raw) else {
            scanMessage = "Code invalide. Format attendu : TEN-0001."
            return
        }
        Task {
            do {
                guard let item = try await itemService.item(byCode: code) else {
                    scanMessage = "Code inconnu."
                    return
                }
                if let known = expected.first(where: { $0.id == item.id }) {
                    pointedIds.insert(known.id)
                    scanMessage = "✓ \(known.name)"
                } else {
                    if !extras.contains(where: { $0.id == item.id }) { extras.append(item) }
                    scanMessage = "En trop : \(item.name) (hors périmètre)"
                }
            } catch {
                scanMessage = "Erreur de lecture. Réessaie."
            }
        }
    }
```

Puis supprimer `private let qrService = QRCodeService()` (la ligne `itemService` reste).

> Vérifier en lisant le fichier : le bloc original (lignes ~58-85) se terminait après le `else if let item = try await itemService.get(id: itemId)` ; remplacer tout le `func resolve` jusqu'à sa accolade fermante par le bloc ci-dessus.

- [ ] **Step 3: `MaterialDetailView.showQRCode` génère depuis `inventory_code`**

Dans `ScoutMateriel/Views/Material/MaterialDetailView.swift`, remplacer la fonction `showQRCode()` :

```swift
    private func showQRCode() {
        qrCode = item.inventoryCode
    }
```

> Le `qrCode` (String) sert déjà à générer l'image via `QRCodeService().generateImage(for:)` dans la vue ; on lui passe maintenant directement le code inventaire. `qrError` reste déclaré (utilisé ailleurs ? si plus référencé après ce changement, le laisser ne casse pas le build — une `@State` non lue ne produit qu'un avertissement, pas une erreur).

- [ ] **Step 4: Mettre à jour les placeholders/textes « TAG-000001 »**

(a) `ScoutMateriel/Views/Scan/QRScannerView.swift` ligne 9 :
```swift
    @State private var message = "Scanne une étiquette ou saisis le code (ex. TEN-0001)."
```
ligne 32 :
```swift
                    SGDFTextField("TEN-0001", text: $manualCode, systemImage: "number")
```

(b) `ScoutMateriel/Views/Inventory/InventoryView.swift` ligne 82 :
```swift
                    SGDFTextField("TEN-0001", text: $viewModel.manualCode, systemImage: "qrcode")
```

- [ ] **Step 5: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED**.

> Note : `QRScannerView.swift` contient encore le flux « tag vierge » (`blankTagCode`, `AssignQRCodeView`). Il n'est plus atteignable via le scan d'items mais reste compilable — on ne le supprime pas (non destructif). Si `TagCode.parse` à la ligne 63 produit une erreur de type, la laisser : la signature est inchangée.

- [ ] **Step 6: Commit**

```bash
git add ScoutMateriel/
git commit -m "feat(scan): resolve scanned code on inventory_code; QR from item code"
```

---

### Task 5: Formulaire — catégorie obligatoire, sous-catégorie, code auto-généré

**Files:**
- Modify: `ScoutMateriel/ViewModels/MaterialFormViewModel.swift`
- Modify: `ScoutMateriel/Views/Material/MaterialFormView.swift`

**Interfaces:**
- Consumes : `ItemService.listSubcategories()`, `ItemService.nextInventoryCode(categoryId:)`, `Item.subcategoryId`, `Subcategory` (Tasks 2–3).
- Produces (consommé par la vue) : `MaterialFormViewModel.subcategories: [Subcategory]`, `subcategoryId: String?`, `filteredSubcategories: [Subcategory]`, `canSave` mis à jour (catégorie requise).

- [ ] **Step 1: Étendre `MaterialFormViewModel`**

Dans `ScoutMateriel/ViewModels/MaterialFormViewModel.swift` :

(a) Ajouter les propriétés publiées, après `@Published var categoryId: String?` :

```swift
    @Published var categoryId: String?
    @Published var subcategoryId: String?
    @Published var subcategories: [Subcategory] = []
```

(b) Dans `init(item:)`, dans la branche `if let item`, après `categoryId = item.categoryId`, ajouter :

```swift
            categoryId = item.categoryId
            subcategoryId = item.subcategoryId
```

(c) Remplacer `canSave` : la catégorie devient obligatoire ; le code n'est plus saisi à la main (donc plus exigé dans `canSave`) :

```swift
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        categoryId != nil && !isSaving
    }
```

(d) Ajouter une vue calculée pour les sous-catégories de la catégorie choisie, après `canSave` :

```swift
    /// Sous-catégories rattachées à la catégorie sélectionnée.
    var filteredSubcategories: [Subcategory] {
        guard let categoryId else { return [] }
        return subcategories.filter { $0.categoryId == categoryId }
    }
```

(e) Charger les sous-catégories dans `loadReferentials()` :

```swift
    func loadReferentials() async {
        let cats = try? await service.listCategories()
        let locs = try? await service.listLocations()
        let subs = try? await service.listSubcategories()
        categories = cats ?? []
        locations = locs ?? []
        subcategories = subs ?? []
        if cats == nil && locs == nil {
            errorMessage = "Impossible de charger catégories/localisations."
        }
    }
```

(f) Dans `save()`, générer le code en création et passer `subcategoryId`. Remplacer le bloc `do { ... }` :

```swift
        do {
            let id = editingItemId ?? UUID().uuidString
            guard let categoryId else {
                errorMessage = "Choisis une catégorie."
                return false
            }
            // En création, le code est généré automatiquement (PRÉFIXE-NNNN).
            // En édition, on conserve le code existant.
            let code: String
            if isEditing {
                code = inventoryCode
            } else {
                code = try await service.nextInventoryCode(categoryId: categoryId)
            }
            var imagePath = existingImagePath
            if let data = pickedImageData {
                imagePath = try await storage.upload(data, path: "items/\(id).jpg")
            }
            let item = Item(
                id: id,
                inventoryCode: code,
                name: name,
                description: itemDescription.isEmpty ? nil : itemDescription,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                locationId: locationId,
                trackingType: trackingType,
                quantity: quantity,
                quantityAvailable: isEditing ? min(existingQuantityAvailable ?? quantity, quantity) : quantity,
                status: status,
                condition: condition,
                branch: branch,
                eventId: nil,
                imagePath: imagePath,
                notes: notes.isEmpty ? nil : notes,
                lastCheckedAt: nil,
                minimumThreshold: trackingType == .global && minimumThreshold > 0 ? minimumThreshold : nil,
                unit: trackingType == .global ? unit : nil
            )
            if isEditing {
                try await service.update(item)
            } else {
                _ = try await service.create(item)
            }
            return true
        } catch {
            errorMessage = "Échec de l'enregistrement. Réessaie."
            return false
        }
```

- [ ] **Step 2: Mettre à jour le formulaire (`MaterialFormView`)**

Dans `ScoutMateriel/Views/Material/MaterialFormView.swift`, section « Identité » : le champ code devient conditionnel (lecture seule en édition, masqué en création). Remplacer la `Section("Identité")` :

```swift
                Section("Identité") {
                    TextField("Nom", text: $viewModel.name)
                    if viewModel.isEditing {
                        LabeledContent("Code inventaire", value: viewModel.inventoryCode)
                    }
                    TextField("Description", text: $viewModel.itemDescription, axis: .vertical)
                }
```

Puis dans la `Section("Classement")`, ajouter le picker sous-catégorie après le picker catégorie, et réinitialiser la sous-catégorie quand la catégorie change. Remplacer la `Section("Classement")` :

```swift
                Section("Classement") {
                    Picker("Catégorie", selection: $viewModel.categoryId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(viewModel.categories) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    if !viewModel.filteredSubcategories.isEmpty {
                        Picker("Sous-catégorie", selection: $viewModel.subcategoryId) {
                            Text("Aucune").tag(String?.none)
                            ForEach(viewModel.filteredSubcategories) { Text($0.name).tag(String?.some($0.id)) }
                        }
                    }
                    Picker("Localisation", selection: $viewModel.locationId) {
                        Text("Aucune").tag(String?.none)
                        ForEach(viewModel.locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    Picker("Branche", selection: $viewModel.branch) {
                        Text("Aucune").tag(Branch?.none)
                        ForEach(Branch.allCases, id: \.self) { Text($0.label).tag(Branch?.some($0)) }
                    }
                }
```

Ajouter un `.onChange` pour vider la sous-catégorie si la catégorie change, à côté des `.onChange` existants (après `.onChange(of: viewModel.trackingType)`) :

```swift
            .onChange(of: viewModel.categoryId) { _, _ in
                viewModel.subcategoryId = nil
            }
```

- [ ] **Step 3: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED**.

- [ ] **Step 4: Vérification manuelle**

Lancer ScoutMatériel. Prérequis : au moins une catégorie avec `code` en base (Task 1, Step 4). Créer un item sans choisir de catégorie → bouton « Enregistrer » désactivé. Choisir une catégorie (code `TEN`) → enregistrer → l'item apparaît avec le code `TEN-0001`. En recréer un → `TEN-0002`. Éditer un item → le code s'affiche en lecture seule et ne change pas.

- [ ] **Step 5: Commit**

```bash
git add ScoutMateriel/
git commit -m "feat(form): required category, subcategory picker, auto-generated code"
```

---

### Task 6: Liste — sections catégorie/sous-catégorie, filtre, vignette

**Files:**
- Modify: `ScoutMateriel/ViewModels/MaterialListViewModel.swift`
- Modify: `ScoutMateriel/Views/Material/MaterialListView.swift`
- Modify: `ScoutMateriel/Views/Material/MaterialFilterView.swift`

**Interfaces:**
- Consumes : `ItemService.listSubcategories()`, `ItemService.list(subcategoryId:)`, `Subcategory`, `Item.subcategoryId`, `Item.imagePath`, `ImageStorageService.publicURL(for:)` (Tasks 2–3 + existant).
- Produces (consommé par les vues) :
  - `MaterialListViewModel.subcategories: [Subcategory]`, `subcategoryFilter: String?`
  - `MaterialListViewModel.filteredSubcategories: [Subcategory]`
  - `MaterialListViewModel.groups: [MaterialCategoryGroup]` (type défini ci-dessous)

- [ ] **Step 1: Étendre `MaterialListViewModel` (sous-catégories, filtre, groupement)**

Dans `ScoutMateriel/ViewModels/MaterialListViewModel.swift` :

(a) Ajouter les types de groupement en haut du fichier, après les `import` :

```swift
struct MaterialSubcategoryGroup: Identifiable {
    let id: String        // id de sous-catégorie, ou "none"
    let name: String
    let items: [Item]
}

struct MaterialCategoryGroup: Identifiable {
    let id: String        // id de catégorie, ou "none"
    let name: String
    let subgroups: [MaterialSubcategoryGroup]
}
```

(b) Ajouter les propriétés publiées, après `@Published var categories` / `@Published var categoryFilter` :

```swift
    @Published var subcategories: [Subcategory] = []
    @Published var subcategoryFilter: String?
```

(c) Charger les sous-catégories dans `loadReferentials()` :

```swift
    func loadReferentials() async {
        categories = (try? await service.listCategories()) ?? []
        locations = (try? await service.listLocations()) ?? []
        subcategories = (try? await service.listSubcategories()) ?? []
    }
```

(d) Passer `subcategoryFilter` à `service.list(...)` dans `load()` :

```swift
            items = try await service.list(
                search: search.isEmpty ? nil : search,
                status: statusFilter,
                categoryId: categoryFilter,
                subcategoryId: subcategoryFilter,
                locationId: locationFilter
            )
```

(e) Inclure la sous-catégorie dans `activeFilterCount` et `clearFilters()` :

```swift
    var activeFilterCount: Int {
        [statusFilter != nil, categoryFilter != nil, subcategoryFilter != nil, locationFilter != nil].filter { $0 }.count
    }

    func clearFilters() {
        statusFilter = nil
        categoryFilter = nil
        subcategoryFilter = nil
        locationFilter = nil
    }
```

(f) Ajouter `filteredSubcategories` et `groups`, après `clearFilters()` :

```swift
    /// Sous-catégories de la catégorie filtrée (vide si aucune catégorie choisie).
    var filteredSubcategories: [Subcategory] {
        guard let categoryFilter else { return [] }
        return subcategories.filter { $0.categoryId == categoryFilter }
    }

    /// `items` (déjà filtrés côté serveur) regroupés par catégorie puis sous-catégorie.
    var groups: [MaterialCategoryGroup] {
        let catName: (String?) -> String = { id in
            guard let id else { return "Sans catégorie" }
            return self.categories.first { $0.id == id }?.name ?? "Sans catégorie"
        }
        let subName: (String?) -> String = { id in
            guard let id else { return "Sans sous-catégorie" }
            return self.subcategories.first { $0.id == id }?.name ?? "Sans sous-catégorie"
        }
        let byCategory = Dictionary(grouping: items) { $0.categoryId ?? "none" }
        return byCategory.keys.sorted { catName($0 == "none" ? nil : $0) < catName($1 == "none" ? nil : $1) }
            .map { catKey in
                let catItems = byCategory[catKey] ?? []
                let bySub = Dictionary(grouping: catItems) { $0.subcategoryId ?? "none" }
                let subgroups = bySub.keys
                    .sorted { subName($0 == "none" ? nil : $0) < subName($1 == "none" ? nil : $1) }
                    .map { subKey in
                        MaterialSubcategoryGroup(
                            id: subKey,
                            name: subName(subKey == "none" ? nil : subKey),
                            items: (bySub[subKey] ?? []).sorted { $0.inventoryCode < $1.inventoryCode }
                        )
                    }
                return MaterialCategoryGroup(
                    id: catKey,
                    name: catName(catKey == "none" ? nil : catKey),
                    subgroups: subgroups
                )
            }
    }
```

(g) `categoryName(_:)` et `locationName(_:)` restent inchangés.

- [ ] **Step 2: Réinitialiser le filtre sous-catégorie dans le `MaterialFilterView`**

Dans `ScoutMateriel/Views/Material/MaterialFilterView.swift`, remplacer la `Section("Catégorie")` par catégorie + sous-catégorie dépendante :

```swift
                Section("Catégorie") {
                    Picker("Catégorie", selection: $viewModel.categoryFilter) {
                        Text("Toutes").tag(String?.none)
                        ForEach(viewModel.categories) { cat in
                            Text(cat.name).tag(String?.some(cat.id))
                        }
                    }
                    .onChange(of: viewModel.categoryFilter) { _, _ in
                        viewModel.subcategoryFilter = nil
                    }
                    if !viewModel.filteredSubcategories.isEmpty {
                        Picker("Sous-catégorie", selection: $viewModel.subcategoryFilter) {
                            Text("Toutes").tag(String?.none)
                            ForEach(viewModel.filteredSubcategories) { sub in
                                Text(sub.name).tag(String?.some(sub.id))
                            }
                        }
                    }
                }
```

- [ ] **Step 3: Liste en sections repliables + vignette**

Dans `ScoutMateriel/Views/Material/MaterialListView.swift` :

(a) Remplacer la branche `else` du `content` (le `List { ForEach(viewModel.items) ... }`) par une liste groupée :

```swift
        } else {
            List {
                ForEach(viewModel.groups) { group in
                    Section {
                        ForEach(group.subgroups) { sub in
                            DisclosureGroup {
                                ForEach(sub.items) { item in
                                    NavigationLink(value: item) { MaterialRow(item: item) }
                                }
                            } label: {
                                Text(sub.name)
                                    .font(SGDFTheme.FontStyle.caption())
                                    .foregroundStyle(SGDFColors.textSecondary)
                            }
                        }
                    } header: {
                        Text(group.name)
                            .foregroundStyle(SGDFColors.primaryBlue)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
```

> `.insetGrouped` rend les en-têtes de section catégorie lisibles ; les sous-catégories sont des `DisclosureGroup` repliables.

(b) Remplacer `MaterialRow` pour ajouter la vignette à gauche du titre :

```swift
/// Ligne de liste : vignette + nom + code + badge statut (+ quantité).
private struct MaterialRow: View {
    let item: Item

    private var imageURL: URL? {
        guard let path = item.imagePath else { return nil }
        return try? ImageStorageService().publicURL(for: path)
    }

    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.md) {
            thumbnail
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
        }
        .padding(.vertical, SGDFTheme.Spacing.xs)
    }

    @ViewBuilder
    private var thumbnail: some View {
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
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
    }
}
```

- [ ] **Step 4: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED**.

- [ ] **Step 5: Vérification manuelle**

Lancer ScoutMatériel. La liste affiche des sections par catégorie, des sous-sections repliables par sous-catégorie, et chaque ligne montre la vignette (ou un placeholder `photo`) à gauche du nom. Ouvrir les filtres → choisir une catégorie → le picker sous-catégorie apparaît avec les sous-catégories de cette catégorie → appliquer → la liste se restreint.

- [ ] **Step 6: Commit**

```bash
git add ScoutMateriel/
git commit -m "feat(material-list): category/subcategory sections, filter, row thumbnail"
```

---

## Notes de vérification finale

- Build des **deux** schémas après chaque task.
- Migration SQL exécutée par l'utilisateur dans Supabase + au moins une catégorie avec `code`.
- Scénario bout-en-bout : créer 2 items dans une catégorie (`XXX-0001`, `XXX-0002`) → scanner/saisir un code → ouvre la fiche → liste groupée + vignette + filtres.

## Hors périmètre

- Écran de gestion des catégories/sous-catégories dans l'app (création/édition depuis l'UI).
- Rétro-compatibilité des codes `TAG-`.
- Renumérotation des items existants.
- Suppression du flux « tag vierge » (`AssignQRCodeView`, `QRCodeService.assign`) — conservé, simplement non utilisé.
