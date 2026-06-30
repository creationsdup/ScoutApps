# Refonte UX du formulaire d'ajout/édition de matériel — Design

**Date :** 2026-06-30
**App :** ScoutMatériel (target `ScoutInventory`)
**Module :** Matériel — `MaterialFormView` / `MaterialFormViewModel`

## Objectif

Alléger le formulaire d'ajout/édition de matériel par **divulgation progressive** :
n'afficher que l'essentiel par défaut, replier le reste sous « Plus d'options », et
soigner la présentation (aperçu photo, marqueurs « Requis », tokens du design system).

Un chef doit pouvoir ajouter un matériel avec **Nom + Photo + Catégorie + Statut**
puis Enregistrer, sans jamais ouvrir « Plus d'options » — les défauts intelligents
existants (Statut « Disponible », État « Bon », Unité « Pièce », etc.) couvrent le reste.

## Périmètre

- **App ScoutMatériel uniquement** (scheme `ScoutInventory`). Cette vue n'existe pas
  dans ScoutCamp.
- Refonte **de présentation** de `MaterialFormView` + deux ajouts **lecture seule** au
  `MaterialFormViewModel` (aperçu photo, état d'expansion).
- **Aucune** modification de `save()`, du modèle `Item`, des services, des enums, ou du
  backend. Aucune migration. La validation reste **Nom + Catégorie requis**.

Hors périmètre : nouveaux champs, wizard multi-étapes, changement des défauts, refonte
des autres formulaires de l'app.

## Composants

### 1. `MaterialFormViewModel` — deux ajouts lecture seule

`/ScoutMateriel/ViewModels/MaterialFormViewModel.swift`

Aucun changement de `save()` ni des `@Published` éditables. On ajoute :

a) **Aperçu de la photo existante (édition).** Le chemin de l'image existante est
aujourd'hui stocké en privé (`existingImagePath`). L'exposer en lecture pour l'aperçu :

```swift
/// URL publique de l'image déjà enregistrée (édition), pour l'aperçu. nil si aucune.
var existingImageURL: URL? {
    guard let path = existingImagePath else { return nil }
    return try? ImageStorageService().publicURL(for: path)
}
```

(Si `existingImagePath` est `private`, le passer à `private(set)` ou ajouter ce
computed dans la même classe — il a accès au membre privé.)

b) **État initial de « Plus d'options ».** Vrai si on édite **et** qu'au moins un champ
avancé n'est pas à sa valeur par défaut, pour ne rien cacher de renseigné :

```swift
/// Faut-il déplier « Plus d'options » à l'ouverture ? (édition avec champ avancé renseigné)
var shouldExpandAdvanced: Bool {
    guard isEditing else { return false }
    return !itemDescription.isEmpty
        || locationId != nil
        || branch != nil
        || condition != .good
        || (trackingType == .global && (minimumThreshold > 0 || unit != .piece))
        || !notes.isEmpty
}
```

Note : `condition`, `branch`, `locationId`, `unit`, `minimumThreshold`, `notes`,
`itemDescription`, `trackingType`, `isEditing` existent déjà sur le VM (confirmé).

### 2. `MaterialFormView` — disposition par divulgation progressive

`/ScoutMateriel/Views/Material/MaterialFormView.swift`

État ajouté :
- `@State private var showAdvanced = false` (initialisé via `.onAppear`/`.task` à
  `viewModel.shouldExpandAdvanced`).

**Section « L'essentiel »** (toujours visible, dans cet ordre) :

1. **Photo** — `PhotosPicker(selection: $photoItem, matching: .images)` dont le label est
   une ligne avec **vignette d'aperçu** + texte :
   - vignette = `pickedImageData` (image fraîchement choisie, via `Image(uiImage:)`) sinon
     `viewModel.existingImageURL` (AsyncImage) sinon placeholder `Image(systemName: "photo")`
     sur fond `SGDFColors.border` ;
   - cadre 56×56, `RoundedRectangle(cornerRadius: SGDFTheme.Radius.card)`, `scaledToFill` + clip ;
   - texte : « Ajouter une photo » si aucune image, « Changer la photo » sinon, en `body`.
2. **Nom** *(requis)* — `TextField("Nom", text: $viewModel.name)` ; sous/à côté, un marqueur
   « Requis » (`Text("Requis").font(.caption).foregroundStyle(SGDFColors.textSecondary)`),
   par ex. via `LabeledContent` ou un `HStack` discret. Pas de rouge.
