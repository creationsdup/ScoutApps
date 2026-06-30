# ScoutManager — Design : Camp (socle) & Intendance

**Date :** 2026‑06‑30
**Périmètre :** Spec A — entité **Camp** (pivot partagé) + module **Intendance** complet
(menus, recettes, liste de courses, budget, stock alimentaire, registre de traçabilité).
**Suite :** Spec B « Programme de camp » réutilise le socle Camp (doc séparé).
**Statut MVP‑1 :** complet (Design System, shell 5 onglets, Auth, Dashboard, Matériel, Scan/QR).

---

## 1. Contexte et contraintes

Cette spec ouvre la **phase 2** de ScoutManager : on remplace les onglets placeholder
`ComingSoonView` (« Intendance », « Camp ») par de vrais modules. On reste dans
l'architecture MVVM stricte et la charte SGDF établies en MVP‑1.

**Contraintes non négociables (héritées) :**

| Contrainte | Conséquence |
|------------|-------------|
| **Backend Supabase partagé avec CampManager** | Migrations **additives uniquement** : nouvelles tables/colonnes/RLS/buckets. On ne mute **jamais** `events`, `inventory_items`, `profiles`, ni un enum/colonne/valeur existant. |
| **Schéma `events` inconnu côté iOS** | Conception **défensive** : on ne suppose **aucune** colonne de `events`. On crée notre propre table `camps` qu'on contrôle, avec un `event_id` *nullable* comme pont optionnel. |
| **Couches `Views → ViewModels/Stores → Services → SupabaseClient`** | Les vues ne touchent jamais le réseau. `SupabaseService.shared.client` reste l'unique client. |
| **Charte SGDF source unique de couleur** | Aucune couleur brute dans les vues. Tokens via `SGDFColors`/`StatusColorMapper`/`SGDFTheme`. |
| **Rôles** | Écriture gardée par `SessionStore.canWrite` (viewer = lecture seule), en miroir des RLS. |
| **Codable ↔ snake_case** | Chaque modèle déclare ses `CodingKeys` explicites. |
| **UI en français** | Tous les libellés en français. |

---

## 2. Architecture cible (ajouts)

```
ScoutManager/
  Models/
    Camp.swift              Camp (+ MealSlot, ExpenseCategory enums)
    Meal.swift              Meal, MealRecipe
    Recipe.swift            Recipe, RecipeIngredient
    ShoppingItem.swift      ShoppingItem (+ ShoppingSource)
    Expense.swift           Expense
    FoodStock.swift         FoodStockItem
    FoodTraceEntry.swift    FoodTraceEntry   (registre)
  Stores/
    CampStore.swift         @MainActor : camp sélectionné, partagé Intendance+Programme
  Services/
    CampService.swift       CRUD camps
    MealService.swift       CRUD meals + meal_recipes
    RecipeService.swift     CRUD recipes + ingredients
    ShoppingService.swift   liste de courses (génération + manuel)
    ExpenseService.swift    budget/dépenses
    FoodStockService.swift  stock alimentaire
    FoodTraceService.swift  registre de traçabilité
  ViewModels/
    CampListViewModel, CampFormViewModel
    MealPlanViewModel, RecipeListViewModel, RecipeDetailViewModel
    ShoppingListViewModel, BudgetViewModel, FoodStockViewModel
    FoodTraceViewModel
  Views/
    Intendance/
      IntendanceHomeView        hub : sélecteur de camp + cartes de sous-modules
      Camp/  CampPickerView, CampListView, CampFormView
      Meals/ MealPlanView, MealEditorView
      Recipes/ RecipeListView, RecipeDetailView, RecipeFormView
      Shopping/ ShoppingListView
      Budget/  BudgetView, ExpenseFormView
      Stock/   FoodStockView, FoodStockFormView
      Trace/   FoodTraceListView, FoodTraceFormView (scan code-barres)
  Scan/
    BarcodeScannerView        AVFoundation étendu EAN-8/EAN-13 (réutilisé par le registre)
```

