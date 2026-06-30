# Plan — Bon de sortie (panier) pour ScoutMatériel

> **Sub-skill :** superpowers:subagent-driven-development. Pas de XCTest : chaque task = livrable
> **build‑vérifié** + revue. Les NOUVEAUX fichiers ScoutMatériel (groupes classiques) sont enregistrés
> dans le target `ScoutInventory` par le **contrôleur** via la gem `xcodeproj` (snippet en Task 3) ;
> les fichiers **ScoutKit** sont auto‑inclus (package dossier).

**Goal :** dans ScoutMatériel, préparer une sortie comme un panier (items + quantités) → un bon de
sortie traçable, avec retours partiels et jauge de disponibilité tenue à jour.

**Architecture :** tables additives `checkouts`/`checkout_items` + RPC transactionnelles ; `CheckoutService`
(ScoutKit) ; 4ᵉ onglet « Sorties » (liste → panier → fiche bon avec retours).

**Spec :** `docs/superpowers/specs/2026-06-30-checkout-cart-design.md`.

## Global Constraints
- iOS 17+, MVVM strict : `Views → ViewModels/Stores → Services → SupabaseService.shared.client`.
- Code partagé dans **ScoutKit**, `public` (+ `public init`). Couleurs via Design System (`SGDFBadge`/`SGDFColors`/`SGDFButton`).
- **Backend partagé / additif uniquement** : `checkouts`/`checkout_items` NOUVELLES ; réutilise `inventory_items.quantity_available`/`status`, `item_movements`. RPC `security invoker`.
- Statut/mouvement réutilisés : `checked_out`/`available` (ItemStatus.sorti/.disponible), `checkout`/`return` (MovementAction).
- Écriture gardée `SessionStore.canWrite` + RLS. Erreurs RPC remontées (pas de `try?` silencieux sur écritures).
- Liste supprimable = `List`+`.onDelete`+`.deleteDisabled(!canWrite)`. Vérif : `xcodebuild build` scheme `ScoutInventory`.

## Réutilisations
- `Item` (ScoutKit) : `id, name, status, quantity: Int, quantityAvailable: Int?, trackingType`. `ItemService().list()` → tous non‑archivés. `SGDFBadge(status:)`. `SessionStore.canWrite`. `SupabaseService.shared.client.rpc(...)`.
- Picker « disponibles » = items où `(quantityAvailable ?? quantity) > 0`.

---

## Task 1 — SQL : tables checkouts/checkout_items + RPC
**Fichier à créer** `supabase/migrations/20260630_scoutmanager_checkouts.sql` :