3. **Catégorie** *(requis)* — `Picker` inchangé (premier tag « Choisir… »), même marqueur « Requis ».
4. **Sous-catégorie** — inchangé : `if !viewModel.filteredSubcategories.isEmpty`.
5. **Code inventaire** — inchangé : `if viewModel.isEditing` → `LabeledContent` lecture seule.
6. **Type de suivi** — `Picker` inchangé ; **Quantité** `Stepper` seulement si
   `viewModel.trackingType == .global` (inchangé).
7. **Statut** — `Picker("Statut", …)` sur `ItemStatus.allCases` (déplacé ici depuis « Suivi »).

**`DisclosureGroup("Plus d'options", isExpanded: $showAdvanced)`** (replié à l'ajout) :

- **Description** — `TextField(axis: .vertical)` (déplacé d'« Identité »).
- **Localisation** — `Picker` inchangé.
- **Branche** — `Picker` inchangé.
- **État** — `Picker("État", …)` sur `ItemCondition.allCases` (déplacé depuis « Suivi »).
- **Unité** — `Picker`, seulement si `trackingType == .global` (inchangé).
- **Seuil minimum** — `Stepper`, seulement si `trackingType == .global` (inchangé,
  label « Seuil minimum : aucun » quand 0).
- **Notes** — `TextField(axis: .vertical)` inchangé.

**Section erreur** — inchangée (`if let error = viewModel.errorMessage`).

**Toolbar** — inchangée : `Annuler` (`.cancellationAction`), `Enregistrer`
(`.confirmationAction`, `.disabled(!viewModel.canSave)`), titre `viewModel.title`.

**Wiring existant conservé** : `.task { loadReferentials() }`, `.onChange(trackingType)` →
quantité 1 en `.specifique`, `.onChange(categoryId)` → `subcategoryId = nil`,
`.onChange(photoItem)` → charge `pickedImageData`. **Ajout** : initialiser `showAdvanced`
depuis `viewModel.shouldExpandAdvanced` à l'apparition (après `loadReferentials` n'est pas
nécessaire — les champs avancés viennent de l'item, déjà chargés à l'init en édition).

## Flux de données

Inchangé. La vue lit/écrit les mêmes `@Published`, `canSave` garde Nom+Catégorie,
`save()` génère le code inventaire (RPC) et crée/maj l'item exactement comme avant. La
divulgation progressive n'affecte que **l'affichage** : tous les champs avancés restent
liés à leurs bindings même repliés (le `DisclosureGroup` ne les démonte pas du modèle,
seulement de l'affichage ; leurs valeurs/défauts partent au save quoi qu'il arrive).

## Gestion d'erreurs

Inchangée : `errorMessage` du VM affiché dans la section erreur en `SGDFColors.red` ;
bouton Enregistrer désactivé tant que `canSave` est faux.

## Design / charte

- Couleurs via `SGDFColors` / `SGDFTheme` uniquement ; aucun hex, `Color.blue`, `.white`.
- **Rouge réservé à l'erreur** : les marqueurs « Requis » sont en `textSecondary`, jamais rouges.
- Vignette photo : `Radius.card`, placeholder cohérent avec `MaterialRow`.

## Tests / vérification

Pas de target XCTest. Vérification :

```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'generic/platform=iOS Simulator' build
```

QA manuelle (simulateur) :
- **Ajout rapide** : Nom + Photo (aperçu s'affiche) + Catégorie + Statut → Enregistrer,
  sans ouvrir « Plus d'options ». L'item est créé avec les défauts (État Bon, etc.).
- « Plus d'options » **replié** à l'ouverture en ajout ; les champs avancés y sont présents.
- **Édition** d'un item ayant une localisation/notes/état≠Bon → « Plus d'options »
  **auto-déplié** ; l'aperçu montre la photo existante.
- Édition d'un item « nu » (aucun champ avancé) → « Plus d'options » **replié**.
- Quantité visible seulement en suivi Global ; Unité/Seuil dans l'avancé seulement en Global.

## Contraintes respectées

- **Backend partagé** : aucune écriture/migration nouvelle ; `save()` intact.
- **Layering MVVM** : la vue ne parle qu'au VM ; le VM ne parle qu'aux services
  (`ImageStorageService` déjà utilisé pour l'upload).
- **Pas de nouveau fichier** : tout dans `MaterialFormView.swift` (vue) et
  `MaterialFormViewModel.swift` (VM) existants → aucune étape Xcode (classic groups).
- **Copie FR** partout.
