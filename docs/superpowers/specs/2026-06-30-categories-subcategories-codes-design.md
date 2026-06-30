# Catégories / sous-catégories, codes auto-générés, vignettes liste — Design

Date : 2026-06-30
Module : ScoutMatériel (`ScoutInventory`) + ScoutKit
Statut : validé (brainstorming)

## Objectif

Dans le module **Matériel**, permettre de :

1. **Classer par catégorie ET sous-catégorie** (hiérarchie stricte à 2 niveaux) :
   liste groupée en sections + filtres dépendants.
2. **Simplifier les codes** : un code unique par item, auto-généré au format
   `<CODE_CATÉGORIE>-NNNN` (ex. `TEN-0001`). Le préfixe est le code de la catégorie.
3. **Afficher la vignette** du produit à gauche du titre dans chaque ligne de la liste.

## Contrainte majeure — backend partagé

Le projet Supabase est partagé avec CampManager. **Toutes les migrations sont additives**
(nouvelles tables/colonnes/fonctions). Rien d'existant n'est modifié, renommé ou supprimé.
La table `qr_tags` est conservée (CampManager peut l'utiliser) ; l'app cesse simplement de
s'en servir pour l'assignation.

## Décisions de cadrage

- Hiérarchie : **catégorie → sous-catégorie**, 2 niveaux stricts (table `subcategories` dédiée).
- Préfixe de tag = **code de la catégorie**, champ dédié saisi à la création de la catégorie.
- Numérotation **par catégorie** (séquence indépendante par catégorie).
- Aucune étiquette QR physique n'est imprimée → migration complète, pas de rétro-compat `TAG-`.
- **Code unifié** : le `inventory_code` de l'item EST le tag. Plus de double code.
- **Catégorie obligatoire** à la création (nécessaire pour générer le code).
- **Pas d'écran de gestion** des catégories/sous-catégories cette itération : elles sont
  créées en base via SQL. L'app ne fait que les sélectionner.
- Liste : **sections groupées + filtres** (les deux).

---

## 1. Modèle de données (migrations additives)

Nouvelle migration `supabase/migrations/20260702_categories_subcategories_codes.sql` :

```sql
-- Code de catégorie (préfixe de tag), additif
alter table public.categories
  add column if not exists code text;

-- Unicité du code (sur les valeurs non nulles)
create unique index if not exists categories_code_key
  on public.categories (upper(code)) where code is not null;

-- Sous-catégories (niveau 2)
create table if not exists public.subcategories (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now()
);

-- Lien item → sous-catégorie (nullable)
alter table public.inventory_items
  add column if not exists subcategory_id uuid references public.subcategories(id) on delete set null;

-- RLS sous-catégories : lecture authentifiée, écriture admin/manager/member
alter table public.subcategories enable row level security;
-- (policies calquées sur public.categories — voir migration mvp1)

-- Génération atomique du prochain code par catégorie
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
    raise exception 'categorie sans code';
  end if;
  -- verrou par catégorie pour éviter les collisions
  perform pg_advisory_xact_lock(hashtext(v_code));
  select coalesce(max(
           nullif(regexp_replace(inventory_code, '^' || v_code || '-', ''), inventory_code)::int
         ), 0) + 1
    into v_seq
    from public.inventory_items
   where inventory_code ~ ('^' || v_code || '-[0-9]+$');
  return v_code || '-' || lpad(v_seq::text, 4, '0');
end;
$$;
```

> Note : la fonction lit le `max` des codes existants de la catégorie et incrémente, sous
> verrou transactionnel. Robuste face aux créations concurrentes. Format `NNNN` = 4 chiffres
> (extensible si > 9999 ; lpad ne tronque pas).

Un seed d'exemple (catégories + codes + sous-catégories) sera fourni ; l'utilisateur ajoute
ses vraies catégories par SQL.

## 2. Couche ScoutKit (modèles + services)

### Modèles

- `ItemCategory` : ajout `public var code: String?` (CodingKey `code`). `init` mis à jour.
- Nouveau `Subcategory` (`Models/Subcategory.swift`) :
  ```swift
  public struct Subcategory: Codable, Identifiable, Hashable {
      public let id: String
      public var categoryId: String   // "category_id"
      public var name: String
      public init(id: String, categoryId: String, name: String)
  }
  ```
- `Item` : ajout `public var subcategoryId: String?` (CodingKey `subcategory_id`).
  Le `CodingKeys` complet doit lister la nouvelle clé.

### Services (`ItemService`)

- `listSubcategories(categoryId:)` → `subcategories` filtré par `category_id`, ordonné par `name`.
  (et/ou `listSubcategories()` global pour résoudre les noms en liste.)
- `nextInventoryCode(categoryId:)` → appelle la fonction RPC `next_inventory_code`.
- `create(...)` : génère `inventory_code` via `nextInventoryCode` quand l'appelant ne fournit
  pas de code (cas création). `subcategory_id` ajouté à l'insert.
- `list(...)` : ajout d'un filtre optionnel `subcategoryId`.

### Format de code (`QRCode.swift` / `TagCode`)

- Regex `^TAG-\\d{6}$` → `^[A-Z]{2,4}-\\d{4}$`.
- `TagCode.parse` conserve le trim + uppercase.

## 3. Scanner — résolution sur `inventory_code`

Aujourd'hui le scan résout `tag_code` (table `qr_tags`) → item. Avec le code unifié, le scan
résout directement `inventory_items.inventory_code`.

- `ItemService` : `item(byCode:)` (query `inventory_items` sur `inventory_code`).
- `ScannerViewModel.resolve` et `InventoryViewModel` : utilisent `item(byCode:)` au lieu du
  chemin `qr_tags`. Code introuvable → message « Code inconnu ».
- `QRCodeService` (assign blank tag) : devient inutilisé par l'app. On ne le supprime pas
  (additif/non destructif), mais les vues `AssignQRCodeView` ne sont plus présentées dans le
  flux de création. Le `QRCodeService.generateImage(for:)` reste utilisé pour afficher le QR
  d'un item à partir de son `inventory_code`.
- Placeholders / messages d'erreur « TAG-000001 » → exemple générique « TEN-0001 » dans :
  `QRScannerView`, `InventoryView`, `ScannerViewModel`, `InventoryViewModel`,
  `MaterialFormView`.

## 4. Liste Matériel (`MaterialListView` + `MaterialListViewModel`)

### Groupement en sections

- `MaterialListViewModel` expose une structure groupée : `[(category, [(subcategory?, [Item])])]`,
  triée par nom de catégorie puis sous-catégorie ; items sans sous-catégorie regroupés sous
  « Sans sous-catégorie ». Le groupement se fait côté view model à partir des `items` chargés
  et des référentiels (`categories`, `subcategories`).
- `MaterialListView` : `List` avec `Section` par catégorie ; en-têtes de section repliables
  (état d'expansion conservé dans la vue). Sous-catégorie en sous-en-tête ou préfixe de section.

### Filtres

- Filtre **catégorie** existant conservé.
- Ajout filtre **sous-catégorie**, dont les options dépendent de la catégorie sélectionnée
  (vidé si aucune catégorie choisie). Passé à `ItemService.list(subcategoryId:)`.

### Vignette dans la ligne (`MaterialRow`)

- Ajout, en **premier enfant** du `HStack`, d'une vignette ~48×48 :
  - URL via `ImageStorageService().publicURL(for: item.imagePath)`.
  - `AsyncImage` : succès → `scaledToFill` clippé `RoundedRectangle`; échec/absence →
    rectangle `SGDFColors.border` + `Image(systemName: "photo")` en `textSecondary`.
- Respect de la charte : aucune couleur hors `SGDFColors` ; pas de hex en vue.

## 5. Formulaire (`MaterialFormView` + `MaterialFormViewModel`)

- Picker **catégorie** (obligatoire — validation bloque la sauvegarde si vide).
- Picker **sous-catégorie** : options filtrées sur la catégorie choisie ; optionnel ;
  réinitialisé si la catégorie change.
- Champ « code inventaire » :
  - **Création** : masqué (auto-généré au save via `nextInventoryCode`).
  - **Édition** : affiché en **lecture seule** (le code ne change pas).
- En édition, changer la catégorie **ne renumérote pas** le code existant.

## 6. Charte & contraintes respectées

- Couleurs uniquement via `SGDFColors` / `StatusColorMapper` ; `Color(hex:)` confiné au
  DesignSystem.
- Symboles ScoutKit utilisés par l'app exposés en `public` (modèles, services, init).
- Erreurs des écritures utilisateur remontées à l'UI (pas de `try?` silencieux).
- Nouveaux fichiers `.swift` côté app (`Subcategory` est dans ScoutKit → dossier, OK ; tout
  nouveau fichier sous `ScoutMateriel/` doit être ajouté à la cible `ScoutInventory`).

## 7. Vérification

- Pas de cible XCTest → vérification par `xcodebuild build` des deux schémas
  (`ScoutInventory` et `ScoutCamp`) puis exécution de l'app.
- Scénarios manuels : créer une catégorie + sous-catégories en SQL ; créer un item
  (code auto `XXX-0001`) ; en créer un 2e (`XXX-0002`) ; scanner/saisir ce code → fiche ;
  liste groupée + filtres ; vignette affichée.

## Hors périmètre (cette itération)

- Écran de gestion des catégories/sous-catégories dans l'app (création/édition depuis l'UI).
- Migration/rétro-compatibilité des codes `TAG-` (aucune étiquette imprimée).
- Renumérotation des items existants.
