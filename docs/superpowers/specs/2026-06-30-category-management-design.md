# Gestion des catégories & sous-catégories (organisation du matériel) — Design

Date : 2026-06-30
Module : ScoutMatériel (`ScoutInventory`) + ScoutKit
Statut : validé (brainstorming)

## Objectif

Donner à l'utilisateur un écran pour **organiser le matériel** depuis l'app (sans passer par
SQL) : créer/renommer/supprimer des **catégories** (nom + code) et leurs **sous-catégories**.
Accessible via un bouton dans la barre d'outils de la liste **Matériel**.

Cet écran était explicitement « hors périmètre / plus tard » dans la spec
`2026-06-30-categories-subcategories-codes-design.md` ; on le construit maintenant.

## Contraintes héritées

- Backend partagé avec CampManager : **aucune migration** nécessaire ici (les tables
  `categories`, `subcategories` et les contraintes existent déjà). Lectures/écritures via les
  RLS existantes (écriture réservée à `admin`/`manager`/`member`).
- Couleurs uniquement via `SGDFColors` / `StatusColorMapper` ; pas de hex en vue.
- Symboles ScoutKit utilisés par l'app en `public`.
- Erreurs des écritures remontées à l'UI (pas de `try?` silencieux).
- UI en français.
- Nouveau fichier `.swift` sous `ScoutMateriel/` → à ajouter à la cible `ScoutInventory`
  (pbxproj) ; les fichiers ScoutKit sont auto-inclus (dossier).

## Décisions de cadrage

- Périmètre : **catégories + sous-catégories** (arborescence à 2 niveaux).
- Opérations : **créer + renommer + supprimer** (catégorie et sous-catégorie).
- **Code catégorie** : modifiable tant que la catégorie n'a **aucun item** ; verrouillé
  ensuite (les codes déjà générés type `TEN-0001` ne sont jamais renumérotés).
- Suppression **autorisée avec avertissement**. La base gère le détachement via les FK
  existantes (voir §4).
- Bouton dans la **barre d'outils Matériel**, visible seulement si `session.canWrite`.

---

## 1. Accès & présentation

- `MaterialListView` gagne `@EnvironmentObject private var session: SessionStore` (déjà injecté
  dans l'arbre — utilisé par `MaterialDetailView`).
- Nouveau `ToolbarItem(placement: .topBarLeading)` : un bouton `Image(systemName:
  "folder.badge.gearshape")` présenté **uniquement si `session.canWrite`**, à côté du `+`
  existant. `accessibilityLabel("Organiser le matériel")`.
- Il ouvre une `.sheet` sur `CategoryManagerView`. À la fermeture (`onDismiss`), la liste
  recharge ses référentiels : `await viewModel.loadReferentials(); await viewModel.load()`.

## 2. Écran `CategoryManagerView`

`NavigationStack` + `List` :

- Une `Section` par catégorie ; l'en-tête affiche `nom` + le `code` (badge discret en
  `SGDFColors.textSecondary`). Chaque section liste ses sous-catégories.
- Actions par ligne (swipe `.swipeActions` + menu) :
  - Catégorie : « Renommer », « Supprimer ».
  - Sous-catégorie : « Renommer », « Supprimer ».
  - Pied de section catégorie : bouton « + Sous-catégorie ».
- Barre d'outils : bouton `+` « Nouvelle catégorie » ; bouton « Fermer ».
- États : `LoadingView` pendant chargement, `EmptyStateView` si aucune catégorie,
  message d'erreur en `SGDFColors.red`.

Création/édition via une sous-vue `CategoryEditView` (présentée en sheet) :
- Champ **Nom** (obligatoire).
- Champ **Code** (obligatoire en création) : `textInputAutocapitalization(.characters)`,
  `autocorrectionDisabled()`. En édition, **désactivé** si la catégorie a des items
  (`itemCount > 0`), avec une note « Code verrouillé : des objets utilisent cette catégorie ».
- Validation locale : nom non vide ; code conforme `^[A-Z]{2,4}$`. Bouton « Enregistrer »
  désactivé sinon. Les erreurs base (doublon de code…) sont affichées.

Édition d'une sous-catégorie : une simple alerte/sheet avec un champ **Nom**.

## 3. ScoutKit — `CategoryService` (nouveau, writes)

Nouveau fichier `ScoutKit/Sources/ScoutKit/Services/CategoryService.swift`. Réutilise
`SupabaseService.shared.client`. Les **lectures** restent dans `ItemService`
(`listCategories`, `listSubcategories`).