```sql
-- ScoutMatériel — bon de sortie (panier) — ADDITIF
create table if not exists public.checkouts (
  id          uuid primary key default gen_random_uuid(),
  label       text not null,
  notes       text,
  status      text not null default 'open',
  created_by  uuid,
  created_at  timestamptz not null default now(),
  returned_at timestamptz
);
alter table public.checkouts drop constraint if exists checkouts_status_chk;
alter table public.checkouts add constraint checkouts_status_chk
  check (status in ('open','returned')) not valid;

create table if not exists public.checkout_items (
  id                uuid primary key default gen_random_uuid(),
  checkout_id       uuid not null references public.checkouts(id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items(id) on delete cascade,
  quantity          integer not null,
  quantity_returned integer not null default 0
);

alter table public.checkouts      enable row level security;
alter table public.checkout_items enable row level security;

do $$ declare t text;
begin
  foreach t in array array['checkouts','checkout_items'] loop
    execute format('drop policy if exists %I_select_auth on public.%I', t, t);
    execute format('create policy %I_select_auth on public.%I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_write_roles on public.%I', t, t);
    execute format($f$create policy %I_write_roles on public.%I for all to authenticated
      using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
      with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))$f$, t, t);
  end loop;
end $$;

-- Création d'un bon : insère bon + lignes, décrémente dispo, pose statut, journalise. Anti-survente.
create or replace function public.create_checkout(p_label text, p_notes text, p_items jsonb)
returns uuid language plpgsql security invoker as $$
declare
  v_checkout_id uuid; v_item jsonb; v_item_id uuid; v_qty integer; v_avail integer;
begin
  insert into public.checkouts (label, notes, status, created_by)
    values (p_label, p_notes, 'open', auth.uid()) returning id into v_checkout_id;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_item->>'item_id')::uuid;
    v_qty := (v_item->>'quantity')::integer;
    if v_qty is null or v_qty <= 0 then raise exception 'Quantité invalide'; end if;
    select coalesce(quantity_available, quantity) into v_avail
      from public.inventory_items where id = v_item_id for update;
    if v_avail is null then raise exception 'Item introuvable'; end if;
    if v_avail < v_qty then raise exception 'Stock insuffisant (dispo %, demandé %)', v_avail, v_qty; end if;
    insert into public.checkout_items (checkout_id, inventory_item_id, quantity)
      values (v_checkout_id, v_item_id, v_qty);
    update public.inventory_items
       set quantity_available = v_avail - v_qty,
           status = case when (v_avail - v_qty) <= 0 then 'checked_out' else 'available' end
     where id = v_item_id;
    insert into public.item_movements (item_id, action, user_id, event_id)
      values (v_item_id, 'checkout', auth.uid(), null);
  end loop;
  return v_checkout_id;
end; $$;
grant execute on function public.create_checkout(text, text, jsonb) to authenticated;

-- Retour partiel d'une ligne : crédite dispo, journalise, ferme le bon si tout rendu.
create or replace function public.return_checkout_line(p_checkout_item_id uuid, p_qty integer)
returns void language plpgsql security invoker as $$
declare
  v_cid uuid; v_item_id uuid; v_qty integer; v_returned integer; v_remaining integer; v_ret integer; v_total integer;
begin
  select checkout_id, inventory_item_id, quantity, quantity_returned
    into v_cid, v_item_id, v_qty, v_returned
    from public.checkout_items where id = p_checkout_item_id for update;
  if v_cid is null then raise exception 'Ligne introuvable'; end if;
  v_remaining := v_qty - v_returned;
  v_ret := least(greatest(p_qty, 0), v_remaining);
  if v_ret <= 0 then return; end if;
  update public.checkout_items set quantity_returned = v_returned + v_ret where id = p_checkout_item_id;
  select quantity into v_total from public.inventory_items where id = v_item_id for update;
  update public.inventory_items
     set quantity_available = least(coalesce(quantity_available,0) + v_ret, v_total), status = 'available'
   where id = v_item_id;
  insert into public.item_movements (item_id, action, user_id, event_id)
    values (v_item_id, 'return', auth.uid(), null);
  if not exists (select 1 from public.checkout_items where checkout_id = v_cid and quantity_returned < quantity) then
    update public.checkouts set status = 'returned', returned_at = now() where id = v_cid;
  end if;
end; $$;
grant execute on function public.return_checkout_line(uuid, integer) to authenticated;

-- Tout rendre : rend le restant de chaque ligne (réutilise la fonction ligne).
create or replace function public.return_checkout_all(p_checkout_id uuid)
returns void language plpgsql security invoker as $$
declare v_line record;
begin
  for v_line in select id, quantity, quantity_returned from public.checkout_items
                where checkout_id = p_checkout_id and quantity_returned < quantity loop
    perform public.return_checkout_line(v_line.id, v_line.quantity - v_line.quantity_returned);
  end loop;
end; $$;
grant execute on function public.return_checkout_all(uuid) to authenticated;
```
*Livrable :* fichier SQL additif (exécuté par l'utilisateur). Pas de build. Commit `feat(checkout): SQL checkouts + create/return RPC`.

---

## Task 2 — [ScoutKit] modèles + CheckoutService
**Fichiers à créer** (auto‑inclus) :

`ScoutKit/Sources/ScoutKit/Models/Checkout.swift`
```swift
import Foundation

public enum CheckoutStatus: String, Codable, Hashable {
    case open, returned
    public var label: String { self == .open ? "Ouvert" : "Rendu" }
}

public struct Checkout: Codable, Identifiable, Hashable {
    public let id: String
    public var label: String
    public var notes: String?
    public var status: CheckoutStatus
    public var createdAt: String?
    public var returnedAt: String?
    public init(id: String, label: String, notes: String? = nil, status: CheckoutStatus,
                createdAt: String? = nil, returnedAt: String? = nil) {
        self.id = id; self.label = label; self.notes = notes; self.status = status
        self.createdAt = createdAt; self.returnedAt = returnedAt
    }
    enum CodingKeys: String, CodingKey {
        case id, label, notes, status
        case createdAt = "created_at"
        case returnedAt = "returned_at"
    }
}

/// Ligne d'un bon + l'item joint (via inventory_items(*)).
public struct CheckoutLine: Codable, Identifiable, Hashable {
    public let id: String
    public var checkoutId: String
    public var inventoryItemId: String
    public var quantity: Int
    public var quantityReturned: Int
    public var item: Item
    public var remaining: Int { quantity - quantityReturned }
    public init(id: String, checkoutId: String, inventoryItemId: String,
                quantity: Int, quantityReturned: Int, item: Item) {
        self.id = id; self.checkoutId = checkoutId; self.inventoryItemId = inventoryItemId
        self.quantity = quantity; self.quantityReturned = quantityReturned; self.item = item
    }
    enum CodingKeys: String, CodingKey {
        case id
        case checkoutId = "checkout_id"
        case inventoryItemId = "inventory_item_id"
        case quantity
        case quantityReturned = "quantity_returned"
        case item = "inventory_items"
    }
}
```

`ScoutKit/Sources/ScoutKit/Services/CheckoutService.swift`
```swift
import Foundation
import Supabase

public struct CheckoutService {
    public init() {}
    private var client: SupabaseClient { SupabaseService.shared.client }

    public func list() async throws -> [Checkout] {
        try await client.from("checkouts").select().order("created_at", ascending: false).execute().value
    }

    public func lines(checkoutId: String) async throws -> [CheckoutLine] {
        try await client.from("checkout_items")
            .select("*, inventory_items(*)").eq("checkout_id", value: checkoutId)
            .execute().value
    }

    private struct CreateParams: Encodable {
        let p_label: String; let p_notes: String?; let p_items: [Line]
        struct Line: Encodable { let item_id: String; let quantity: Int }
    }
    @discardableResult
    public func create(label: String, notes: String?, items: [(itemId: String, qty: Int)]) async throws -> String {
        let params = CreateParams(p_label: label, p_notes: notes,
                                  p_items: items.map { .init(item_id: $0.itemId, quantity: $0.qty) })
        return try await client.rpc("create_checkout", params: params).execute().value
    }

    private struct ReturnLineParams: Encodable { let p_checkout_item_id: String; let p_qty: Int }
    public func returnLine(checkoutItemId: String, qty: Int) async throws {
        try await client.rpc("return_checkout_line",
                             params: ReturnLineParams(p_checkout_item_id: checkoutItemId, p_qty: qty)).execute()
    }
    public func returnAll(checkoutId: String) async throws {
        try await client.rpc("return_checkout_all", params: ["p_checkout_id": checkoutId]).execute()
    }
}
```
*Livrable :* `xcodebuild -scheme ScoutInventory … build` → `** BUILD SUCCEEDED **`. Commit `feat(checkout): Checkout models + CheckoutService in ScoutKit`.

---

## Task 3 — [ScoutMatériel] onglet « Sorties » : liste + panier (création)
**Fichiers à créer** dans `ScoutMateriel/` :
- `App` → modifier `AppRouter.swift` : `enum Tab { case dashboard, material, scan, sorties }`. Modifier `MainTabView.swift` : ajouter un 4ᵉ onglet `CheckoutListView().tabItem { Label("Sorties", systemImage: "arrow.up.bin") }.tag(AppRouter.Tab.sorties)`.
- `ViewModels/CheckoutListViewModel.swift` : `@MainActor`, `checkouts: [Checkout]`, `isLoading`, `errorMessage` ; `load()` (CheckoutService.list).
- `ViewModels/CheckoutCartViewModel.swift` : `available: [Item]` (chargé via `ItemService().list()` filtré `(quantityAvailable ?? quantity) > 0`) ; `label: String`, `notes: String` ; `cart: [(item: Item, qty: Int)]` ; `add(item:)`/`removeLine(at:)`/`setQty(itemId:qty:)` ; `maxQty(for: Item) -> Int` (= `quantityAvailable ?? quantity`) ; `canValidate` (label non vide && cart non vide) ; `validate() async throws -> Void` → `CheckoutService().create(label:notes:items: cart.map{($0.item.id,$0.qty)})`. Erreurs remontées.
- `Views/Checkout/CheckoutListView.swift` : `@EnvironmentObject session`, `@StateObject vm`. `NavigationStack`. `List` des bons → `NavigationLink` vers `CheckoutDetailView(checkout:)`. Chaque ligne : `label` + date + badge statut (texte « Ouvert »/« Rendu », couleur `SGDFColors.green`/`textSecondary`). Toolbar « + » (si `canWrite`) → présente `CheckoutCartView`. État vide → `EmptyStateView`. `.task { await vm.load() }`.
- `Views/Checkout/CheckoutCartView.swift` : `Form`/`NavigationStack`. Section destination (`TextField` label requis + notes). Section **Panier** : `ForEach(vm.cart)` lignes = nom + `Stepper` quantité (`1...vm.maxQty(for:)` ; figé à 1 si max==1) ; `.onDelete` retire la ligne. Bouton « Ajouter du matériel » → sheet picker de `vm.available` (recherche par nom, tap ajoute au panier s'il n'y est pas). Toolbar « Valider » (désactivé si `!vm.canValidate || isSaving`) → `Task { try await vm.validate(); onCreated(); dismiss() }`, erreur affichée (section rouge). `onCreated: () -> Void` pour recharger la liste.

**[CONTRÔLEUR/GEM] enregistrer les nouveaux fichiers dans le target ScoutInventory** :
```ruby
require 'xcodeproj'
p = Xcodeproj::Project.open('ScoutInventory.xcodeproj')
t = p.targets.find { |x| x.name == 'ScoutInventory' }
g = p.main_group['ScoutMateriel']
['Views/Checkout/CheckoutListView.swift','Views/Checkout/CheckoutCartView.swift',
 'ViewModels/CheckoutListViewModel.swift','ViewModels/CheckoutCartViewModel.swift'].each do |rel|
  ref = g.new_reference(rel); t.source_build_phase.add_file_reference(ref)
end
p.save
```
*Livrable :* `xcodebuild -scheme ScoutInventory … build` vert ; l'onglet Sorties liste et un panier crée un bon. Commit `feat(checkout): Sorties tab — list + cart creation`.

---

## Task 4 — [ScoutMatériel] fiche bon + retours partiels
**Fichiers à créer** dans `ScoutMateriel/` :
- `ViewModels/CheckoutDetailViewModel.swift` : `lines: [CheckoutLine]`, `isLoading`, `errorMessage` ; `load(checkoutId:)` (CheckoutService.lines) ; `returnLine(line:qty:)` (`CheckoutService().returnLine`, recharge) ; `returnAll(checkoutId:)` (recharge).
- `Views/Checkout/CheckoutDetailView.swift` : `let checkout: Checkout`, `@EnvironmentObject session`, `@StateObject vm`. Entête : `checkout.label` + date + badge statut. `List` des `vm.lines` : nom de l'item + `quantityReturned / quantity rendu` ; si `canWrite` && `line.remaining > 0`, une action « Rendre » (sous-vue avec `Stepper` 1...`line.remaining` + bouton) → `vm.returnLine(line:qty:)`. Toolbar « Tout rendre » (si `canWrite` && statut ouvert, `confirmationDialog`) → `vm.returnAll(checkoutId: checkout.id)`. `.task { await vm.load(checkoutId: checkout.id) }`. Erreurs affichées.

**[CONTRÔLEUR/GEM]** enregistrer `Views/Checkout/CheckoutDetailView.swift` + `ViewModels/CheckoutDetailViewModel.swift` dans le target ScoutInventory (même snippet).
*Livrable :* build vert ; ouvrir un bon, rendre partiellement une ligne et tout rendre, le bon se ferme. Commit `feat(checkout): checkout detail + partial returns`.

---

## Task 5 — [option] indicateur « sorti via bon » sur la fiche matériel
**Modifier** `ScoutMateriel/Views/Material/MaterialDetailView.swift` : `@State openCheckoutLabel: String?` + `.task` qui interroge un bon ouvert contenant l'item (via `CheckoutService` — ajouter `openCheckoutLabel(forItemId:) async throws -> String?` : `checkout_items` ⋈ `checkouts` où `status='open'`, limit 1, renvoie `checkouts.label`). Si non nil, ligne lecture seule « Dans la sortie : ‹label› » (caption, `SGDFColors.textSecondary`) sous le badge.
*Livrable :* build `ScoutInventory` vert. Commit `feat(checkout): show open-checkout label in material detail`.

> Chaque task touchant le code : build `ScoutInventory` vert + revue. SQL (Task 1) exécuté par l'utilisateur avant le test runtime.
