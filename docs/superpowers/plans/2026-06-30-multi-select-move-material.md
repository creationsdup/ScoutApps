# Sélection multiple + déplacement de matériel — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre de sélectionner plusieurs matériels dans la liste Matériel et de les déplacer en une action vers une catégorie ou une sous-catégorie cible.

**Architecture:** MVVM strict (Views → ViewModel → ItemService → SupabaseClient). Un déplacement en masse = une seule requête PostgREST `update(...).in("id", values:)` calquée sur `markChecked`. La vue gère un mode sélection local (`Set<String>`) et une sheet de cible ; le ViewModel orchestre l'appel service + le rechargement.

**Tech Stack:** SwiftUI, ScoutKit (Swift package local), supabase-swift (PostgREST).

## Global Constraints

- **App :** ScoutMatériel uniquement — scheme `ScoutInventory`, target `ScoutInventory`.
- **Backend partagé** : additif seulement. Aucune migration. On écrit uniquement les colonnes existantes `category_id` / `subcategory_id` de `inventory_items`.
- **Design System** : couleurs via `SGDFColors` / `SGDFTheme` uniquement. Aucun hex, `Color.blue`, `.white` ni `Color(red:…)` dans une vue.
- **Layering** : une vue n'appelle jamais le réseau ; elle ne parle qu'au ViewModel. Le ViewModel ne parle qu'aux Services. `SupabaseService.shared.client` est le seul client.
- **Symboles ScoutKit** consommés par l'app doivent être `public` (méthode `move` comprise).
- **Write-gating** : tout point d'entrée d'écriture gated `if session.canWrite`.
- **Copie FR** partout.
- **Pas de XCTest** : vérification par `xcodebuild ... -scheme ScoutInventory build` + run manuel simulateur. Le « test » de chaque tâche est une compilation verte (et, en fin de plan, des vérifs manuelles).
- **Nouveaux fichiers app** : un `.swift` créé sous `ScoutMateriel/` doit être ajouté au target Xcode (classic groups). Pour l'éviter, `MoveItemsSheet` est placé **dans** `MaterialListView.swift` (pas de nouveau fichier). Les fichiers sous `ScoutKit/Sources/ScoutKit/` sont folder-based (aucune action Xcode).

Commande de build de référence (utilisée à chaque étape « vérifier la compilation ») :

```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'generic/platform=iOS Simulator' build
```

---

### Task 1: `ItemService.move` — déplacement en masse (ScoutKit)

**Files:**
- Modify: `ScoutKit/Sources/ScoutKit/Services/ItemService.swift` (ajouter une méthode après `markChecked`, ~ligne 103, et un payload privé)

**Interfaces:**
- Consumes : `client` (propriété existante de `ItemService`), pattern `markChecked`.
- Produces : `public func move(itemIds: [String], categoryId: String, subcategoryId: String?) async throws` — utilisé par `MaterialListViewModel.move` (Task 2).

- [ ] **Step 1: Ajouter la méthode `move` et le payload privé**

Dans `ItemService.swift`, juste après la méthode `markChecked` (après la ligne 103 `}`), ajouter :

```swift
    /// Déplace une liste d'objets vers une catégorie (et éventuellement une
    /// sous-catégorie) en une seule requête. No-op si la liste est vide.
    /// `subcategoryId == nil` efface explicitement la sous-catégorie (null en DB).
    public func move(itemIds: [String], categoryId: String, subcategoryId: String?) async throws {
        guard !itemIds.isEmpty else { return }
        try await client.from("inventory_items")
            .update(MovePayload(categoryId: categoryId, subcategoryId: subcategoryId))
            .`in`("id", values: itemIds)
            .execute()
    }
```

- [ ] **Step 2: Ajouter le payload privé avec encodage explicite de `null`**

Toujours dans `ItemService.swift`, ajouter ce type privé (au même niveau que les autres payloads privés du fichier, ou juste avant la fermeture `}` finale du `struct ItemService`). L'`encode` manuel est **obligatoire** : l'`Encodable` synthétisé omettrait la clé quand `nil`, ce qui ne mettrait pas la colonne à `null` (PostgREST ne toucherait pas la colonne).

