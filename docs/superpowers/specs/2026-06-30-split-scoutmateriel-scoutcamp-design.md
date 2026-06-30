# ScoutManager → ScoutMatériel + ScoutCamp : scission en deux apps (design)

**Date :** 2026‑06‑30
**Périmètre :** Projet 1 — **scission packaging** : extraire un package partagé `ScoutKit`,
transformer l'app existante en **ScoutMatériel** (Dashboard + Matériel + Scan) et créer une
2ᵉ app **ScoutCamp** (Intendance + Programme), sans changer aucun comportement.
**Hors périmètre (Projet 2, spec séparé) :** flux matériel partagé camp↔inventaire (liste de
chargement, statut `indisponible`, mouvements, rattachement activité).

---

## 1. Contexte et décision

ScoutManager est aujourd'hui **une** app iOS native (5 onglets) sur backend Supabase partagé
avec CampManager (web). L'utilisateur veut une expérience **camp mobile‑first** dédiée (CampManager
web ne lui convient pas) et une app matériel focalisée. Décision validée :

- **Deux apps, une seule base de code** via un **Swift Package local `ScoutKit`** + **deux app
  targets** dans le même projet Xcode (approche A).
- L'app actuelle **devient ScoutMatériel** (on en retire les onglets Intendance/Camp) ; **ScoutCamp**
  est une 2ᵉ app neuve qui héberge le module camp existant.
- **Source de vérité camp = les tables `camps`/… de ScoutManager** (ScoutCamp remplace CampManager
  pour ce groupe). Contrainte backend partagé inchangée : **additif uniquement**, on ne casse pas
  CampManager.
- **Aucune régression fonctionnelle** : à la fin, chaque app fait exactement ce que faisait son
  module dans l'app unique.

---

## 2. Architecture cible

```
ScoutKit/                      ← Swift Package local (le commun)
  Package.swift
  Sources/ScoutKit/
    Models/        (17) Enums, Item, ItemCategory, ItemLocation, QRCode, MovementHistory,
                        Camp, Meal, Recipe, ShoppingItem, Expense, FoodStock, FoodTraceEntry,
                        Activity, ProgramSlot, Formatting, DateFormatters
    Services/      (14) SupabaseService, ItemService, ImageStorageService, QRCodeService,
                        CampService, MealService, RecipeService, ShoppingService, ExpenseService,
                        FoodStockService, FoodTraceService, ActivityService, ProgramService
    Stores/        (2)  SessionStore, CampStore
    DesignSystem/  (4)  SGDFColors, SGDFTheme, StatusColorMapper, Color+Hex
    Components/    (6)  SGDFButton, SGDFCard, SGDFBadge, SGDFTextField, EmptyStateView, LoadingView
    Config/             Config, AppInfo
    Auth/               LoginView
    Shared/             String+Identifiable (@retroactive, déplacé depuis Scan)

ScoutMateriel/                 ← app target #1 (ex-ScoutManager)
  App/        ScoutMaterielApp (@main), RootView, MainTabView (3 onglets), AppRouter, Info.plist
  Views/      Dashboard/, Material/, Scan/
  ViewModels/ DashboardViewModel, MaterialListViewModel, MaterialFormViewModel, ScannerViewModel

ScoutCamp/                     ← app target #2 (nouveau)
  App/        ScoutCampApp (@main), RootView, CampTabView (2 onglets), Info.plist
  Views/      Intendance/, Program/
  ViewModels/ MealPlanViewModel, RecipeListViewModel, RecipeDetailViewModel, RecipeFormViewModel,
              ShoppingListViewModel, BudgetViewModel, FoodStockViewModel, FoodTraceViewModel,
              ActivityLibraryViewModel, ProgramPlanViewModel (+ Camp form/info VMs s'il y en a)
```

Les deux apps `import ScoutKit`. **Couche inchangée** : `Views → ViewModels/Stores → Services →
SupabaseService.shared.client`.

---

## 3. Répartition shared vs spécifique

