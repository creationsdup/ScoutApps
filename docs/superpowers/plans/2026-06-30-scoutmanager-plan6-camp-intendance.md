# ScoutManager — Plan 6 : Camp (socle) & Intendance

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.
> Pas de target XCTest : chaque task = livrable **build‑vérifié** (`xcodebuild build`) +
> revue, puis vérification écran dans l'app (écrans authentifiés = user‑vérifiables).

**Goal:** Remplacer le placeholder de l'onglet Intendance par le module complet, adossé à une
entité **Camp** pivot : socle Camp → menus → recettes → courses → budget → stock → registre
de traçabilité → scan code‑barres.

**Architecture:** `Views → ViewModels/CampStore → CampService/MealService/RecipeService/
ShoppingService/ExpenseService/FoodStockService/FoodTraceService → SupabaseService.shared.client`.
`CampStore` (@MainActor) porte le camp sélectionné, partagé avec le futur module Programme.

**Spec:** `docs/superpowers/specs/2026-06-30-scoutmanager-camp-intendance-design.md`.

## Global Constraints
- iOS 17+, SwiftUI. Couleurs **uniquement** via le Design System (aucun littéral hex/`Color(...)`).
- `#003a5d` dominant ; création en **orange**, validation **vert**, alertes/erreurs **rouge**, statuts via `StatusColorMapper`.
- **Backend partagé — additif uniquement.** Aucune mutation de `events`/`inventory_items`/`profiles`/enums existants. Migrations idempotentes.
- Conception **défensive** : on ne suppose aucune colonne de `events`. Table `camps` contrôlée par l'app, `event_id` nullable.
- `Codable` ↔ snake_case via `CodingKeys` explicites. `id = UUID().uuidString` généré client à la création.
- Écriture gardée par `SessionStore.canWrite` (viewer = lecture seule), miroir des RLS.
- Erreurs des écritures user remontées (pas de `try?` silencieux).
- Pas d'édition de `project.pbxproj` (groupes synchronisés). Caméra absente du Simulateur → saisie manuelle.

## SQL (à exécuter par l'utilisateur avant les tasks concernées)
Fichier unique additif `supabase/migrations/20260630_scoutmanager_camp_intendance.sql` créé en
**Task M** (tables `camps`), enrichi par chaque task introduisant ses tables. Toutes : RLS
select `authenticated` + write `admin/manager/member` (cf. policies `categories`). Checks d'enum
en `not valid`.

## Tasks

- **Task M — Socle Camp.** SQL `camps`. Modèle `Camp` (+ pas d'enum nouveau, réutilise `Branch`).
  `CampService` (list/create/update/delete). `CampStore` (@MainActor : `camps`, `selectedCamp`,
  persistance de l'id sélectionné via `UserDefaults`). `IntendanceHomeView` (hub) + `CampPickerView`
  + `CampListView`/`CampFormView`. Brancher l'onglet Intendance sur `IntendanceHomeView` ; injecter
  `CampStore` au niveau racine (réutilisable par Programme). État vide = « Créer un camp ».
  *Livrable :* sélectionner/créer un camp, persistant entre lancements.

- **Task N — Menus.** SQL `meals` + `meal_recipes`. Enum `MealSlot`. Modèles `Meal`, `MealRecipe`.
  `MealService` (list par camp, upsert, lien recettes). `MealPlanViewModel`. `MealPlanView` (grille
  **jour × créneau** sur `[start_date…end_date]` du camp sélectionné) + `MealEditorView` (titre,
  notes, recettes liées). *Livrable :* planifier un repas par case jour/créneau.

- **Task O — Recettes.** SQL `recipes` + `recipe_ingredients`. Modèles `Recipe`, `RecipeIngredient`.
  `RecipeService` (CRUD + ingrédients). `RecipeListViewModel`/`RecipeDetailViewModel`. `RecipeListView`
  (bibliothèque), `RecipeDetailView` (**fiche** : ingrédients pour `servings_base` + instructions),
  `RecipeFormView`. Brancher la sélection de recettes dans `MealEditorView` (Task N). *Livrable :*
  consulter/éditer une fiche recette et la lier à un repas.

- **Task P — Liste de courses.** SQL `shopping_items`. Modèle `ShoppingItem` (+ `ShoppingSource`).
  `ShoppingService` : `generate(campId)` = agrège ingrédients des recettes des repas du camp,
  `quantity = ingredient.quantity × ceil(participants / servings_base)` par (name, unit), remplace
  les lignes `source=auto`, préserve `manual`. `ShoppingListViewModel`. `ShoppingListView` : bouton
  « Générer depuis les menus », cochage (`checked`), ajout manuel. *Livrable :* liste générée +
  cochable + ajouts manuels.

- **Task Q — Budget.** SQL `expenses`. Enum `ExpenseCategory`. Modèle `Expense`. `ExpenseService`.
  `BudgetViewModel` (totaux prévu/réel + écart). `BudgetView` + `ExpenseFormView`. *Livrable :*
  saisir des dépenses et voir prévu vs réel.

- **Task R — Stock alimentaire.** SQL `food_stock`. Modèle `FoodStockItem`. `FoodStockService`.
  `FoodStockViewModel`. `FoodStockView` (+ `FoodStockFormView`) avec **badge péremption** (rouge si
  `expiry_date` passée/proche, via `SGDFColors`). *Livrable :* gérer la réserve + alerte péremption.

- **Task S — Registre de traçabilité.** SQL `food_traceability`. Modèle `FoodTraceEntry`.
  `FoodTraceService` (+ photo via `ImageStorageService` existant, sous-dossier `trace/`).
  `FoodTraceViewModel`. `FoodTraceListView` + `FoodTraceFormView` (produit, marque, provenance,
  n° de lot, code-barres en **saisie manuelle**, quantités, dates, lien repas optionnel, photo).
  *Livrable :* enregistrer une entrée de registre complète (sans scan).

- **Task T — Scan code-barres.** `BarcodeScannerView` = base `AVFoundation` de `QRScannerView`
  avec `metadataObjectTypes = [.ean8, .ean13, .qr]`. Brancher un bouton « Scanner » dans
  `FoodTraceFormView` qui pré-remplit `barcode`. Pas de lookup en ligne. *Livrable :* scanner un
  code-barres pré-remplit le champ (saisie manuelle reste possible / Simulateur).

> Chaque task : (1) SQL additif si tables — l'utilisateur l'exécute, (2) modèle + `CodingKeys`,
> (3) service, (4) ViewModel, (5) vues, (6) `xcodebuild build` propre, (7) revue, avant la suivante.
