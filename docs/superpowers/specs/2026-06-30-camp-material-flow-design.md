# Flux matériel partagé camp ↔ inventaire (design) — Projet 2

**Date :** 2026‑06‑30
**Périmètre :** liste de chargement d'un camp dans **ScoutCamp**, synchronisée avec la
disponibilité de l'inventaire dans **ScoutMatériel**, via le backend partagé. Suite du
Projet 1 (scission ScoutMatériel + ScoutCamp + package ScoutKit).
**Prérequis :** scission livrée (deux apps, `ScoutKit`). Touche **les deux apps + ScoutKit**.

---

## 1. Contexte et décisions

ScoutCamp gère un camp (intendance, programme). On veut suivre le **matériel emporté** : on
sélectionne des items de l'inventaire pour le camp, ils deviennent **Sorti** dans ScoutMatériel
(l'app inventaire sait qu'ils sont partis), et au retour ils redeviennent **Disponible** — avec
un **mouvement** journalisé à chaque fois. C'est la sortie/entrée de matériel pilotée depuis le camp.

Décisions validées :
- **Statut réutilisé** : `sorti` (checked_out) — pas de nouveau statut. Réutilise
  `MovementAction.checkout/return` (déjà : checkout→sorti, return→disponible).
- **Granularité v1 : item entier** (spécifique comme global). Pas de prise partielle de quantité
  (raffinement futur).
- **Opérations atomiques via RPC Postgres** (leçon de la génération de courses) : assignation et
  retour font 3 écritures (chargement + statut + mouvement) dans **une transaction**.
- **3ᵉ onglet « Matériel »** dans ScoutCamp.
- **Backend partagé** : additif uniquement ; réutilise `inventory_items`, `item_movements`,
  `program_slot_materials` ; ajoute `camp_materials` + 2 fonctions.

---

## 2. Modèle de données (additif)

**Nouvelle table `camp_materials`** — la liste de chargement (source de vérité du matériel du camp) :

| Colonne | Type | Notes |
|---------|------|-------|
| camp_id | uuid not null → camps(id) on delete cascade | |
| inventory_item_id | uuid not null → inventory_items(id) on delete cascade | item entier |
| added_by | uuid | `auth.uid()` |
| added_at | timestamptz not null default now() | |
| **PK** | (camp_id, inventory_item_id) | un item au plus une fois par camp |

RLS calquée sur les autres tables (select `authenticated`, write `admin/manager/member`).

**Réutilisé, inchangé** : `inventory_items.status` (bascule `sorti`/`available`),
`item_movements` (journal, via `MovementAction` `checkout`/`return`, `event_id` best‑effort),
`program_slot_materials` (liens activité↔item, déjà créés au Projet Programme).

---

## 3. RPC transactionnelles (fichier SQL additif)

`security invoker` → la RLS de `camp_materials`/`inventory_items`/`item_movements` s'applique
(un viewer reçoit une erreur, miroir de `canWrite`). `grant execute … to authenticated`.

**`assign_material_to_camp(p_camp_id uuid, p_item_id uuid) returns void`** :
1. `insert into camp_materials(camp_id, inventory_item_id, added_by) values (p_camp_id, p_item_id, auth.uid()) on conflict do nothing;`
2. `update inventory_items set status = 'checked_out' where id = p_item_id;`
3. `insert into item_movements(item_id, action, user_id, event_id) values (p_item_id, 'checkout', auth.uid(), (select event_id from camps where id = p_camp_id));`

**`return_material_from_camp(p_camp_id uuid, p_item_id uuid) returns void`** :
1. `delete from camp_materials where camp_id = p_camp_id and inventory_item_id = p_item_id;`
2. `update inventory_items set status = 'available' where id = p_item_id;`
3. `insert into item_movements(item_id, action, user_id, event_id) values (p_item_id, 'return', auth.uid(), (select event_id from camps where id = p_camp_id));`

Les deux sont idempotentes au niveau `camp_materials` (`on conflict do nothing` / `delete`).
Le statut est posé de façon idempotente (valeur cible fixe).

> Remarque : `'checked_out'`/`'available'` sont les rawValues DB de `ItemStatus.sorti`/`.disponible`.

---

## 4. Cohérence camp ↔ activité

- **Rattacher un item à une activité** (`SlotMaterialPickerView` existant, ScoutCamp) appelle
  **aussi** `assign_material_to_camp` pour chaque item sélectionné (idempotent) → l'item entre dans
  le chargement et passe `sorti`. Impossible de planifier un matériel « pas pris ».