**ScoutKit (partagé)** : tous les `Models`, tous les `Services` (un seul `SupabaseService.shared`
reste l'unique client), `Stores` (`SessionStore`, `CampStore`), tout le `DesignSystem`, tous les
`Components`, `Config`/`AppInfo`, et `LoginView` (identique sur les 2 apps). L'extension
`String: @retroactive Identifiable` (aujourd'hui dans `QRScannerView.swift`) est **déplacée dans
ScoutKit** (définie une seule fois, disponible aux deux apps).

**Spécifique à chaque app** : `@main`, `RootView`, le shell d'onglets, et les Views/ViewModels métier.

**Shells :**
- **ScoutMatériel** : `MainTabView` à **3 onglets** (Dashboard, Matériel, Scan). `AppRouter.Tab`
  réduit à `dashboard/material/scan`.
- **ScoutCamp** : `CampTabView` à **2 onglets** (Intendance → `IntendanceHomeView`, Programme →
  `ProgramHomeView`). Le sélecteur de camp est déjà embarqué dans ces deux vues (via `CampStore`),
  donc **zéro changement de comportement**. (Un onglet « Camps » dédié pourra être ajouté plus tard.)

---

## 4. Accès `public` (conséquence de l'approche A)

Tout symbole de `ScoutKit` consommé par une app doit être `public` (le défaut `internal` ne franchit
pas un module). Balayage systématique requis sur le code partagé :
- `struct`/`enum`/`class`/`final class` partagés → `public`.
- Leurs propriétés stockées/calculées utilisées hors module → `public` (les `@Published` aussi).
- Les `init` appelés par les apps → `public init(...)` explicites (un type sans `init` public n'est
  pas instanciable hors module).
- Les méthodes appelées par les apps → `public`.
- `SupabaseService.shared`, `SessionStore`, `CampStore`, les services, `SGDFColors`/`SGDFTheme`/
  composants, `Config` → `public`.

C'est mécanique mais transverse. Un build de chaque app révèle les manques (« X is inaccessible due
to 'internal' protection level ») → on complète jusqu'au vert.

---

## 5. Configuration, secrets, nommage

- **Package** : `Package.swift` déclare une cible `ScoutKit` (platforms iOS 17+), dépendance SPM
  **supabase‑swift**. Les apps dépendent de `ScoutKit` (qui ré‑exporte / expose ce qu'il faut) ;
  la dépendance supabase‑swift est portée par le package.
- **Secrets** : un seul `Secrets.xcconfig` (clé anon, hors git) sert de **base config** aux deux
  targets (Debug/Release). Chaque `Info.plist` (un par app) porte `SupabaseAnonKey =
  $(SUPABASE_ANON_KEY)`. `Config` lit `Bundle.main` au runtime → résout le bundle de l'app courante,
  OK pour les deux.
- **Bundle ids / noms** :
  - ScoutMatériel : **conserve** `com.scout.manager` (continuité des installs existantes), nom
    d'affichage « ScoutMatériel ».
  - ScoutCamp : nouveau `com.scout.camp`, nom « ScoutCamp ».
- **Schemes** : un scheme par app (`ScoutMateriel`, `ScoutCamp`). Le scheme historique `ScoutInventory`
  est renommé/retiré au profit de `ScoutMateriel` (le produit reste `ScoutInventory.app` tant qu'on ne
  renomme pas le target produit — voir Risques).

---

## 6. Répartition des étapes (faisabilité)

Le `project.pbxproj` ne se modifie pas proprement hors Xcode (et CLAUDE.md l'interdit). D'où une
exécution **hybride** :

**Préparé par l'assistant (fichiers, versionnable) :**
1. Créer `ScoutKit/Package.swift` + arborescence `Sources/ScoutKit/…`.
2. Déplacer les sources partagées dans `Sources/ScoutKit/…` (git mv).
3. Réorganiser le métier dans `ScoutMateriel/` et `ScoutCamp/` (git mv + nouveaux fichiers d'app).
4. Balayage `public` sur ScoutKit.
5. Écrire `ScoutCampApp` + `RootView` + `CampTabView` ; adapter `ScoutMaterielApp`/`MainTabView`/
   `AppRouter` (3 onglets) ; ajouter `import ScoutKit` partout où c'est nécessaire.

**Réalisé par l'utilisateur dans Xcode (instructions pas‑à‑pas fournies) :**
6. Ajouter le package local `ScoutKit` au projet (File ▸ Add Package… ▸ Add Local).
7. Créer le target app **ScoutCamp** (iOS App), définir son dossier source synchronisé `ScoutCamp/`.
8. Pointer le dossier source synchronisé de l'app existante sur `ScoutMateriel/`.
9. Ajouter la dépendance `ScoutKit` aux **deux** targets.
10. Régler par target : base xcconfig = `Secrets.xcconfig`, `INFOPLIST_FILE`, `SupabaseAnonKey`,
    bundle id, display name, deployment target iOS 17.
11. Créer/renommer les schemes.

Chaque incrément se valide par `xcodebuild build` du/des scheme(s) concerné(s).

---

## 7. Découpage en incréments (pour le plan)

1. **Package ScoutKit (squelette)** : `Package.swift` + déplacement des Models/DesignSystem/
   Components/Config + balayage `public` partiel ; build du package seul.
2. **Services + Stores dans ScoutKit** : déplacement + `public` ; build package.
3. **LoginView + String+Identifiable dans ScoutKit** ; build package.
4. **ScoutMatériel** : réorg `ScoutMateriel/`, app entry + `MainTabView` 3 onglets + `import ScoutKit` ;
   build app matériel vert, parité Dashboard/Matériel/Scan.
5. **ScoutCamp** : réorg `ScoutCamp/`, `ScoutCampApp` + `CampTabView` 2 onglets + `import ScoutKit` ;
   build app camp vert, parité Intendance/Programme.
6. **Schemes + secrets par target** : les 2 apps démarrent et se connectent (smoke test).

Les étapes Xcode GUI (package, targets, dépendances, Info.plist) sont intercalées et documentées
dans le plan, à exécuter par l'utilisateur au bon moment.

---

## 8. Risques / points d'attention

- **Surface `public` large** : oubli = erreur de compilation explicite (pas de risque silencieux).
  On itère build→fix.
- **Groupes synchronisés (`PBXFileSystemSynchronizedRootGroup`)** : Xcode auto‑inclut les `.swift`
  d'un dossier dans le target qui le référence. Bien faire pointer chaque target sur SON dossier
  (`ScoutMateriel/` / `ScoutCamp/`) pour éviter qu'un fichier soit compilé deux fois.
- **Nom du produit `ScoutInventory.app`** : on peut garder le target/produit historique pour
  ScoutMatériel (moindre risque) ou le renommer ; décision au plan. Renommer le bundle id de l'app
  matériel casserait les installs → on **conserve** `com.scout.manager`.
- **Secrets** : `Secrets.example.xcconfig` mis à jour ; les deux targets doivent référencer la base
  config, sinon « clé Supabase manquante ».
- **Pas de target de test** (inchangé) : vérification par `xcodebuild build` + lancement des 2 apps.

---

## 9. Critère de fin (Projet 1)

Les **deux apps compilent, démarrent et se connectent** ; ScoutMatériel expose Dashboard/Matériel/
Scan, ScoutCamp expose Intendance/Programme — **fonctionnalités identiques à aujourd'hui, zéro
régression**. Le code partagé vit dans `ScoutKit`. Le flux matériel partagé (camp↔inventaire) est
le **Projet 2**.
