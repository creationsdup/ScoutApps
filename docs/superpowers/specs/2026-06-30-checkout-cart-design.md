# Bon de sortie (panier de matériel) — design

**Date :** 2026‑06‑30
**Périmètre :** dans **ScoutMatériel**, un workflow « panier de sortie » : sélectionner du
matériel, ajuster les quantités, valider → un **bon de sortie traçable** ; sorties et retours
(partiels) journalisés, jauge de disponibilité tenue à jour.
**App :** ScoutMatériel (les modèles/service partagés vivent dans **ScoutKit**).

---

## 1. Contexte et décisions

L'intendant prépare une sortie comme un panier de courses : il pioche des items, choisit des
quantités (ex. 12 gamelles sur 20), valide. Le bon est **consultable** et **rendable par morceaux**
(le matériel revient échelonné ; certaines unités se perdent). Décisions validées :
- **Bon de sortie = entité tracée** (`checkouts` + lignes `checkout_items`), pas un simple lot de mouvements.
- **Retour partiel par ligne, piloté quantité** : chaque ligne suit `quantity`/`quantity_returned` ; le bon se ferme quand tout est rendu.
- **Destination = texte libre** (`label`), ex. « Camp été – patrouille Loups », « Prêt à Jean ».
- **4ᵉ onglet « Sorties »** dans ScoutMatériel.
- **Atomicité via RPC Postgres** (`security invoker` → RLS), comme les flux courses / matériel‑camp.
- **Additif uniquement** (backend partagé) : nouvelles tables `checkouts`/`checkout_items` + RPC ; réutilise `inventory_items.quantity_available`/`status`, `item_movements`.
- Distinct du **chargement de camp** (Projet 2 : items entiers rattachés à un camp) — deux workflows coexistants, pas de fusion.

---

## 2. Modèle de données (additif)

**`checkouts`** (le bon)
| Colonne | Type | Notes |
|---------|------|-------|
| id | uuid pk | |
| label | text not null | destination/libellé libre |
| notes | text | |
| status | text not null default 'open' | `open` / `returned` (check) |
| created_by | uuid | `auth.uid()` |
| created_at | timestamptz default now() | |
| returned_at | timestamptz | posé quand tout est rendu |

**`checkout_items`** (lignes du panier)
| Colonne | Type | Notes |
|---------|------|-------|
| id | uuid pk | |
| checkout_id | uuid not null → checkouts(id) on delete cascade | |
| inventory_item_id | uuid not null → inventory_items(id) on delete cascade | |
| quantity | integer not null | quantité sortie |
| quantity_returned | integer not null default 0 | ≤ quantity |

RLS calquée sur les autres tables (select `authenticated`, write `admin/manager/member`).
Réutilisé : `inventory_items.quantity_available` (integer), `inventory_items.status`,
`item_movements` (`checkout`/`return`).

---

## 3. Règles quantité / statut (unifiées spécifique + global)

`quantity_available` (plancher 0, plafond `quantity`) est la source de vérité de « combien on peut prendre ».
- **Sortie** d'une quantité `q` sur un item : `quantity_available -= q` ;
  `status = (quantity_available ≤ 0) ? 'checked_out' : 'available'`.
- **Retour** d'une quantité `r` : `quantity_returned += r` (ligne) ; `quantity_available += r`
  (plafonné à `quantity`) ; `status = 'available'` (il reste des unités après un retour).
- **Spécifique** (individuel, quantity=1) : `q=1`, dispo 1→0 = sorti, retour = dispo.
- **Global** (ex. 20 gamelles) : `q` choisi ; tant qu'il reste des unités le statut reste `available` (jauge X/Y juste).
Chaque opération journalise un mouvement (`checkout`/`return`) dans `item_movements`.

---

## 4. RPC transactionnelles (`security invoker`)

- **`create_checkout(p_label text, p_notes text, p_items jsonb) returns uuid`** —
  `p_items` = `[{ "item_id": uuid, "quantity": int }, …]`. En une transaction : insère le bon (`status='open'`),
  puis pour chaque ligne : **garde-fou** `quantity_available ≥ q` (sinon `raise exception` → rollback total,
  anti‑survente) ; insère la ligne ; décrémente `quantity_available` + pose `status` ; journalise un `checkout`.
  Retourne l'id du bon.
