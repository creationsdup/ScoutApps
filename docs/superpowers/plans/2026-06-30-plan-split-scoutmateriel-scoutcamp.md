# Plan — Scission ScoutManager → ScoutMatériel + ScoutCamp (package ScoutKit)

> **Exécution :** plan **collaboratif et linéaire**, PAS subagent-driven. Il mêle des tâches
> « fichiers » (préparées par l'assistant) et des tâches **Xcode GUI** (réalisées par l'utilisateur),
> avec une boucle build→fix unique. À exécuter en mode `executing-plans` (checkpoints), pas en
> parallèle. Cases `- [ ]` pour le suivi.

**Goal :** transformer l'app unique en deux apps (ScoutMatériel + ScoutCamp) partageant un Swift
Package local `ScoutKit`, **sans aucune régression fonctionnelle**.

**Architecture :** `ScoutKit` (Models, Services, Stores, DesignSystem, Components, Config, Login) ;
deux app targets légers qui `import ScoutKit` et n'embarquent que leurs Views/ViewModels + leur shell.

**Spec :** `docs/superpowers/specs/2026-06-30-split-scoutmateriel-scoutcamp-design.md`.

## Global Constraints
- iOS 17+, SwiftUI, MVVM strict : `Views → ViewModels/Stores → Services → SupabaseService.shared.client`.
- Tout symbole de `ScoutKit` utilisé par une app doit être **`public`** (le défaut `internal` ne franchit pas le module).
- **Zéro régression** : ScoutMatériel = Dashboard/Matériel/Scan ; ScoutCamp = Intendance/Programme — comportements identiques à aujourd'hui.
- **Backend partagé inchangé** : aucune migration ici. Charte couleur : Design System reste l'unique source de couleur.
- **ScoutMatériel conserve `com.scout.manager`** (continuité des installs) ; **ScoutCamp = `com.scout.camp`**.
- L'assistant **ne modifie pas `project.pbxproj`** : toutes les opérations projet (package, target, dépendances, Info.plist, schemes) se font **dans Xcode par l'utilisateur**, étapes fournies.
- Vérification : `xcodebuild build` du scheme concerné (pas de XCTest) + lancement des apps.
- Déplacements de fichiers via **`git mv`** (préserver l'historique).

## Conventions de marquage
- **[ASSISTANT/FICHIERS]** : je le fais via les outils fichiers/git, versionné.
- **[UTILISATEUR/XCODE]** : tu le fais dans Xcode en suivant les clics ; rien à coder.
- **[VÉRIF]** : commande de build / smoke test.

---

## Task 1 — [ASSISTANT/FICHIERS] Squelette du package ScoutKit + déplacement du commun « pur »
**But :** créer `ScoutKit/Package.swift` et y déplacer le code partagé sans dépendance d'app (Models, DesignSystem, Components, Config, Auth), avec `git mv`.

- Créer `ScoutKit/Package.swift` :
  ```swift
  // swift-tools-version:5.9
  import PackageDescription

  let package = Package(
      name: "ScoutKit",
      platforms: [.iOS(.v17)],
      products: [.library(name: "ScoutKit", targets: ["ScoutKit"])],
      dependencies: [
          .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
      ],
      targets: [
          .target(
              name: "ScoutKit",
              dependencies: [.product(name: "Supabase", package: "supabase-swift")]
          )
      ]
  )
  ```
  > La version `from:` doit correspondre à celle déjà résolue dans le projet (relever la version exacte dans `ScoutInventory.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` et l'aligner).
- `git mv` vers `ScoutKit/Sources/ScoutKit/` :
  - `ScoutManager/Models/` → `ScoutKit/Sources/ScoutKit/Models/`
  - `ScoutManager/DesignSystem/` → `…/DesignSystem/`
  - `ScoutManager/Components/` → `…/Components/`
  - `ScoutManager/App/Config.swift` → `…/Config/Config.swift`
  - `ScoutManager/App/AppInfo.swift` → `…/Config/AppInfo.swift`
  - `ScoutManager/Views/Auth/LoginView.swift` → `…/Auth/LoginView.swift`
- Extraire l'extension `String: @retroactive Identifiable` de `ScoutManager/Views/Scan/QRScannerView.swift` vers un nouveau `ScoutKit/Sources/ScoutKit/Shared/StringIdentifiable.swift` (la rendre `public` n'est pas requis pour une conformance, mais le `var id` doit rester accessible — laisser tel quel, c'est une conformance de protocole publique via le type String public).
- **[VÉRIF]** structurelle (le projet ne build pas encore) : `swift package dump-package --package-path ScoutKit` doit réussir (Package.swift valide). Commit `chore(split): scaffold ScoutKit package + move shared models/design/components`.

---

## Task 2 — [ASSISTANT/FICHIERS] Déplacer Services + Stores dans ScoutKit
**But :** finir le contenu partagé.

- `git mv` :
  - `ScoutManager/Services/` → `ScoutKit/Sources/ScoutKit/Services/`
  - `ScoutManager/Stores/` → `ScoutKit/Sources/ScoutKit/Stores/`
- `import Supabase` reste valide (le package dépend de supabase-swift).
- Commit `chore(split): move Services + Stores into ScoutKit`.

---

## Task 3 — [ASSISTANT/FICHIERS] Balayage `public` de ScoutKit
**But :** exposer la surface nécessaire aux apps. Appliquer ces règles à TOUT fichier de `ScoutKit/Sources/ScoutKit/` :

- `struct X` / `enum X` / `final class X` consommés par les apps → `public struct/enum/final class X`.
- Pour chaque type partagé, ajouter un **`public init(...)`** explicite reprenant ses propriétés stockées (sinon non instanciable hors module). Ex. pour les modèles `Codable`, ajouter `public init(...)` mémberwise.
- Propriétés utilisées hors module → `public var` / `public let` (les `@Published var` aussi : `@Published public var`).
- Méthodes appelées par les apps → `public func`.
- Singletons / points d'accès : `public static let shared`, `public var client`, etc.
- Enums avec `rawValue`/`label`/`CaseIterable` utilisés en UI → `public` (cases inclus implicitement, mais le type et `var label`/`init?(rawValue:)` doivent être publics).
- Composants SwiftUI (`SGDFButton`, `SGDFCard`, …) : `public struct` + `public init` + `public var body`.
- Tokens couleur/thème : `public enum SGDFColors { public static let primaryBlue … }` etc.

> Méthode : ce balayage sera **complété pilote-par-erreurs** aux Tasks 6/7 (le compilateur liste les
> « inaccessible due to 'internal' protection level »). Ici on fait la passe systématique de base.

- **[VÉRIF]** structurelle : `git grep -n "^struct \|^enum \|^final class " ScoutKit/Sources` ne doit plus lister de type partagé sans `public` (revue visuelle). Commit `chore(split): make ScoutKit API public`.

---

## Task 4 — [ASSISTANT/FICHIERS] Réorganiser ScoutMatériel + adapter son shell
**But :** l'app existante ne garde que Dashboard/Matériel/Scan et `import ScoutKit`.

- Créer le dossier `ScoutMateriel/` et `git mv` dedans :
  - `ScoutManager/App/ScoutManagerApp.swift` → `ScoutMateriel/App/ScoutMaterielApp.swift`
  - `ScoutManager/App/RootView.swift` → `ScoutMateriel/App/RootView.swift`
  - `ScoutManager/App/MainTabView.swift` → `ScoutMateriel/App/MainTabView.swift`
  - `ScoutManager/App/AppRouter.swift` → `ScoutMateriel/App/AppRouter.swift`
  - `ScoutManager/App/Info.plist` → `ScoutMateriel/App/Info.plist`
  - `ScoutManager/Views/Dashboard/`, `Material/`, `Scan/` → `ScoutMateriel/Views/…`
  - `ScoutManager/ViewModels/DashboardViewModel.swift`, `MaterialListViewModel.swift`, `MaterialFormViewModel.swift`, `ScannerViewModel.swift` → `ScoutMateriel/ViewModels/…`
- Éditer `ScoutMaterielApp.swift` : renommer `struct ScoutManagerApp` → `struct ScoutMaterielApp`, ajouter `import ScoutKit`. Injecter `SessionStore`/`AppRouter` comme aujourd'hui (CampStore PAS nécessaire ici en Projet 1).
- Éditer `AppRouter.swift` : `enum Tab { case dashboard, material, scan }` (retirer `intendance`, `camp`).
- Éditer `MainTabView.swift` : ne garder que les 3 onglets Dashboard/Matériel/Scan (retirer les `ComingSoonView`/Intendance/Camp). `import ScoutKit`.
- Ajouter `import ScoutKit` en tête de chaque fichier de `ScoutMateriel/Views` et `ScoutMateriel/ViewModels` qui référence un type partagé (Item, SGDF*, services, stores…).
- Supprimer `ScoutManager/Views/Placeholder/ComingSoonView.swift` s'il n'est plus référencé.
- Commit `chore(split): carve ScoutMateriel app (3 onglets) on ScoutKit`.

---

## Task 5 — [ASSISTANT/FICHIERS] Créer l'app ScoutCamp + son shell
**But :** nouvelle app camp à 2 onglets sur `ScoutKit`.

- Créer `ScoutCamp/` et `git mv` :
  - `ScoutManager/Views/Intendance/` → `ScoutCamp/Views/Intendance/`
  - `ScoutManager/Views/Program/` → `ScoutCamp/Views/Program/`
  - Les ViewModels camp : `MealPlanViewModel`, `RecipeListViewModel`, `RecipeDetailViewModel`, `RecipeFormViewModel`, `ShoppingListViewModel`, `BudgetViewModel`, `FoodStockViewModel`, `FoodTraceViewModel`, `ActivityLibraryViewModel`, `ProgramPlanViewModel` (+ tout VM Camp form/info) → `ScoutCamp/ViewModels/…`
- Créer `ScoutCamp/App/ScoutCampApp.swift` :
  ```swift
  import SwiftUI
  import ScoutKit

  @main
  struct ScoutCampApp: App {
      @StateObject private var session = SessionStore()
      @StateObject private var campStore = CampStore()
      var body: some Scene {
          WindowGroup {
              RootView()
                  .environmentObject(session)
                  .environmentObject(campStore)
                  .tint(SGDFColors.primaryBlue)
                  .task { await session.restore() }
          }
      }
  }
  ```
- Créer `ScoutCamp/App/RootView.swift` (login ↔ shell camp) :
  ```swift
  import SwiftUI
  import ScoutKit

  struct RootView: View {
      @EnvironmentObject private var session: SessionStore
      var body: some View {
          Group {
              if session.isAuthenticated { CampTabView() } else { LoginView() }
          }
      }
  }
  ```
- Créer `ScoutCamp/App/CampTabView.swift` (2 onglets) :
  ```swift
  import SwiftUI
  import ScoutKit

  struct CampTabView: View {
      init() {
          let tint = UIColor(SGDFColors.primaryBlue)
          UITabBar.appearance().tintColor = tint
          UINavigationBar.appearance().tintColor = tint
      }
      var body: some View {
          TabView {
              IntendanceHomeView()
                  .tabItem { Label("Intendance", systemImage: "fork.knife") }
              ProgramHomeView()
                  .tabItem { Label("Programme", systemImage: "tent") }
          }
          .tint(SGDFColors.primaryBlue)
      }
  }
  ```
- Créer `ScoutCamp/App/Info.plist` (copie de celui de ScoutMatériel : clés standard + `SupabaseAnonKey = $(SUPABASE_ANON_KEY)`).
- Ajouter `import ScoutKit` en tête des fichiers de `ScoutCamp/Views` et `ScoutCamp/ViewModels` qui référencent un type partagé.
- Vérifier qu'aucun fichier ScoutCamp ne redéclare `String: Identifiable` (la conformance vit dans ScoutKit).
- Commit `chore(split): create ScoutCamp app (Intendance/Programme) on ScoutKit`.

---

## Task 6 — [UTILISATEUR/XCODE] Câbler le projet (package, targets, dépendances, Info.plist, schemes)
**But :** rendre le projet buildable. Suivre dans Xcode (projet ouvert) :

- [ ] **Ajouter le package local** : File ▸ Add Package Dependencies… ▸ « Add Local… » ▸ choisir le dossier `ScoutKit/` ▸ Add.
- [ ] **App ScoutMatériel (target existant)** :
  - Onglet *General* du target existant : renommer le **Display Name** en « ScoutMatériel » ; laisser le **Bundle Identifier** `com.scout.manager`.
  - *Build Phases* ▸ *Link Binary With Libraries* (ou *General ▸ Frameworks, Libraries…*) ▸ + ▸ **ScoutKit**.
  - *Build Settings* : vérifier `INFOPLIST_FILE = ScoutMateriel/App/Info.plist` et que la **base configuration** (Debug/Release) reste `Secrets.xcconfig`.
  - S'assurer que le **dossier source synchronisé** du target pointe sur `ScoutMateriel/` (retirer l'ancien groupe `ScoutManager/` s'il subsiste ; ajouter `ScoutMateriel/` comme racine synchronisée).
- [ ] **Nouveau target ScoutCamp** : File ▸ New ▸ Target… ▸ iOS ▸ **App** ▸ Product Name « ScoutCamp », interface SwiftUI, langage Swift, **décocher** les tests.
  - Supprimer les fichiers générés par défaut (`ScoutCampApp.swift`/`ContentView.swift` du template) puisqu'on a déjà les nôtres dans `ScoutCamp/App/`.
  - Définir le **dossier source synchronisé** du target sur `ScoutCamp/`.
  - *General* : Bundle Identifier `com.scout.camp`, Display Name « ScoutCamp », iOS Deployment Target 17.
  - *Frameworks, Libraries…* ▸ + ▸ **ScoutKit**.
  - *Build Settings* : `INFOPLIST_FILE = ScoutCamp/App/Info.plist` ; **base configuration** Debug/Release = `Secrets.xcconfig` (pour `$(SUPABASE_ANON_KEY)`).
- [ ] **Schemes** : renommer le scheme `ScoutInventory` → `ScoutMateriel` (ou en créer un) ; un scheme `ScoutCamp` est créé automatiquement avec le target.
- [ ] **[VÉRIF]** : Product ▸ Build (⌘B) sur **ScoutMatériel**. Ça peut échouer sur des erreurs `inaccessible due to 'internal' protection level` → c'est la Task 7.

---

## Task 7 — [ASSISTANT/FICHIERS + VÉRIF] Boucle build→fix `public` et imports (ScoutMatériel puis ScoutCamp)
**But :** rendre les deux apps vertes.

- **[VÉRIF]** build ScoutMatériel :
  ```bash
  xcodebuild -project ScoutInventory.xcodeproj -scheme ScoutMateriel \
    -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
  ```
- Pour chaque erreur :
  - `… inaccessible due to 'internal' protection level` → ajouter `public` au symbole concerné dans `ScoutKit`.
  - `cannot find 'X' in scope` sur un type partagé → ajouter `import ScoutKit` au fichier.
  - `'X' initializer is inaccessible` → ajouter un `public init` au type dans ScoutKit.
  Réitérer jusqu'à `** BUILD SUCCEEDED **`.
- Répéter à l'identique pour **ScoutCamp** (scheme `ScoutCamp`).
- Commit (un ou plusieurs) `fix(split): public surface + imports to build both apps`.

---

## Task 8 — [UTILISATEUR + VÉRIF] Smoke test des deux apps
**But :** parité fonctionnelle, zéro régression.

- [ ] Lancer **ScoutMatériel** au simulateur : login → Dashboard/Matériel (liste, filtre, fiche, ajout/édit) / Scan (saisie manuelle `TAG-000001`). Comportement identique à avant.
- [ ] Lancer **ScoutCamp** au simulateur : login → Intendance (camp picker, Menus/Recettes/Courses/Budget/Stock/Registre) / Programme (Infos/Planning/Activités). Comportement identique.
- [ ] Vérifier qu'aucune des deux n'affiche « clé Supabase manquante » (secrets bien câblés sur les 2 targets).
- Mettre à jour `CLAUDE.md` (architecture : 1 package + 2 apps) et `Secrets.example.xcconfig` si besoin. Commit `docs(split): update CLAUDE.md for ScoutKit + two apps`.

---

## Notes d'exécution
- L'ordre 1→8 est **strict** : les Tasks 1–5 préparent les fichiers (le projet ne builde pas encore),
  la Task 6 (Xcode, utilisateur) débloque le build, les Tasks 7–8 stabilisent.
- Entre la Task 5 et la Task 6, le repo est volontairement « non buildable » par `xcodebuild` tant que
  le projet Xcode n'est pas recâblé — c'est normal.
- Si le balayage `public` devient lourd, le faire fichier par fichier guidé par la sortie d'erreurs
  (Task 7), c'est plus rapide que de tout deviner d'avance.