```swift
private struct MovePayload: Encodable {
    let categoryId: String
    let subcategoryId: String?

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case subcategoryId = "subcategory_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(categoryId, forKey: .categoryId)
        // `encode` (et non `encodeIfPresent`) écrit `null` quand nil → efface la sous-catégorie.
        try c.encode(subcategoryId, forKey: .subcategoryId)
    }
}
```

Note : si `LastCheckedPayload` est déjà un type privé au niveau fichier (hors du `struct`), placer `MovePayload` au même endroit pour rester cohérent.

- [ ] **Step 3: Vérifier la compilation**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'generic/platform=iOS Simulator' build
```
Expected : `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ScoutKit/Sources/ScoutKit/Services/ItemService.swift
git commit -m "feat(service): ItemService.move — bulk move items to category/subcategory"
```

---

### Task 2: `MaterialListViewModel.move` (ViewModel)

**Files:**
- Modify: `ScoutMateriel/ViewModels/MaterialListViewModel.swift` (ajouter une méthode ; `service`, `categories`, `subcategories`, `load()` existent déjà)

**Interfaces:**
- Consumes : `ItemService.move(itemIds:categoryId:subcategoryId:)` (Task 1) ; `self.service` (existant) ; `self.load()` (existant).
- Produces : `func move(itemIds: Set<String>, categoryId: String, subcategoryId: String?) async -> String?` — retourne `nil` au succès, un message d'erreur FR sinon. Consommé par `MaterialListView` (Task 3).

- [ ] **Step 1: Ajouter la méthode `move`**

Dans `MaterialListViewModel.swift`, ajouter cette méthode (par ex. juste après `load()`). Elle ne touche **pas** `errorMessage` (qui pilote l'écran d'erreur plein écran) : elle retourne le message pour une alerte locale.

```swift
    /// Déplace les items sélectionnés vers la catégorie (et sous-catégorie) cible.
    /// Retourne nil au succès, sinon un message d'erreur à afficher.
    func move(itemIds: Set<String>, categoryId: String, subcategoryId: String?) async -> String? {
        guard !itemIds.isEmpty else { return nil }
        do {
            try await service.move(itemIds: Array(itemIds),
                                   categoryId: categoryId,
                                   subcategoryId: subcategoryId)
            await load()
            return nil
        } catch {
            return "Le déplacement a échoué : \(error.localizedDescription)"
        }
    }
```

- [ ] **Step 2: Vérifier la compilation**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'generic/platform=iOS Simulator' build
```
Expected : `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ScoutMateriel/ViewModels/MaterialListViewModel.swift
git commit -m "feat(material): MaterialListViewModel.move — orchestrate bulk move + reload"
```

---

### Task 3: Mode sélection + `MoveItemsSheet` dans `MaterialListView`

**Files:**
- Modify: `ScoutMateriel/Views/Material/MaterialListView.swift` (état + toolbar + liste + sheet + alerte ; `MoveItemsSheet` ajouté dans le même fichier — pas de nouveau fichier à enregistrer dans Xcode)

**Interfaces:**
- Consumes : `viewModel.move(itemIds:categoryId:subcategoryId:)` (Task 2) ; `viewModel.categories: [ItemCategory]`, `viewModel.subcategories: [Subcategory]`, `viewModel.groups` (existants) ; `session.canWrite`.
- Produces : aucune API consommée par d'autres tâches (feuille de l'arbre).

- [ ] **Step 1: Ajouter l'état du mode sélection**

Dans `struct MaterialListView`, sous les `@State` existants (après la ligne `@State private var showCategoryManager = false`), ajouter :

```swift
    @State private var isSelecting = false
    @State private var selectedIds: Set<String> = []
    @State private var showMoveSheet = false
    @State private var moveErrorMessage: String?
```

- [ ] **Step 2: Ajouter les boutons de toolbar du mode sélection**

Dans le `.toolbar { ... }` de `body`, après le `ToolbarItem` du filtre (le bloc `.topBarTrailing` existant, lignes 30-36), ajouter — gated `canWrite` — un bouton d'entrée hors mode et les actions en mode :

