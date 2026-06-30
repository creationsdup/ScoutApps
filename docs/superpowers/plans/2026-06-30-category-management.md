# Gestion des catégories & sous-catégories — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un écran « Organisation du matériel » (bouton dans la barre Matériel) pour créer/renommer/supprimer catégories et sous-catégories, avec verrouillage du code catégorie dès qu'un item existe.

**Architecture:** Nouveau `CategoryService` (ScoutKit) pour les écritures catégories/sous-catégories + comptage d'items ; nouveaux `CategoryManagerViewModel` et `CategoryManagerView` (app) ; bouton + sheet câblés dans `MaterialListView`. Aucune migration (tables et FK existent déjà ; suppression gérée par les FK `on delete cascade`/`set null`).

**Tech Stack:** SwiftUI, Swift Package (ScoutKit), supabase-swift (PostgREST), Supabase Postgres + RLS.

## Global Constraints

- **Aucune migration SQL.** Les tables `categories` (avec `code`), `subcategories`, les FK et contraintes (`categories_code_format_chk`, index unique `categories_code_key`) existent déjà.
- **Backend partagé avec CampManager** — ne jamais modifier le schéma existant.
- **Pas de cible XCTest.** « Vérifier » = `xcodebuild build` des DEUX schémas sans erreur :
  ```bash
  xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
  xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
  ```
  SourceKit montre des erreurs périmées ; seul `xcodebuild` fait foi.