- **`return_checkout_line(p_checkout_item_id uuid, p_qty int) returns void`** — clampe `p_qty` au restant
  `(quantity - quantity_returned)` ; incrémente `quantity_returned` ; crédite `quantity_available` (plafond
  `quantity`) ; `status='available'` ; journalise un `return` ; si toutes les lignes du bon sont rendues →
  `status='returned'`, `returned_at=now()`.
- **`return_checkout_all(p_checkout_id uuid) returns void`** — rend le restant de chaque ligne (même logique),
  ferme le bon.
- `grant execute … to authenticated` sur les trois.

---

## 5. Couche Swift (ScoutKit) — partagée

- Enum `CheckoutStatus: String` (`open`/`returned`, `label` FR « Ouvert » / « Rendu »).
- `Checkout` (`Codable, Identifiable`, public, `public init`) : `id, label, notes?, status, createdAt?, returnedAt?`.
- `CheckoutItem` : `id, checkoutId, inventoryItemId, quantity, quantityReturned`.
- `CheckoutService` (public) :
  - `list() -> [Checkout]` (ordre `created_at` desc).
  - `lines(checkoutId:) -> [(CheckoutItem, Item)]` (jointure `inventory_items(*)` pour nom/jauge).
  - `create(label:notes:items: [(itemId, qty)]) -> String` (appel RPC `create_checkout`, items en jsonb).
  - `returnLine(checkoutItemId:qty:)` (RPC `return_checkout_line`).
  - `returnAll(checkoutId:)` (RPC `return_checkout_all`).

---

## 6. UI — onglet « Sorties » (ScoutMatériel)

`AppRouter.Tab` gagne `.sorties` ; `MainTabView` passe à **4 onglets** (Dashboard, Matériel, Scan, Sorties).

- **`CheckoutListView`** : liste des bons (ouverts + rendus), libellé + date + badge statut. Bouton **« Nouvelle sortie »** (si `canWrite`). Tap → détail.
- **`CheckoutCartView`** (le panier) : champ **destination/libellé** (requis) + notes ; **ajout d'items** via un picker des items à **dispo > 0** ; chaque ligne du panier = nom + **stepper quantité** (1…`quantity_available` ; **spécifique = 1 figé**) + retrait de ligne ; total d'articles ; **Valider** (désactivé si panier vide ou libellé vide) → `create(label:notes:items:)`. Erreur (ex. stock insuffisant) remontée.
- **`CheckoutDetailView`** : entête (libellé, date, statut) ; lignes avec `sortie` / `rendu` (ex. « 8 / 12 rendu ») ; par ligne une action **« Rendre »** (stepper de la quantité à rendre, max = restant) → `returnLine` ; bouton **« Tout rendre »** (si `canWrite`, ouvert) → `returnAll`. Badge Ouvert/Rendu via Design System.

Charte : statuts/jauges via `SGDFBadge`/`StatusColorMapper` ; actions via `SGDFButton` ; aucune couleur en dur. Écriture gardée par `canWrite` + RLS.

---

## 7. Découpage en incréments (pour le plan)

1. **SQL** : tables `checkouts`/`checkout_items` + RPC `create_checkout` / `return_checkout_line` / `return_checkout_all`.
2. **ScoutKit** : enum + modèles `Checkout`/`CheckoutItem` + `CheckoutService`.
3. **Onglet Sorties — liste + panier** : `AppRouter`/`MainTabView` (4 onglets), `CheckoutListView`, `CheckoutCartView` (création). *(nouveaux fichiers ScoutMatériel → enregistrés au target via la gem par le contrôleur.)*
4. **Fiche bon + retours partiels** : `CheckoutDetailView` (returnLine/returnAll).
5. *(option)* indicateur « sorti via le bon ‹libellé› » sur `MaterialDetailView`.

---

## 8. Garde‑fous / hors périmètre

- Anti‑survente : RPC `create_checkout` refuse si `quantity_available < q` (transaction annulée).
- `quantity_available` plafonné à `quantity` au retour, plancher 0 à la sortie.
- Écriture gardée `canWrite` + RLS `security invoker`.
- **Hors périmètre v1** : modification d'un bon après création (on annule/rend puis recrée) ; lien direct bon↔camp (workflows distincts) ; lookup produit ; export du bon.