```swift
                    if session.canWrite {
                        ToolbarItem(placement: .topBarTrailing) {
                            if isSelecting {
                                Button("Annuler") {
                                    isSelecting = false
                                    selectedIds = []
                                }
                            } else {
                                Button("Sélectionner") { isSelecting = true }
                            }
                        }
                        if isSelecting {
                            ToolbarItem(placement: .bottomBar) {
                                Button {
                                    showMoveSheet = true
                                } label: {
                                    Text("Déplacer (\(selectedIds.count))")
                                }
                                .disabled(selectedIds.isEmpty)
                            }
                        }
                    }
```

- [ ] **Step 3: Présenter la sheet de cible et l'alerte d'erreur**

Toujours dans `body`, après le `.sheet(isPresented: $showCategoryManager, ...)` existant (ligne 44-48), ajouter :

```swift
                .sheet(isPresented: $showMoveSheet) {
                    MoveItemsSheet(
                        count: selectedIds.count,
                        categories: viewModel.categories,
                        subcategories: viewModel.subcategories
                    ) { categoryId, subcategoryId in
                        let ids = selectedIds
                        Task {
                            let error = await viewModel.move(itemIds: ids,
                                                             categoryId: categoryId,
                                                             subcategoryId: subcategoryId)
                            if let error {
                                moveErrorMessage = error
                            } else {
                                isSelecting = false
                                selectedIds = []
                            }
                        }
                    }
                }
                .alert("Erreur", isPresented: Binding(
                    get: { moveErrorMessage != nil },
                    set: { if !$0 { moveErrorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { moveErrorMessage = nil }
                } message: {
                    Text(moveErrorMessage ?? "")
                }
```

- [ ] **Step 4: Rendre les lignes sélectionnables en mode sélection**

Dans `content`, remplacer le `NavigationLink(value: item) { MaterialRow(item: item) }` (lignes 78-83) par un rendu conditionnel : en mode sélection, une ligne tap-toggle avec coche ; sinon le `NavigationLink` actuel. Remplacer le bloc :

```swift
                                ForEach(sub.items) { item in
                                    NavigationLink(value: item) { MaterialRow(item: item) }
                                        .listRowInsets(EdgeInsets(
                                            top: SGDFTheme.Spacing.xs,
                                            leading: SGDFTheme.Spacing.sm,
                                            bottom: SGDFTheme.Spacing.xs,
                                            trailing: SGDFTheme.Spacing.md))
                                }
```

par :

```swift
                                ForEach(sub.items) { item in
                                    Group {
                                        if isSelecting {
                                            HStack(spacing: SGDFTheme.Spacing.md) {
                                                Image(systemName: selectedIds.contains(item.id)
                                                      ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedIds.contains(item.id)
                                                                     ? SGDFColors.primaryBlue
                                                                     : SGDFColors.textSecondary)
                                                MaterialRow(item: item)
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if selectedIds.contains(item.id) {
                                                    selectedIds.remove(item.id)
                                                } else {
                                                    selectedIds.insert(item.id)
                                                }
                                            }
                                        } else {
                                            NavigationLink(value: item) { MaterialRow(item: item) }
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(
                                        top: SGDFTheme.Spacing.xs,
                                        leading: SGDFTheme.Spacing.sm,
                                        bottom: SGDFTheme.Spacing.xs,
                                        trailing: SGDFTheme.Spacing.md))
                                }
```

- [ ] **Step 5: Ajouter la sous-vue `MoveItemsSheet` dans le même fichier**

À la fin de `MaterialListView.swift` (après le `private struct MaterialRow { ... }`, hors de tout autre type), ajouter :

