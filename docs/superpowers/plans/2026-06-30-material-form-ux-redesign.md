# Refonte UX formulaire matériel — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Alléger le formulaire d'ajout/édition de matériel par divulgation progressive (essentiel visible, reste sous « Plus d'options ») + aperçu photo + marqueurs « Requis ».

**Architecture:** Refonte de présentation de `MaterialFormView` + 2 computed lecture seule sur `MaterialFormViewModel`. Aucune touche à `save()`, au modèle, aux services, au backend.

**Tech Stack:** SwiftUI (`Form`, `DisclosureGroup`, `PhotosPicker`, `AsyncImage`), ScoutKit.

## Global Constraints

- App **ScoutMatériel** seulement (scheme `ScoutInventory`). Vérif = `xcodebuild build` (pas de XCTest).
- Couleurs via `SGDFColors`/`SGDFTheme` uniquement ; aucun hex/`Color.blue`/`.white`. **Rouge réservé à l'erreur** → marqueurs « Requis » en `textSecondary`.
- Validation inchangée : Nom + Catégorie requis. `save()` intact.
- Fichiers existants seulement (aucune étape Xcode). Copie FR.

Build de référence :
```bash
xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutInventory -destination 'generic/platform=iOS Simulator' build
```

---

### Task 1: `MaterialFormViewModel` — 2 computed lecture seule

**Files:**
- Modify: `ScoutMateriel/ViewModels/MaterialFormViewModel.swift`

**Interfaces:**
- Produces : `var existingImageURL: URL?` et `var shouldExpandAdvanced: Bool` — consommés par la vue (Task 2).

- [ ] **Step 1: Ajouter les deux computed** (après `filteredSubcategories`, avant `loadReferentials`)

```swift
    /// URL publique de l'image déjà enregistrée (édition), pour l'aperçu. nil si aucune.
    var existingImageURL: URL? {
        guard let existingImagePath else { return nil }
        return try? ImageStorageService().publicURL(for: existingImagePath)
    }

    /// Déplier « Plus d'options » à l'ouverture ? (édition avec au moins un champ avancé renseigné)
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

- [ ] **Step 2: Build** (commande de référence) → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**
```bash
git add ScoutMateriel/ViewModels/MaterialFormViewModel.swift
git commit -m "feat(material): VM exposes existingImageURL + shouldExpandAdvanced for form redesign"
```

---

### Task 2: `MaterialFormView` — divulgation progressive + aperçu photo

**Files:**
- Modify: `ScoutMateriel/Views/Material/MaterialFormView.swift`

**Interfaces:**
- Consumes : `viewModel.existingImageURL`, `viewModel.shouldExpandAdvanced` (Task 1) ; tous les `@Published` existants.

- [ ] **Step 1: Ajouter `import UIKit`** (sous les imports existants, pour `UIImage(data:)`)

```swift
import UIKit
```

- [ ] **Step 2: Ajouter l'état d'expansion** (sous `@State private var photoItem`)

```swift
    @State private var showAdvanced = false
