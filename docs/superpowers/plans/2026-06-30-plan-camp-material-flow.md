# Plan — Flux matériel partagé camp ↔ inventaire (Projet 2)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (ou
> executing-plans). Pas de XCTest : chaque task = livrable **build‑vérifié** + revue.
> **Note projet :** un nouveau fichier sous `ScoutKit/Sources/ScoutKit/` est auto‑inclus (package
> dossier). Un nouveau fichier sous `ScoutCamp/` doit être ajouté au target ScoutCamp (groupes
> classiques) — le contrôleur l'ajoute via la gem `xcodeproj` (snippet en Task 3).

**Goal :** suivre le matériel emporté pour un camp depuis ScoutCamp (liste de chargement), avec
bascule de disponibilité (`sorti`/`disponible`) + mouvements côté inventaire, visible dans ScoutMatériel.

**Architecture :** table additive `camp_materials` + 2 RPC transactionnelles ; `CampMaterialService`
dans ScoutKit ; 3ᵉ onglet « Matériel » dans ScoutCamp ; « Sorti pour camp » dans la fiche ScoutMatériel.

**Spec :** `docs/superpowers/specs/2026-06-30-camp-material-flow-design.md`.

## Global Constraints
- iOS 17+, SwiftUI, MVVM strict : `Views → ViewModels/Stores → Services → SupabaseService.shared.client`.
- Code partagé dans **ScoutKit**, exposé `public` (types/membres/`public init`).
- **Backend partagé / additif uniquement** : `camp_materials` NOUVELLE ; réutilise `inventory_items`/`item_movements`/`program_slot_materials`/`camps` sans les muter. RPC `security invoker`.
- Statut réutilisé : `checked_out` (= `ItemStatus.sorti`) / `available` (= `.disponible`). Mouvements `checkout`/`return`.
- Écriture gardée par `SessionStore.canWrite` côté app + RLS côté serveur. Erreurs RPC remontées (pas de `try?` silencieux).
- Item entier (pas de quantité partielle). Couleurs via Design System (`SGDFBadge`/`StatusColorMapper`).
- Vérif : `xcodebuild build` des schemes **ScoutInventory** (ScoutMatériel) et **ScoutCamp** selon la task.

## Réutilisations clés (existant)
- `ItemService.list(search:status:categoryId:locationId:includeArchived:) -> [Item]` ; `Item` a `id, name, inventoryCode, status: ItemStatus`. Picker dispo = `list(status: .disponible)`.
- `SGDFBadge(status:)`, `StatusColorMapper`. `CampStore.selectedCamp`. `SessionStore.canWrite`.
- `SupabaseService.shared.client.rpc("fn", params: [...]).execute()` (cf. `ShoppingService.regenerateAuto`).
- `camps.event_id` (nullable). `item_movements(item_id, action, user_id, event_id)`.
- `MaterialDetailView` (ScoutMateriel/Views/Material/), `ProgramSlotFormView`/`SlotMaterialPickerView` (ScoutCamp/Views/Program/), `CampTabView` (ScoutCamp/App/).

---

## Task 1 — SQL : table `camp_materials` + RPC assign/return (additif)
**Fichier à créer** `supabase/migrations/20260630_scoutmanager_camp_materials.sql` :