Le socle **Camp** (table + `CampStore` + sélecteur) est livré en premier ; tout le reste
de l'Intendance le consomme.

---

## 3. Modèle de données (SQL additif)

Toutes les tables suivantes sont **nouvelles** (aucune n'existe côté CampManager). RLS
calquée sur `categories`/`locations` : `select` pour `authenticated`, écriture pour
`admin/manager/member`. `id uuid default gen_random_uuid()`, `created_at timestamptz default now()`.

### 3.1 `camps` (socle)
| Colonne | Type | Notes |
|---------|------|-------|
| id | uuid pk | |
| event_id | uuid null → events(id) on delete set null | **pont optionnel** vers l'existant ; jamais requis |
| name | text not null | |
| location | text | lieu du camp |
| start_date | date | |
| end_date | date | |
| branch | text | `LJ/SG/PC/Groupe` (réutilise `Branch`) ; check `not valid` |
| participants_count | int | base de calcul des courses |
| encadrants_count | int | |
| created_by | uuid | `auth.uid()` |

Lien matériel ↔ camp : **via l'`event_id` existant** sur `inventory_items` (le matériel
d'un camp = items dont `event_id = camps.event_id`). Aucune colonne ajoutée à
`inventory_items`.

### 3.2 Intendance
**`meals`** — `camp_id→camps, date date, slot text (petit_dej/midi/gouter/diner), title text, notes text`.
Check `slot in (...)` `not valid`.

**`recipes`** (bibliothèque, **non** scoped camp) — `name text not null, servings_base int not null default 1, instructions text, branch text`.
**`recipe_ingredients`** — `recipe_id→recipes on delete cascade, name text not null, quantity numeric, unit text`.

**`meal_recipes`** — `meal_id→meals on delete cascade, recipe_id→recipes on delete cascade`, pk composite. Lien N‑N repas↔recettes.

**`shopping_items`** — `camp_id→camps, name text not null, quantity numeric, unit text, checked bool default false, source text (auto/manual)`.
La génération calcule `quantity = ingredient.quantity × ceil(participants_count / recipe.servings_base)` agrégé par (name, unit) sur tous les repas du camp ; lignes `source='auto'` régénérables, lignes `source='manual'` préservées.

**`expenses`** — `camp_id→camps, label text not null, category text, amount_planned numeric, amount_real numeric`.

**`food_stock`** — `camp_id→camps, name text not null, quantity numeric, unit text, expiry_date date, location text`.

**`food_traceability`** (registre) — `camp_id→camps, product_name text not null, brand text, supplier text, lot_number text, barcode text, quantity numeric, received_date date, expiry_date date, meal_id uuid null→meals on delete set null, photo_path text`.
`photo_path` réutilise le bucket Storage `item-images` (déjà créé), sous-dossier `trace/`.

### 3.3 RLS & contraintes
Un seul fichier `supabase/migrations/20260630_scoutmanager_camp_intendance.sql`, idempotent
(`if not exists`, `drop/create policy`). Pour chaque table : `enable row level security`,
policy select `authenticated`, policy write `admin/manager/member` (miroir
`can_write_inventory`). Checks d'enum en `not valid` (n'invalide pas l'existant — ici vide).

---

## 4. Modèles Swift

Enums nouveaux :
- `MealSlot: String` — `petitDej="petit_dej", midi, gouter, diner` ; `label` FR
  (« Petit‑déj », « Midi », « Goûter », « Dîner ») ; `CaseIterable` pour l'ordre d'affichage.
- `ShoppingSource: String` — `auto, manual`.
- `ExpenseCategory: String` — `alimentaire, materiel, transport, autre` ; `label` FR.

Structs `Codable, Identifiable` avec `CodingKeys` snake_case explicites (ex. `campId="camp_id"`,
`servingsBase="servings_base"`, `lotNumber="lot_number"`, `receivedDate="received_date"`).
À la création : `id = UUID().uuidString` généré client (Postgres accepte un uuid fourni),
comme pour `Item`.

---

## 5. Surfaces (écrans) & flux

**Onglet Intendance → `IntendanceHomeView` (hub).** En tête : `CampPickerView`
(camp sélectionné, persistant via `CampStore`). Si aucun camp : `EmptyStateView` +
bouton « Créer un camp ». Sous le sélecteur, une grille de `SGDFCard` vers les
sous‑modules : Menus, Recettes, Courses, Budget, Stock, Registre.

| Sous‑module | Écran | Contenu |
|-------------|-------|---------|
| **Camp** | `CampListView`/`CampFormView` | CRUD camps ; formulaire dates/lieu/branche/effectifs. |
| **Menus** | `MealPlanView` | grille **jour × créneau** sur `[start_date…end_date]` ; tap → `MealEditorView` (titre, recettes liées, notes). |
| **Recettes** | `RecipeListView`/`RecipeDetailView` | bibliothèque ; détail = **fiche recette** (ingrédients pour `servings_base`, instructions) ; `RecipeFormView` en écriture. |
| **Courses** | `ShoppingListView` | bouton « Générer depuis les menus » (agrège, scale par participants) ; lignes cochables ; ajout manuel ; auto vs manuel distingués. |
| **Budget** | `BudgetView` | total prévu/réel + écart ; liste `expenses` ; `ExpenseFormView`. |
| **Stock** | `FoodStockView` | denrées ; **alerte péremption** (badge rouge si `expiry_date` proche/passée). |
| **Registre** | `FoodTraceListView`/`FoodTraceFormView` | traçabilité ; formulaire avec **scan code‑barres** (pré‑remplit `barcode`), saisie lot/provenance, photo optionnelle. |

**Couleurs (charte) :** Intendance = identité bleu primaire (titres/nav) ; actions de
création en **orange** ; validations/retours en **vert** ; alertes péremption/erreurs en
**rouge** (via `StatusColorMapper`/`SGDFColors`, jamais en dur).

---

## 6. Scan code‑barres (incrément isolé)

`BarcodeScannerView` = même base `AVFoundation` que `QRScannerView`, mais
`metadataObjectTypes = [.ean8, .ean13, .qr]`. Retourne la chaîne brute (EAN) au
`FoodTraceViewModel` qui la place dans `barcode`. **Pas** de lookup produit en ligne en V1
(saisie manuelle du nom/provenance). Caméra indisponible en Simulateur → saisie manuelle du
code (cohérent avec MVP‑1). Cet incrément est **livré en dernier** : le registre fonctionne
sans lui (saisie manuelle), le scan est un confort.

---

## 7. Découpage en incréments (pour le plan)

1. **Socle Camp** : table + `Camp` + `CampService` + `CampStore` + sélecteur + CRUD.
2. **Menus** : `meals`/`meal_recipes` + grille jour×créneau + éditeur.
3. **Recettes** : `recipes`/`recipe_ingredients` + liste + fiche + formulaire.
4. **Courses** : `shopping_items` + génération (scale participants) + cochage + manuel.
5. **Budget** : `expenses` + totaux prévu/réel.
6. **Stock** : `food_stock` + alerte péremption.
7. **Registre (traçabilité)** : `food_traceability` + formulaire + photo.
8. **Scan code‑barres** : `BarcodeScannerView` branché sur le registre.

Chaque incrément : migration additive (si tables) → modèle → service → VM → vues →
build‑vérifié → revue, avant le suivant.

---

## 8. Hors périmètre (cette spec)

- Lookup produit en ligne par code‑barres (Open Food Facts…) — V2 éventuelle.
- Export PDF du registre / des menus.
- Partage multi‑utilisateurs temps réel (au‑delà du backend partagé).
- Programme de camp → **Spec B**.