- **Retirer un item d'une activité** ne déclenche **pas** de retour (l'item peut servir ailleurs ou
  rester dans la malle). Le retour est explicite, depuis l'onglet Matériel.
- Le chargement (`camp_materials`) reste la source de vérité de la disponibilité.

---

## 5. Couche Swift (ScoutKit) — services & modèle

- **Modèle `CampMaterial`** (`Codable, Identifiable`) : `campId`, `inventoryItemId`, `addedAt` ;
  `id = inventoryItemId` (unique par camp). CodingKeys snake_case.
- **`CampMaterialService`** (ScoutKit) :
  - `items(campId:) async throws -> [Item]` — items du chargement (jointure camp_materials → inventory_items, renvoie des `Item` pour afficher nom + statut).
  - `assign(campId:itemId:) async throws` — appelle la RPC `assign_material_to_camp`.
  - `remove(campId:itemId:) async throws` — appelle `return_material_from_camp`.
  - `returnAll(campId:) async throws` — récupère les ids du chargement puis `return_material_from_camp` pour chacun (boucle).
  - `campLabel(forItemId:) async throws -> String?` — pour ScoutMatériel : nom du camp qui détient l'item (lecture `camp_materials` ⋈ `camps`), nil si non emporté.
- Réutilise `ItemService` (liste des items disponibles pour le picker) et `MovementAction`/`MovementService` n'est PAS rappelé directement (la RPC fait le mouvement). `MovementService` reste pour les flux matériel classiques.

---

## 6. UI

**ScoutCamp — 3ᵉ onglet « Matériel » (`CampMaterialView`)** :
- En tête : dépend du camp sélectionné (`CampStore`). Si aucun camp → `EmptyStateView`.
- Liste du chargement : nom de l'item + `SGDFBadge(status:)`. Vide → message + bouton ajouter.
- **« Ajouter du matériel »** (si `canWrite`) → picker des items **disponibles** (`ItemService.list(status: .disponible)`), multi‑sélection ; valider appelle `assign` pour chacun. Items non disponibles non proposés (anti‑double‑réservation).
- **Swipe = rendre** un item (si `canWrite`) → `remove`. Bouton **« Tout rendre »** (si `canWrite`, confirmation) → `returnAll` (fin de camp).
- `CampTabView` passe de 2 à **3 onglets** : Intendance / Programme / Matériel.

**ScoutMatériel — `MaterialDetailView`** : si l'item est dans un `camp_materials`, afficher une
ligne lecture seule **« Sorti pour : ‹nom du camp› »** (via `CampMaterialService.campLabel(forItemId:)`),
sous le badge de statut. Aucune autre modification de ScoutMatériel.

**Charte** : badges via `StatusColorMapper`/`SGDFBadge` ; actions via `SGDFButton` (orange pour ajouter, etc.) ; aucune couleur en dur.

---

## 7. Garde‑fous

- Écritures gardées par `canWrite` côté app ET par la RLS (RPC `security invoker`) côté serveur.
- Le picker ne propose que les items `disponible` → pas d'item déjà sorti ailleurs.
- Erreurs des RPC remontées à l'écran (pas de `try?` silencieux).
- `camp_materials` additif ; aucune mutation des tables existantes. `item_movements.action`
  réutilise les valeurs `checkout`/`return` déjà émises par `MovementService`.
- Pas de target XCTest : vérif `xcodebuild build` des **deux** schemes + lancement.

---

## 8. Découpage en incréments (pour le plan)

1. **SQL** : table `camp_materials` + RPC `assign_material_to_camp` / `return_material_from_camp` (fichier additif, à exécuter par l'utilisateur).
2. **ScoutKit** : modèle `CampMaterial` + `CampMaterialService` (items/assign/remove/returnAll/campLabel).
3. **ScoutCamp** : 3ᵉ onglet « Matériel » (`CampMaterialView` + picker d'ajout) ; `CampTabView` à 3 onglets.
4. **Cohérence activité** : `SlotMaterialPickerView`/`ProgramSlotFormView` appellent aussi `assign` au rattachement.
5. **ScoutMatériel** : « Sorti pour : ‹camp› » dans `MaterialDetailView`.

---

## 9. Hors périmètre

- Prise **partielle** de quantité pour les items globaux (item entier seulement en v1).
- Réservation temporelle (statut différent selon camp futur/en cours).
- Transfert direct d'un camp à un autre (passer par un retour puis une nouvelle assignation).
- Modification de `item_movements`/`inventory_items` (schéma inchangé).