```sql
-- ScoutManager — Projet 2 : flux matériel partagé camp <-> inventaire (ADDITIF)
create table if not exists public.camp_materials (
  camp_id            uuid not null references public.camps(id) on delete cascade,
  inventory_item_id  uuid not null references public.inventory_items(id) on delete cascade,
  added_by           uuid,
  added_at           timestamptz not null default now(),
  primary key (camp_id, inventory_item_id)
);

alter table public.camp_materials enable row level security;
drop policy if exists camp_materials_select_auth on public.camp_materials;
create policy camp_materials_select_auth on public.camp_materials for select to authenticated using (true);
drop policy if exists camp_materials_write_roles on public.camp_materials;
create policy camp_materials_write_roles on public.camp_materials for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

create or replace function public.assign_material_to_camp(p_camp_id uuid, p_item_id uuid)
returns void language plpgsql security invoker as $$
begin
  insert into public.camp_materials (camp_id, inventory_item_id, added_by)
    values (p_camp_id, p_item_id, auth.uid())
    on conflict (camp_id, inventory_item_id) do nothing;
  update public.inventory_items set status = 'checked_out' where id = p_item_id;
  insert into public.item_movements (item_id, action, user_id, event_id)
    values (p_item_id, 'checkout', auth.uid(), (select event_id from public.camps where id = p_camp_id));
end; $$;
grant execute on function public.assign_material_to_camp(uuid, uuid) to authenticated;

create or replace function public.return_material_from_camp(p_camp_id uuid, p_item_id uuid)
returns void language plpgsql security invoker as $$
begin
  delete from public.camp_materials where camp_id = p_camp_id and inventory_item_id = p_item_id;
  update public.inventory_items set status = 'available' where id = p_item_id;
  insert into public.item_movements (item_id, action, user_id, event_id)
    values (p_item_id, 'return', auth.uid(), (select event_id from public.camps where id = p_camp_id));
end; $$;
grant execute on function public.return_material_from_camp(uuid, uuid) to authenticated;
```
*Livrable :* fichier SQL additif (exécuté par l'utilisateur dans Supabase). Pas de build. Commit `feat(camp-mat): SQL camp_materials + assign/return RPC`.

---

## Task 2 — [ScoutKit] modèle `CampMaterial` + `CampMaterialService`
**Fichiers à créer** (auto‑inclus, package dossier) :
- `ScoutKit/Sources/ScoutKit/Models/CampMaterial.swift`
  ```swift
  import Foundation

  /// Ligne de chargement matériel d'un camp (table `camp_materials`).
  public struct CampMaterial: Codable, Identifiable, Hashable {
      public let campId: String
      public let inventoryItemId: String
      public var addedAt: String?
      public var id: String { inventoryItemId }   // unique par camp
      public init(campId: String, inventoryItemId: String, addedAt: String? = nil) {
          self.campId = campId; self.inventoryItemId = inventoryItemId; self.addedAt = addedAt
      }
      enum CodingKeys: String, CodingKey {
          case campId = "camp_id"
          case inventoryItemId = "inventory_item_id"
          case addedAt = "added_at"
      }
  }
  ```
- `ScoutKit/Sources/ScoutKit/Services/CampMaterialService.swift`
  ```swift
  import Foundation
  import Supabase

  /// Liste de chargement matériel d'un camp + assignation/retour atomiques (RPC).
  public struct CampMaterialService {
      public init() {}
      private var client: SupabaseClient { SupabaseService.shared.client }

      /// Items du chargement d'un camp (jointure camp_materials -> inventory_items).
      public func items(campId: String) async throws -> [Item] {
          struct Row: Decodable { let inventory_items: Item }
          let rows: [Row] = try await client.from("camp_materials")
              .select("inventory_items(*)").eq("camp_id", value: campId).execute().value
          return rows.map(\.inventory_items)
      }

      public func assign(campId: String, itemId: String) async throws {
          try await client.rpc("assign_material_to_camp",
                               params: ["p_camp_id": campId, "p_item_id": itemId]).execute()
      }
      public func remove(campId: String, itemId: String) async throws {
          try await client.rpc("return_material_from_camp",
                               params: ["p_camp_id": campId, "p_item_id": itemId]).execute()
      }
      public func returnAll(campId: String) async throws {
          for it in try await items(campId: campId) { try await remove(campId: campId, itemId: it.id) }
      }

      /// Nom du camp détenant l'item (pour ScoutMatériel), nil si non emporté.
      public func campLabel(forItemId itemId: String) async throws -> String? {
          struct CampName: Decodable { let name: String }
          struct Row: Decodable { let camps: CampName? }
          let rows: [Row] = try await client.from("camp_materials")
              .select("camps(name)").eq("inventory_item_id", value: itemId).limit(1).execute().value
          return rows.first?.camps?.name
      }
  }
  ```
*Livrable :* build d'un scheme (compile ScoutKit). `xcodebuild -scheme ScoutCamp … build` → `** BUILD SUCCEEDED **`. Commit `feat(camp-mat): CampMaterial model + service in ScoutKit`.

---

## Task 3 — [ScoutCamp] 3ᵉ onglet « Matériel » (chargement)
**Fichiers à créer** dans `ScoutCamp/Views/Material/` :
- `CampMaterialViewModel.swift` (`ViewModels/`) : `@MainActor`, `items: [Item]`, `available: [Item]`, `isLoading`, `errorMessage` ; `load(campId:)` (CampMaterialService.items) ; `loadAvailable()` (`ItemService().list(status: .disponible)`) ; `add(campId:itemIds:)` (boucle `assign`, puis recharge) ; `remove(campId:item:)` (`remove`, retire en mémoire) ; `returnAll(campId:)`. Erreurs remontées.
- `CampMaterialView.swift` : `@EnvironmentObject campStore`, `@EnvironmentObject session`, `@StateObject vm`. Si `selectedCamp == nil` → `EmptyStateView(systemImage:"shippingbox", …)`. Sinon `List` du chargement (nom + `SGDFBadge(status:)`), `.onDelete` (si `canWrite`) → `remove`. Toolbar « + » (si `canWrite`) → sheet picker des `available` (multi‑sélection) → `add`. Toolbar « Tout rendre » (si `canWrite`, `confirmationDialog`) → `returnAll`. État vide = message. `.task`/`.onChange(of: campStore.selectedCampID)`.
- Picker d'ajout : sous-vue (sheet) listant `vm.available` avec coches (`Set<String>`), valider = `add`.

**Modifier** `ScoutCamp/App/CampTabView.swift` : ajouter un 3ᵉ onglet
`CampMaterialView().tabItem { Label("Matériel", systemImage: "shippingbox") }`.

**[CONTRÔLEUR/GEM] ajouter les nouveaux fichiers au target ScoutCamp** (groupes classiques) :
```ruby
require 'xcodeproj'
p = Xcodeproj::Project.open('ScoutInventory.xcodeproj')
t = p.targets.find { |x| x.name == 'ScoutCamp' }
g = p.main_group['ScoutCamp']
['Views/Material/CampMaterialView.swift','ViewModels/CampMaterialViewModel.swift'].each do |rel|
  ref = g.new_reference(rel)
  t.source_build_phase.add_file_reference(ref)
end
p.save
```
*Livrable :* `xcodebuild -scheme ScoutCamp … build` vert ; l'onglet Matériel liste/ajoute/rend. Commit `feat(camp-mat): ScoutCamp loadout tab (list/add/return/return-all)`.

---

## Task 4 — [ScoutCamp] cohérence activité → chargement
**Modifier** `ScoutCamp/Views/Program/ProgramSlotFormView.swift` : lors de l'enregistrement des
liens matériel d'un créneau (après `ProgramService.setItems`), appeler aussi
`CampMaterialService().assign(campId:itemId:)` pour chaque item sélectionné (idempotent) afin de
l'ajouter au chargement et le passer `sorti`. Non‑bloquant comme le lien recettes : une erreur
d'assign s'affiche mais ne bloque pas l'enregistrement du créneau. Retirer un item d'une activité
**ne** déclenche **pas** de retour.
*Livrable :* build ScoutCamp vert ; rattacher un item à une activité l'ajoute au chargement. Commit `feat(camp-mat): activity link auto-feeds camp loadout`.

---

## Task 5 — [ScoutMatériel] « Sorti pour : ‹camp› » dans la fiche
**Modifier** `ScoutMateriel/Views/Material/MaterialDetailView.swift` : ajouter un `@State campLabel: String?`
et un `.task` qui appelle `CampMaterialService().campLabel(forItemId: item.id)`. Si non nil, afficher
une ligne lecture seule « Sorti pour : ‹campLabel› » sous le badge de statut (style existant, couleur
`SGDFColors.textSecondary`). Aucune autre modification.
*Livrable :* `xcodebuild -scheme ScoutInventory … build` vert ; un item sorti pour un camp affiche le camp. Commit `feat(camp-mat): show 'Sorti pour camp' in material detail`.

---

## Notes
- Chaque task touchant une app finit par un build vert du/des scheme(s) concerné(s).
- L'utilisateur exécute le SQL de la Task 1 dans Supabase avant de tester le runtime (le build n'en dépend pas).
- Le picker d'ajout ne propose que les items `disponible` → anti‑double‑réservation. Le `SlotMaterialPickerView` (Task 4) peut, lui, lister tout l'inventaire (l'assign idempotent gère les doublons), mais l'item sera passé `sorti`.
