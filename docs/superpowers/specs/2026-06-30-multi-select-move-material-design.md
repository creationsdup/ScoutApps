# Sélection multiple + déplacement de matériel — Design

**Date :** 2026-06-30
**App :** ScoutMatériel (target `ScoutInventory`)
**Module :** Matériel

## Objectif

Permettre à un utilisateur (avec droit d'écriture) de **sélectionner plusieurs
matériels** dans la liste Matériel et de les **déplacer en une action** vers une
catégorie ou une sous-catégorie cible.

Sémantique « déplacer » (validée) : la cible écrase toujours `categoryId` **et**
`subcategoryId`. Choisir une **catégorie seule** range les items à la racine de
cette catégorie (`subcategoryId = nil`). Pour ranger dans une sous-catégorie, on
choisit explicitement la sous-catégorie.

## Périmètre

- App **ScoutMatériel** uniquement (scheme `ScoutInventory`).
- Écran **Matériel** (`MaterialListView`) et son `MaterialListViewModel`.
- Méthode de déplacement en masse sur `ItemService` (ScoutKit).
- Réservé aux rôles `canWrite` (viewer = lecture seule).

Hors périmètre : déplacement par glisser-déposer, déplacement inter-app,
modification d'autres champs en masse (statut, lieu, etc.).

## Composants

### 1. `ItemService.move` (ScoutKit — bulk update)

`/ScoutKit/Sources/ScoutKit/Services/ItemService.swift`

Nouvelle méthode publique, calquée sur le pattern existant `markChecked` :

```swift
public func move(itemIds: [String], categoryId: String, subcategoryId: String?) async throws
```

- Payload privé `Encodable` avec clés snake_case DB : `category_id`, `subcategory_id`.
- Écriture en une requête : `client.from("inventory_items").update(payload).in("id", values: itemIds)`.
- `subcategory_id` encodé même quand `nil` (pour effacer la sous-catégorie côté DB) ;
  le payload doit donc encoder explicitement `null` (ne pas omettre la clé).
- `itemIds` vide ⇒ retour immédiat sans requête (garde défensive).

Backend : `inventory_items` est une table **existante partagée** ; on ne modifie
que des lignes via colonnes `category_id` / `subcategory_id` déjà présentes. Aucune
migration nécessaire. Additif uniquement, conforme à la contrainte backend partagé.

### 2. `MaterialListViewModel.move` (ViewModel)

`/ScoutMateriel/ViewModels/MaterialListViewModel.swift`

```swift
func move(itemIds: Set<String>, categoryId: String, subcategoryId: String?) async -> Bool
```

- Appelle `service.move(itemIds: Array(itemIds), categoryId:, subcategoryId:)`.
- Sur succès : `await load()` (rafraîchit `items` et donc le groupement `groups`),
  retourne `true`.
- Sur erreur : positionne `errorMessage`, retourne `false`. Pas de `try?` silencieux.

Le VM possède déjà `categories: [ItemCategory]` et `subcategories: [Subcategory]`
(chargés par `loadReferentials()`), réutilisés tels quels pour le picker cible.

### 3. Mode sélection dans `MaterialListView`

`/ScoutMateriel/Views/Material/MaterialListView.swift`

État ajouté :
- `@State private var isSelecting = false`
- `@State private var selectedIds: Set<String> = []`
- `@State private var showMoveSheet = false`

Toolbar (gating `if session.canWrite`) :
- **Hors mode sélection :** ajoute un bouton **« Sélectionner »** qui passe
  `isSelecting = true`. Les boutons existants (+, organiser, filtres) restent.
- **En mode sélection :** bouton **« Annuler »** (`isSelecting = false`,
  `selectedIds = []`) et bouton **« Déplacer (N) »** désactivé si
  `selectedIds.isEmpty`, qui ouvre `showMoveSheet`.

Liste / `MaterialRow` :
- En mode sélection, chaque ligne devient un tap-toggle (pattern
  `CampMaterialView.AddMaterialSheet`) : `.contentShape(Rectangle())` +
  `.onTapGesture` qui insère/retire `item.id` dans `selectedIds`. Une coche
  (`checkmark.circle.fill` sélectionné / `circle` sinon) est affichée en tête de
  ligne. Couleurs issues du Design System (`SGDFColors`), jamais de hex en vue.
- Hors mode sélection, comportement actuel inchangé (`NavigationLink` vers la fiche).
- Implémentation : la ligne reste dans la `List` groupée existante ; en mode
  sélection on rend la `MaterialRow` sans `NavigationLink` (ou `NavigationLink`
  désactivé) pour éviter la navigation accidentelle.

### 4. `MoveItemsSheet` (nouvelle sous-vue)

Présentée en `.sheet(isPresented: $showMoveSheet)` depuis `MaterialListView`.

- Reçoit `categories: [ItemCategory]`, `subcategories: [Subcategory]`, le nombre
  d'items sélectionnés, et un callback de confirmation
  `(_ categoryId: String, _ subcategoryId: String?) -> Void`.
- État interne : `@State selectedCategoryId: String?`, `@State selectedSubcategoryId: String?`.
- UI (`Form` / `NavigationStack`) :
  - En-tête FR rappelant « N matériel(s) sélectionné(s) ».
  - Picker **Catégorie** (obligatoire).
  - Picker **Sous-catégorie** : option « Aucune » + sous-catégories filtrées
    `subcategories.filter { $0.categoryId == selectedCategoryId }`. Réinitialisé à
    « Aucune » quand la catégorie change.
  - Bouton **« Déplacer »** désactivé tant que `selectedCategoryId == nil`.
- Au tap « Déplacer » : appelle le callback puis ferme la sheet.

## Flux de données

1. `canWrite` → bouton « Sélectionner » → `isSelecting = true`.
2. Taps sur lignes → mise à jour de `selectedIds`.
3. « Déplacer (N) » → `MoveItemsSheet`.
4. Choix catégorie (+ sous-catégorie optionnelle) → callback →
   `Task { let ok = await viewModel.move(...) ; if ok { isSelecting = false; selectedIds = [] } }`.
5. `viewModel.move` → `ItemService.move` (1 requête) → `await load()` → la liste se
   regroupe automatiquement via `groups`.

## Gestion d'erreurs

- Échec réseau / DB : `errorMessage` sur le VM, affiché via le mécanisme d'alerte
  existant de `MaterialListView`. Le mode sélection reste actif pour réessayer.
- Aucune catégorie cible choisie : bouton « Déplacer » désactivé (impossible de
  confirmer un état invalide). `categoryId` est donc toujours non-nil à l'appel.

## Tests / vérification

Pas de target XCTest dans le projet. Vérification par :

```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'generic/platform=iOS Simulator' build
```

Vérifications manuelles dans le simulateur :
- Bouton « Sélectionner » absent pour un viewer (lecture seule).
- Sélection/désélection multi-lignes, compteur correct.
- Déplacement vers catégorie seule ⇒ items à la racine (sous-catégorie effacée).
- Déplacement vers sous-catégorie ⇒ items regroupés sous la sous-catégorie.
- Liste regroupée à jour après déplacement, sortie du mode sélection.

## Contraintes respectées

- **Backend partagé** : aucune migration, écriture additive sur colonnes existantes.
- **Design System** : couleurs via `SGDFColors` uniquement, pas de hex en vue.
- **Layering MVVM** : la vue n'appelle que le VM ; le VM appelle `ItemService`.
- **Nouveau fichier** : si `MoveItemsSheet` est dans un fichier `.swift` séparé, il
  doit être ajouté au target `ScoutInventory` dans Xcode (classic groups). Pour
  éviter cette étape, on peut placer `MoveItemsSheet` dans `MaterialListView.swift`.
- **Copie FR** partout.