- **Symboles ScoutKit utilisés par l'app en `public`** (struct, méthodes, init).
- **Couleurs uniquement via `SGDFColors` / `StatusColorMapper`** ; aucun hex ni `Color(...)` en vue.
- **Erreurs des écritures remontées à l'UI** (pas de `try?` silencieux sur create/update/delete).
- **UI en français.**
- **Nouveau fichier `.swift` sous `ScoutMateriel/`** → doit être ajouté à la cible `ScoutInventory` dans `project.pbxproj` (via la gem Ruby `xcodeproj`). Les fichiers sous `ScoutKit/Sources/ScoutKit/` sont auto-inclus (dossier) — pas d'édition pbxproj.
- **Format/validation du code catégorie** : `^[A-Z]{2,4}$`, unique (déjà imposé en base ; l'UI valide en amont et affiche les erreurs base).

---

### Task 1: `CategoryService` (ScoutKit — écritures + comptage)

**Files:**
- Create: `ScoutKit/Sources/ScoutKit/Services/CategoryService.swift`

**Interfaces:**
- Consumes : `ItemCategory` (champs `id`, `name`, `code`), `Subcategory` (`id`, `categoryId`, `name`), `SupabaseService.shared.client`.
- Produces (consommé par Task 2) :
  - `CategoryService.createCategory(name: String, code: String) async throws -> ItemCategory`
  - `CategoryService.updateCategory(id: String, name: String, code: String?) async throws`
  - `CategoryService.deleteCategory(id: String) async throws`
  - `CategoryService.createSubcategory(categoryId: String, name: String) async throws -> Subcategory`
  - `CategoryService.updateSubcategory(id: String, name: String) async throws`
  - `CategoryService.deleteSubcategory(id: String) async throws`
  - `CategoryService.itemCount(categoryId: String) async throws -> Int`

- [ ] **Step 1: Créer le fichier `CategoryService.swift`**

Créer `ScoutKit/Sources/ScoutKit/Services/CategoryService.swift` avec ce contenu exact :

```swift
import Foundation
import Supabase

/// Écritures sur les référentiels de classement (categories / subcategories)
/// + comptage d'items. Les lectures vivent dans `ItemService`
/// (`listCategories` / `listSubcategories`).
public struct CategoryService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Payloads

    private struct CategoryInsert: Encodable { let name: String; let code: String }
    private struct CategoryNameCode: Encodable { let name: String; let code: String }
    private struct NameOnly: Encodable { let name: String }
    private struct SubcategoryInsert: Encodable { let category_id: String; let name: String }

    // MARK: - Catégories

    @discardableResult
    public func createCategory(name: String, code: String) async throws -> ItemCategory {
        try await client.from("categories")
            .insert(CategoryInsert(name: name, code: code))
            .select().single().execute().value
    }

    /// Met à jour le nom toujours ; le code seulement s'il est fourni (non verrouillé).
    public func updateCategory(id: String, name: String, code: String?) async throws {
        if let code {
            try await client.from("categories")
                .update(CategoryNameCode(name: name, code: code))
                .eq("id", value: id).execute()
        } else {
            try await client.from("categories")
                .update(NameOnly(name: name))
                .eq("id", value: id).execute()
        }
    }

    public func deleteCategory(id: String) async throws {
        try await client.from("categories").delete().eq("id", value: id).execute()
    }

    // MARK: - Sous-catégories

    @discardableResult
    public func createSubcategory(categoryId: String, name: String) async throws -> Subcategory {
        try await client.from("subcategories")
            .insert(SubcategoryInsert(category_id: categoryId, name: name))
            .select().single().execute().value
    }

    public func updateSubcategory(id: String, name: String) async throws {
        try await client.from("subcategories")
            .update(NameOnly(name: name))
            .eq("id", value: id).execute()
    }

    public func deleteSubcategory(id: String) async throws {
        try await client.from("subcategories").delete().eq("id", value: id).execute()
    }

    // MARK: - Comptage (règle de verrouillage du code)

    /// Nombre d'items rattachés à une catégorie (sert à verrouiller le code).
    public func itemCount(categoryId: String) async throws -> Int {
        let response = try await client.from("inventory_items")
            .select("id", head: true, count: .exact)
            .eq("category_id", value: categoryId)
            .execute()
        return response.count ?? 0
    }
}
```

- [ ] **Step 2: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED** pour les deux. (Si `CountOption` n'est pas trouvé, c'est qu'il faut `import PostgREST` en plus — mais `import Supabase` ré-exporte `PostgREST` ; `.exact` est `CountOption.exact`.)

- [ ] **Step 3: Commit**

```bash
git add ScoutKit/Sources/ScoutKit/Services/CategoryService.swift
git commit -m "feat(service): CategoryService — category/subcategory CRUD + itemCount"
```

---

### Task 2: `CategoryManagerViewModel` (app)

**Files:**
- Create: `ScoutMateriel/ViewModels/CategoryManagerViewModel.swift`
- Modify: `ScoutInventory.xcodeproj/project.pbxproj` (ajout du fichier à la cible `ScoutInventory`)

**Interfaces:**
- Consumes : `CategoryService` (Task 1), `ItemService().listCategories()` / `listSubcategories()`, `ItemCategory`, `Subcategory`.
- Produces (consommé par Task 3) :
  - `@Published var categories: [ItemCategory]`, `allSubcategories: [Subcategory]`, `itemCounts: [String: Int]`, `isLoading: Bool`, `errorMessage: String?`
  - `func load() async`
  - `func subcategories(of categoryId: String) -> [Subcategory]`
  - `func canEditCode(_ categoryId: String) -> Bool`
  - `func createCategory(name: String, code: String) async -> Bool`
  - `func renameCategory(id: String, name: String, code: String?) async -> Bool`
  - `func deleteCategory(id: String) async`
  - `func createSubcategory(categoryId: String, name: String) async -> Bool`
  - `func renameSubcategory(id: String, name: String) async -> Bool`
  - `func deleteSubcategory(id: String) async`

- [ ] **Step 1: Créer le fichier `CategoryManagerViewModel.swift`**

Créer `ScoutMateriel/ViewModels/CategoryManagerViewModel.swift` avec ce contenu exact :

```swift
import Foundation
import ScoutKit

@MainActor
final class CategoryManagerViewModel: ObservableObject {
    @Published var categories: [ItemCategory] = []
    @Published var allSubcategories: [Subcategory] = []
    @Published var itemCounts: [String: Int] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let itemService = ItemService()
    private let service = CategoryService()

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let cats = try await itemService.listCategories()
            let subs = try await itemService.listSubcategories()
            var counts: [String: Int] = [:]
            for cat in cats {
                counts[cat.id] = (try? await service.itemCount(categoryId: cat.id)) ?? 0
            }
            categories = cats
            allSubcategories = subs
            itemCounts = counts
        } catch {
            errorMessage = "Impossible de charger les catégories."
        }
        isLoading = false
    }

    func subcategories(of categoryId: String) -> [Subcategory] {
        allSubcategories.filter { $0.categoryId == categoryId }
    }

    /// Le code est modifiable tant qu'aucun item n'utilise la catégorie.
    func canEditCode(_ categoryId: String) -> Bool {
        (itemCounts[categoryId] ?? 0) == 0
    }

    // MARK: - Actions catégorie

    func createCategory(name: String, code: String) async -> Bool {
        do {
            _ = try await service.createCategory(name: name, code: code)
            await load()
            return true
        } catch {
            errorMessage = "Création impossible. Code peut-être déjà utilisé."
            return false
        }
    }

    func renameCategory(id: String, name: String, code: String?) async -> Bool {
        do {
            try await service.updateCategory(id: id, name: name, code: code)
            await load()
            return true
        } catch {
            errorMessage = "Modification impossible. Code peut-être déjà utilisé."
            return false
        }
    }

    func deleteCategory(id: String) async {
        do {
            try await service.deleteCategory(id: id)
            await load()
        } catch {
            errorMessage = "Suppression impossible. Réessaie."
        }
    }

    // MARK: - Actions sous-catégorie

    func createSubcategory(categoryId: String, name: String) async -> Bool {
        do {
            _ = try await service.createSubcategory(categoryId: categoryId, name: name)
            await load()
            return true
        } catch {
            errorMessage = "Création de la sous-catégorie impossible."
            return false
        }
    }

    func renameSubcategory(id: String, name: String) async -> Bool {
        do {
            try await service.updateSubcategory(id: id, name: name)
            await load()
            return true
        } catch {
            errorMessage = "Modification de la sous-catégorie impossible."
            return false
        }
    }

    func deleteSubcategory(id: String) async {
        do {
            try await service.deleteSubcategory(id: id)
            await load()
        } catch {
            errorMessage = "Suppression de la sous-catégorie impossible."
        }
    }
}
```

- [ ] **Step 2: Ajouter le fichier à la cible `ScoutInventory` (gem `xcodeproj`)**

Le projet utilise des groupes classiques : un nouveau fichier doit être référencé ET inscrit dans la build phase Sources de la cible `ScoutInventory`. L'ajouter à côté de son fichier voisin `MaterialListViewModel.swift` (même groupe, même cible). Exécuter :

```bash
cd /Users/maeldupin/Desktop/ScoutInventory-iOS
ruby -e '
require "xcodeproj"
proj = Xcodeproj::Project.open("ScoutInventory.xcodeproj")
target = proj.targets.find { |t| t.name == "ScoutInventory" }
sibling = proj.files.find { |f| f.display_name == "MaterialListViewModel.swift" }
group = sibling.parent
base = "CategoryManagerViewModel.swift"
unless group.files.any? { |f| f.display_name == base }
  ref = group.new_reference(base)
  target.add_file_references([ref])
  proj.save
  puts "added: #{base}"
else
  puts "already present: #{base}"
end
'
```

- [ ] **Step 3: Vérifier l'appartenance à la cible**

Run :
```bash
grep -c "CategoryManagerViewModel.swift in Sources" ScoutInventory.xcodeproj/project.pbxproj
```
Expected : `1` (le fichier figure dans la build phase Sources). Si `0`, l'ajout a échoué — relancer Step 2 (vérifier que `group.new_reference(base)` a bien produit un chemin relatif `CategoryManagerViewModel.swift`).

- [ ] **Step 4: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED** pour les deux.

- [ ] **Step 5: Commit**

```bash
git add ScoutMateriel/ViewModels/CategoryManagerViewModel.swift ScoutInventory.xcodeproj/project.pbxproj
git commit -m "feat(material): CategoryManagerViewModel"
```

---

### Task 3: `CategoryManagerView` + `CategoryEditView` (app)

**Files:**
- Create: `ScoutMateriel/Views/Material/CategoryManagerView.swift`
- Modify: `ScoutInventory.xcodeproj/project.pbxproj` (ajout à la cible `ScoutInventory`)

**Interfaces:**
- Consumes : `CategoryManagerViewModel` (Task 2) et toutes ses méthodes/propriétés ; `SGDFColors`, `SGDFTheme`, `LoadingView`, `EmptyStateView`.
- Produces (consommé par Task 4) : `struct CategoryManagerView: View` avec `init()` (crée son `@StateObject`).

- [ ] **Step 1: Créer le fichier `CategoryManagerView.swift`**

Créer `ScoutMateriel/Views/Material/CategoryManagerView.swift` avec ce contenu exact :

```swift
import SwiftUI
import ScoutKit

struct CategoryManagerView: View {
    @StateObject private var viewModel = CategoryManagerViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var editingCategory: ItemCategory?      // sheet renommer/coder
    @State private var creatingCategory = false
    @State private var addingSubTo: ItemCategory?          // alerte nouvelle sous-cat
    @State private var renamingSub: Subcategory?           // alerte renommer sous-cat
    @State private var subNameField = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Organisation")
                .navigationBarTitleDisplayMode(.inline)
                .background(SGDFColors.background)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { creatingCategory = true } label: { Image(systemName: "plus") }
                    }
                }
                .task { await viewModel.load() }
                .sheet(isPresented: $creatingCategory) {
                    CategoryEditView(viewModel: viewModel, category: nil)
                }
                .sheet(item: $editingCategory) { cat in
                    CategoryEditView(viewModel: viewModel, category: cat)
                }
                // Nouvelle sous-catégorie
                .alert("Nouvelle sous-catégorie",
                       isPresented: Binding(get: { addingSubTo != nil },
                                            set: { if !$0 { addingSubTo = nil } })) {
                    TextField("Nom", text: $subNameField)
                    Button("Annuler", role: .cancel) { subNameField = ""; addingSubTo = nil }
                    Button("Ajouter") {
                        if let cat = addingSubTo {
                            let name = subNameField
                            subNameField = ""; addingSubTo = nil
                            Task { _ = await viewModel.createSubcategory(categoryId: cat.id, name: name) }
                        }
                    }
                }
                // Renommer sous-catégorie
                .alert("Renommer la sous-catégorie",
                       isPresented: Binding(get: { renamingSub != nil },
                                            set: { if !$0 { renamingSub = nil } })) {
                    TextField("Nom", text: $subNameField)
                    Button("Annuler", role: .cancel) { subNameField = ""; renamingSub = nil }
                    Button("Enregistrer") {
                        if let sub = renamingSub {
                            let name = subNameField
                            subNameField = ""; renamingSub = nil
                            Task { _ = await viewModel.renameSubcategory(id: sub.id, name: name) }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.categories.isEmpty {
            LoadingView()
        } else if viewModel.categories.isEmpty {
            EmptyStateView(systemImage: "folder",
                           title: "Aucune catégorie",
                           message: "Crée ta première catégorie avec le bouton +.")
        } else {
            List {
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(SGDFColors.red) }
                }
                ForEach(viewModel.categories) { cat in
                    Section {
                        ForEach(viewModel.subcategories(of: cat.id)) { sub in
                            Text(sub.name)
                                .foregroundStyle(SGDFColors.textPrimary)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteSubcategory(id: sub.id) }
                                    } label: { Label("Supprimer", systemImage: "trash") }
                                    Button {
                                        subNameField = sub.name; renamingSub = sub
                                    } label: { Label("Renommer", systemImage: "pencil") }
                                }
                        }
                        Button {
                            subNameField = ""; addingSubTo = cat
                        } label: {
                            Label("Sous-catégorie", systemImage: "plus.circle")
                                .foregroundStyle(SGDFColors.primaryBlue)
                        }
                    } header: {
                        HStack {
                            Text(cat.name).foregroundStyle(SGDFColors.primaryBlue)
                            if let code = cat.code {
                                Text(code).foregroundStyle(SGDFColors.textSecondary)
                            }
                            Spacer()
                            Menu {
                                Button { editingCategory = cat } label: {
                                    Label("Renommer", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteCategory(id: cat.id) }
                                } label: { Label("Supprimer", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(SGDFColors.primaryBlue)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

/// Création / renommage d'une catégorie (nom + code). Code verrouillé si la
/// catégorie a déjà des items (édition seulement).
private struct CategoryEditView: View {
    @ObservedObject var viewModel: CategoryManagerViewModel
    let category: ItemCategory?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var code = ""
    @State private var saving = false

    private var isEditing: Bool { category != nil }
    private var codeLocked: Bool {
        guard let category else { return false }
        return !viewModel.canEditCode(category.id)
    }
    private var codeValid: Bool {
        code.range(of: "^[A-Z]{2,4}$", options: .regularExpression) != nil
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (codeLocked || codeValid) && !saving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Catégorie") {
                    TextField("Nom", text: $name)
                    if codeLocked {
                        LabeledContent("Code", value: code)
                        Text("Code verrouillé : des objets utilisent cette catégorie.")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    } else {
                        TextField("Code (2-4 lettres, ex. TEN)", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(SGDFColors.red) }
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouvelle catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    code = category.code ?? ""
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let ok: Bool
        if let category {
            // En édition : n'envoie le code que s'il est déverrouillé.
            ok = await viewModel.renameCategory(id: category.id, name: name,
                                                code: codeLocked ? nil : code)
        } else {
            ok = await viewModel.createCategory(name: name, code: code)
        }
        if ok { dismiss() }
    }
}
```

- [ ] **Step 2: Ajouter le fichier à la cible `ScoutInventory`**

À côté de son voisin `MaterialListView.swift`. Exécuter :

```bash
cd /Users/maeldupin/Desktop/ScoutInventory-iOS
ruby -e '
require "xcodeproj"
proj = Xcodeproj::Project.open("ScoutInventory.xcodeproj")
target = proj.targets.find { |t| t.name == "ScoutInventory" }
sibling = proj.files.find { |f| f.display_name == "MaterialListView.swift" }
group = sibling.parent
base = "CategoryManagerView.swift"
unless group.files.any? { |f| f.display_name == base }
  ref = group.new_reference(base)
  target.add_file_references([ref])
  proj.save
  puts "added: #{base}"
else
  puts "already present: #{base}"
end
'
```

- [ ] **Step 3: Vérifier l'appartenance à la cible**

Run :
```bash
grep -c "CategoryManagerView.swift in Sources" ScoutInventory.xcodeproj/project.pbxproj
```
Expected : `1`.

- [ ] **Step 4: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED** pour les deux.

- [ ] **Step 5: Commit**

```bash
git add ScoutMateriel/Views/Material/CategoryManagerView.swift ScoutInventory.xcodeproj/project.pbxproj
git commit -m "feat(material): CategoryManagerView (organisation screen)"
```

---

### Task 4: Câblage dans `MaterialListView` (bouton + sheet + reload)

**Files:**
- Modify: `ScoutMateriel/Views/Material/MaterialListView.swift`

**Interfaces:**
- Consumes : `CategoryManagerView` (Task 3), `SessionStore.canWrite` (déjà `public`).

- [ ] **Step 1: Ajouter l'accès au `SessionStore` et l'état de présentation**

Dans `ScoutMateriel/Views/Material/MaterialListView.swift`, remplacer le bloc de propriétés en tête de `struct MaterialListView` :

```swift
struct MaterialListView: View {
    @StateObject private var viewModel = MaterialListViewModel()
    @EnvironmentObject private var session: SessionStore
    @State private var showFilters = false
    @State private var showAddForm = false
    @State private var showCategoryManager = false
```

- [ ] **Step 2: Ajouter le bouton (gardé par `canWrite`) dans la toolbar**

Toujours dans `MaterialListView`, remplacer le `ToolbarItem(placement: .topBarLeading)` existant (le bouton `+`) par ces deux items, de sorte que le bouton d'organisation n'apparaisse que pour les rôles en écriture :

```swift
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showAddForm = true } label: { Image(systemName: "plus") }
                    }
                    if session.canWrite {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showCategoryManager = true } label: {
                                Image(systemName: "folder.badge.gearshape")
                            }
                            .accessibilityLabel("Organiser le matériel")
                        }
                    }
```

- [ ] **Step 3: Présenter la feuille et recharger à la fermeture**

Toujours dans `MaterialListView`, ajouter une `.sheet` juste après la `.sheet(isPresented: $showFilters) { … }` existante :

```swift
                .sheet(isPresented: $showCategoryManager, onDismiss: {
                    Task { await viewModel.loadReferentials(); await viewModel.load() }
                }) {
                    CategoryManagerView()
                }
```

- [ ] **Step 4: Vérifier le build (les deux schémas)**

Run :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutCamp -destination 'generic/platform=iOS Simulator' build
```
Expected : **BUILD SUCCEEDED** pour les deux. (Si « Cannot find SessionStore in scope » : `SessionStore` est dans ScoutKit, déjà importé en tête du fichier via `import ScoutKit` — vérifier que l'import est présent.)

- [ ] **Step 5: Vérification manuelle**

Lancer ScoutMatériel (compte en écriture). Le bouton dossier apparaît dans la liste Matériel → ouvre « Organisation ». Créer une catégorie (`SAC` / « Sacs »), une sous-catégorie, renommer, supprimer (avertissement). Créer un item dans `SAC` → rouvrir l'organisation → le code de `SAC` est verrouillé en édition. Avec un compte **viewer**, le bouton n'apparaît pas.

- [ ] **Step 6: Commit**

```bash
git add ScoutMateriel/Views/Material/MaterialListView.swift
git commit -m "feat(material): organiser button opens CategoryManager (gated on canWrite)"
```

---

## Notes de vérification finale

- Build des **deux** schémas après chaque task.
- Scénario bout-en-bout : créer/renommer/supprimer catégorie & sous-catégorie ; verrouillage du code après création d'un item ; bouton masqué pour un viewer ; doublon de code refusé avec message.

## Hors périmètre

- Glisser-déposer / réordonnancement manuel.
- Déplacement en masse d'items entre catégories ; fusion de catégories.
- Gestion des localisations.