```

- [ ] **Step 3: Remplacer tout le bloc `Form { … }`** (lignes 18-79 actuelles, des `Form {` au `}` fermant juste avant `.navigationTitle`) par :

```swift
            Form {
                Section("L'essentiel") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: SGDFTheme.Spacing.md) {
                            photoThumbnail
                            Text(hasPhoto ? "Changer la photo" : "Ajouter une photo")
                        }
                    }
                    HStack {
                        TextField("Nom", text: $viewModel.name)
                        Text("Requis")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                    Picker(selection: $viewModel.categoryId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(viewModel.categories) { Text($0.name).tag(String?.some($0.id)) }
                    } label: {
                        HStack {
                            Text("Catégorie")
                            Text("Requis")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                    }
                    if !viewModel.filteredSubcategories.isEmpty {
                        Picker("Sous-catégorie", selection: $viewModel.subcategoryId) {
                            Text("Aucune").tag(String?.none)
                            ForEach(viewModel.filteredSubcategories) { Text($0.name).tag(String?.some($0.id)) }
                        }
                    }
                    if viewModel.isEditing {
                        LabeledContent("Code inventaire", value: viewModel.inventoryCode)
                    }
                    Picker("Type de suivi", selection: $viewModel.trackingType) {
                        ForEach(TrackingType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    if viewModel.trackingType == .global {
                        Stepper("Quantité : \(viewModel.quantity)", value: $viewModel.quantity, in: 1...9999)
                    }
                    Picker("Statut", selection: $viewModel.status) {
                        ForEach(ItemStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                Section {
                    DisclosureGroup("Plus d'options", isExpanded: $showAdvanced) {
                        TextField("Description", text: $viewModel.itemDescription, axis: .vertical)
                        Picker("Localisation", selection: $viewModel.locationId) {
                            Text("Aucune").tag(String?.none)
                            ForEach(viewModel.locations) { Text($0.name).tag(String?.some($0.id)) }
                        }
                        Picker("Branche", selection: $viewModel.branch) {
                            Text("Aucune").tag(Branch?.none)
                            ForEach(Branch.allCases, id: \.self) { Text($0.label).tag(Branch?.some($0)) }
                        }
                        Picker("État", selection: $viewModel.condition) {
                            ForEach(ItemCondition.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        if viewModel.trackingType == .global {
                            Picker("Unité", selection: $viewModel.unit) {
                                ForEach(ItemUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                            Stepper(viewModel.minimumThreshold == 0
                                    ? "Seuil minimum : aucun"
                                    : "Seuil minimum : \(viewModel.minimumThreshold)",
                                    value: $viewModel.minimumThreshold, in: 0...9999)
                        }
                        TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    }
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(SGDFColors.red) }
                }
            }
```

- [ ] **Step 4: Initialiser `showAdvanced` dans le `.task`** — remplacer le `.task` existant par :

```swift
            .task {
                showAdvanced = viewModel.shouldExpandAdvanced
                await viewModel.loadReferentials()
            }
```

- [ ] **Step 5: Ajouter les vues d'aperçu photo** — à la fin du `struct MaterialFormView`, après le `var body` (avant le `}` final du struct) :

```swift
    private var hasPhoto: Bool {
        viewModel.pickedImageData != nil || viewModel.existingImageURL != nil
    }

    @ViewBuilder
    private var photoThumbnail: some View {
        Group {
            if let data = viewModel.pickedImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if let url = viewModel.existingImageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholderPhoto
                    }
                }
            } else {
                placeholderPhoto
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
    }

    private var placeholderPhoto: some View {
        Rectangle().fill(SGDFColors.border)
            .overlay(Image(systemName: "photo").foregroundStyle(SGDFColors.textSecondary))
    }
```

- [ ] **Step 6: Build** (commande de référence) → `** BUILD SUCCEEDED **`.

- [ ] **Step 7: QA manuelle simulateur** — ajout rapide (Nom+Photo+Catégorie+Statut → Enregistrer, sans ouvrir l'avancé) ; aperçu photo visible ; « Plus d'options » replié en ajout, auto-déplié en édition d'un item avec localisation/notes/état≠Bon ; Quantité/Unité/Seuil seulement en suivi Global.

- [ ] **Step 8: Commit**
```bash
git add ScoutMateriel/Views/Material/MaterialFormView.swift
git commit -m "feat(material): add/edit form — progressive disclosure + photo preview + required markers"
```

---

## Self-Review

- Spec §1 (existingImageURL, shouldExpandAdvanced) → Task 1. ✓
- Spec §2 (Photo preview, Nom/Catégorie requis markers, Statut in essentials, DisclosureGroup advanced, État/Unité/Seuil/Notes/Loc/Branche/Description in advanced) → Task 2. ✓
- Spec « auto-déplié en édition » → `shouldExpandAdvanced` + `.task` init. ✓
- Rouge réservé erreur → « Requis » en `textSecondary`. ✓
- save() intact → Task 2 ne touche pas la toolbar/save. ✓
- Types : `existingImageURL: URL?`, `shouldExpandAdvanced: Bool` cohérents entre VM (Task 1) et vue (Task 2). `pickedImageData: Data?`, `existingImagePath` privé accessible au computed. ✓
- Pas de placeholder. ✓