API (toutes `public`, `async throws`) :

```swift
public struct CategoryService {
    public init() {}
    private var client: SupabaseClient { SupabaseService.shared.client }

    // Catégories
    @discardableResult
    public func createCategory(name: String, code: String) async throws -> ItemCategory
    public func updateCategory(id: String, name: String, code: String?) async throws
    public func deleteCategory(id: String) async throws

    // Sous-catégories
    @discardableResult
    public func createSubcategory(categoryId: String, name: String) async throws -> Subcategory
    public func updateSubcategory(id: String, name: String) async throws
    public func deleteSubcategory(id: String) async throws

    // Règle de verrouillage du code
    public func itemCount(categoryId: String) async throws -> Int
}
```

Détails d'implémentation :
- Inserts/updates via petits payloads `Encodable` en snake_case (`name`, `code`,
  `category_id`). `updateCategory` n'écrit `code` que s'il est non-nil (cas non verrouillé).
- `itemCount` : `select("id", head:true, count:.exact)` sur `inventory_items` filtré
  `category_id` → renvoie `response.count ?? 0`. (À défaut de `count`, fallback : récupérer
  les `id` et compter — un seul des deux, déterminé à l'implémentation selon l'API
  supabase-swift disponible ; le plan tranchera avec le code exact.)
- `deleteCategory`/`deleteSubcategory` : `.delete().eq("id", value: id).execute()`.

## 4. Suppression — comportement base (FK existantes)

Aucune logique applicative de détachement n'est nécessaire ; les FK déjà en place font le
travail :
- `subcategories.category_id → categories(id) on delete cascade` : supprimer une catégorie
  supprime ses sous-catégories.
- `inventory_items.category_id → categories(id) on delete set null` : les items perdent leur
  catégorie (restent visibles sous « Sans catégorie » dans la liste groupée).
- `inventory_items.subcategory_id → subcategories(id) on delete set null` : idem pour la
  sous-catégorie.

L'UI affiche une **confirmation** avant suppression. Si la catégorie a des items, le message
le précise (« N objet(s) seront détachés »).

## 5. ViewModel — `CategoryManagerViewModel`

`@MainActor final class … : ObservableObject` sous `ScoutMateriel/ViewModels/` :
- `@Published categories: [ItemCategory]`, `subcategories: [Subcategory]`,
  `itemCounts: [String: Int]` (par catégorie), `isLoading`, `errorMessage`.
- `load()` : charge catégories + sous-catégories (via `ItemService`) et les `itemCounts`
  (via `CategoryService.itemCount`).
- `subcategories(of:)` : filtre par `categoryId`.
- `canEditCode(categoryId:) -> Bool` : `(itemCounts[id] ?? 0) == 0`.
- Méthodes d'action (`createCategory`, `renameCategory`, `deleteCategory`,
  `createSubcategory`, `renameSubcategory`, `deleteSubcategory`) : appellent `CategoryService`,
  puis `await load()` ; en cas d'échec, renseignent `errorMessage` (message FR).

## 6. Découpage des unités (fichiers)

| Fichier | Responsabilité |
|---|---|
| `ScoutKit/.../Services/CategoryService.swift` (create) | écritures catégories/sous-catégories + `itemCount` |
| `ScoutMateriel/ViewModels/CategoryManagerViewModel.swift` (create) | état + actions de l'écran |
| `ScoutMateriel/Views/Material/CategoryManagerView.swift` (create) | liste + sheets d'édition (`CategoryEditView` interne) |
| `ScoutMateriel/Views/Material/MaterialListView.swift` (modify) | bouton toolbar + sheet + reload onDismiss + `session` |

## 7. Vérification

- Pas de cible XCTest → `xcodebuild build` des deux schémas (`ScoutInventory`, `ScoutCamp`).
- Scénarios manuels : ouvrir l'écran ; créer une catégorie (`SAC`/« Sacs ») ; créer une
  sous-catégorie ; renommer ; créer un item dans cette catégorie → le code devient verrouillé ;
  supprimer une sous-catégorie (item détaché) ; supprimer une catégorie (avertissement) ;
  un **viewer** ne voit pas le bouton.
- Code dupliqué refusé (message d'erreur) ; code mal formé refusé côté UI.

## Hors périmètre

- Réorganisation par glisser-déposer / réordonnancement manuel des catégories.
- Déplacement en masse d'items d'une catégorie à une autre.
- Gestion des **localisations** (hors sujet ici).
- Fusion de catégories.