```swift
/// Sheet de choix de la cible d'un déplacement multiple : catégorie (obligatoire)
/// + sous-catégorie optionnelle. Catégorie seule ⇒ sous-catégorie effacée.
private struct MoveItemsSheet: View {
    let count: Int
    let categories: [ItemCategory]
    let subcategories: [Subcategory]
    let onConfirm: (_ categoryId: String, _ subcategoryId: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategoryId: String?
    @State private var selectedSubcategoryId: String?

    private var availableSubcategories: [Subcategory] {
        guard let categoryId = selectedCategoryId else { return [] }
        return subcategories.filter { $0.categoryId == categoryId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(count) matériel(s) sélectionné(s)")
                        .foregroundStyle(SGDFColors.textSecondary)
                }
                Section("Catégorie cible") {
                    Picker("Catégorie", selection: $selectedCategoryId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(String?.some(category.id))
                        }
                    }
                    .onChange(of: selectedCategoryId) { _, _ in
                        selectedSubcategoryId = nil
                    }
                }
                if !availableSubcategories.isEmpty {
                    Section("Sous-catégorie (optionnel)") {
                        Picker("Sous-catégorie", selection: $selectedSubcategoryId) {
                            Text("Aucune").tag(String?.none)
                            ForEach(availableSubcategories) { sub in
                                Text(sub.name).tag(String?.some(sub.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Déplacer")
            .navigationBarTitleDisplayMode(.inline)
            .background(SGDFColors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Déplacer") {
                        guard let categoryId = selectedCategoryId else { return }
                        onConfirm(categoryId, selectedSubcategoryId)
                        dismiss()
                    }
                    .disabled(selectedCategoryId == nil)
                }
            }
        }
    }
}
```

- [ ] **Step 6: Vérifier la compilation**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory \
  -destination 'generic/platform=iOS Simulator' build
```
Expected : `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Vérifications manuelles dans le simulateur**

Lancer ScoutMatériel (scheme `ScoutInventory`) et confirmer :
1. Connecté en rôle écriture : le bouton « Sélectionner » apparaît dans la liste Matériel.
2. « Sélectionner » → coches sur les lignes, tap sur plusieurs items → compteur « Déplacer (N) » correct ; les lignes ne naviguent plus vers la fiche.
3. « Déplacer (N) » → sheet ; Picker catégorie + (si la catégorie a des sous-catégories) Picker sous-catégorie ; « Déplacer » désactivé tant qu'aucune catégorie.
4. Déplacement vers **catégorie seule** → items rangés à la racine de la catégorie (ancienne sous-catégorie effacée), liste regroupée à jour, sortie du mode sélection.
5. Déplacement vers **sous-catégorie** → items regroupés sous la sous-catégorie.
6. En rôle lecture seule (viewer) : aucun bouton « Sélectionner ».

(Note CLAUDE.md : la caméra ne marche pas au simulateur ; non pertinent ici, aucune fonctionnalité scan touchée.)

- [ ] **Step 8: Commit**

```bash
git add ScoutMateriel/Views/Material/MaterialListView.swift
git commit -m "feat(material): multi-select rows + move sheet to category/subcategory"
```

---

## Self-Review

**Spec coverage :**
- Service bulk update → Task 1. ✓
- VM `move` + reload + erreur non destructive → Task 2. ✓
- Mode sélection (bouton, toggle, coche) → Task 3 (steps 1, 2, 4). ✓
- Barre d'action « Annuler » / « Déplacer (N) » → Task 3 (step 2). ✓
- `MoveItemsSheet` (picker catégorie + sous-catégorie « Aucune ») → Task 3 (steps 3, 5). ✓
- Sémantique « catégorie seule efface la sous-catégorie » → encodage `null` explicite (Task 1, step 2) + `selectedSubcategoryId = nil` au changement de catégorie. ✓
- Gating `canWrite` → Task 3 (step 2, blocs `if session.canWrite`). ✓
- Erreurs remontées (pas de `try?` silencieux) → Task 2 (catch) + alerte locale Task 3 (step 3). ✓
- Backend additif, aucune migration → Task 1 n'écrit que des colonnes existantes. ✓

**Placeholders :** aucun TODO/TBD ; tout le code est fourni.

**Cohérence des types :** `move(itemIds: Set<String>, categoryId: String, subcategoryId: String?) async -> String?` (VM) appelle `ItemService.move(itemIds: [String], categoryId: String, subcategoryId: String?) async throws` — signatures alignées (conversion `Array(itemIds)`). `MoveItemsSheet.onConfirm: (String, String?) -> Void` correspond à l'appel `viewModel.move`. `ItemCategory.id`, `ItemCategory.name`, `Subcategory.id`, `Subcategory.categoryId`, `Subcategory.name`, `Item.id` confirmés via l'exploration du modèle.
