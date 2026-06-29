# ScoutManager — Design MVP‑1

**Date :** 2026‑06‑29
**Périmètre :** MVP‑1 — Design System SGDF, navigation, module Matériel, module QR/Scan.
**Hors périmètre (phases ultérieures) :** Événements, Intendance/recettes, Programme de camp.

---

## 1. Contexte et décisions

ScoutManager est l'évolution de l'app iOS native existante `ScoutInventory` (SwiftUI,
parcours *scan → fiche → action*). On la fait **évoluer en place** : même dépôt git,
même projet Xcode, même backend Supabase.

Décisions validées :

| Sujet | Décision |
|-------|----------|
| Relation à l'existant | **Évolution en place** : nouvelle racine `ScoutManager/`, retrait progressif des écrans `ScoutInventory/`, jamais de projet cassé entre deux étapes. |
| Couche Supabase | **SDK officiel `supabase-swift`** via SPM (auth, Postgrest, Storage). Abandon assumé de la règle « zéro dépendance ». |
| Backend | **Même projet Supabase, schéma étendu** : on ajoute les tables MVP à côté de l'existant. Migrations SQL fournies. |
| Target Xcode | **Renommée `ScoutManager`** (scheme, `@main`, bundle id `com.scout.manager`). |
| Authentification | **On garde le login email/mot de passe** existant, porté sur le SDK. |
| Secrets | On conserve `Secrets.xcconfig` (clé anon hors git). |

---

## 2. Architecture cible

MVVM strict, services séparés. Arborescence (MVP en gras, le reste préparé mais vide) :

```
ScoutManager/
  App/            ScoutManagerApp.swift, RootView.swift
  DesignSystem/   SGDFColors.swift, SGDFTheme.swift, StatusColorMapper.swift, SGDFComponents.swift
  Components/     SGDFButton, SGDFCard, SGDFBadge, SGDFTextField, EmptyStateView, LoadingView
  Models/         Item, ItemCategory, ItemLocation, QRCode, MovementHistory (+ enums)
  Services/       SupabaseService, ItemService, QRCodeService, ImageStorageService
  ViewModels/     DashboardVM, MaterialListVM, MaterialDetailVM, MaterialFormVM, QRScannerVM
  Views/
    Dashboard/    DashboardView
    Material/      MaterialListView, MaterialDetailView, MaterialFormView,
                   MaterialImagePickerView, MaterialStatusBadge, MaterialFilterView
    Scan/          QRScannerView, QRCodeDetailView, AssignQRCodeView, QRCodeGeneratorView
    Intendance/    (placeholder « Bientôt »)
    Program/       (placeholder « Bientôt »)
```

**Règle de couches :** `Views → ViewModels → Services → SupabaseClient`. Les vues ne
touchent jamais le réseau. Les ViewModels sont `@MainActor ObservableObject`. Les
services encapsulent tout l'accès Supabase.

`SupabaseService` est un singleton fin exposant le `SupabaseClient` configuré depuis
`Config` (URL + clé anon depuis `Secrets.xcconfig`). Les services métier
(`ItemService`, `QRCodeService`, `ImageStorageService`) s'appuient dessus.

---

## 3. Design System SGDF

**Source unique de couleur de toute l'app.** Aucune vue n'écrit `Color.blue`, un hex,
ni un `Color(red:…)`. L'extension `Color(hex:)` est **privée au DesignSystem**.

### 3.1 `SGDFColors.swift`

Couleurs chartées :

| Token | Hex |
|-------|-----|
| `primaryBlue` | `#003a5d` |
| `orange` | `#ff8300` |
| `lightBlue` | `#0077b3` |
| `red` | `#d03f15` |
| `green` | `#007254` |
| `lightGreen` | `#65bc99` |
| `violet` | `#6e74aa` |

Neutres autorisés (interface uniquement) :

| Token | Hex | Rôle |
|-------|-----|------|
| `background` | `#F7F8FA` | fond d'écran (blanc cassé très léger) |
| `surface` | `#FFFFFF` | cartes, surfaces |
| `border` | `#E3E6EB` | bordures / séparateurs (gris très clair) |
| `textPrimary` | `#003a5d` | titres / texte fort (bleu SGDF) |
| `textSecondary` | `#5B6B7A` | texte secondaire (gris bleuté lisible) |

`#003a5d` doit rester **dominant** : NavBar, TabBar (tint), titres, boutons
principaux, icônes principales, onglet actif, écran scan, identité globale.

### 3.2 `StatusColorMapper.swift`

Mapping `ItemStatus → Color`, source unique pour badges/cartes/indicateurs :

| Statut | Couleur |
|--------|---------|
| `disponible` | `lightGreen` |
| `réservé` | `violet` |
| `sorti` | `orange` |
| `à vérifier` | `orange` |
| `à réparer` | `red` |
| `indisponible` | `red` |
| `perdu` | `red` |
| `rentré`/validé (mouvement) | `green` |
| `archivé` | `textSecondary` |

Couleurs de contexte (pour les onglets / en‑têtes de module) : Scan QR → `primaryBlue`,
Événement/camp → `lightBlue`, Intendance → `green`, Programme → `violet`.

### 3.3 `SGDFTheme.swift`

Typographies (titres en `textPrimary`), rayons de cartes (coins arrondis), espacements,
tailles de boutons (grands, lisibles, usage terrain), tint global `primaryBlue`.

### 3.4 Composants (`Components/`)

`SGDFButton` (primaire bleu / action rapide orange / secondaire), `SGDFCard` (carte
arrondie surface+border), `SGDFBadge` (badge de statut coloré via `StatusColorMapper`),
`SGDFTextField`, `EmptyStateView`, `LoadingView`. Tous les écrans n'utilisent que ces
composants pour boutons/cartes/badges.

---

## 4. Modèle de données (MVP)

### 4.1 Enums Swift

- **ItemStatus** : `disponible, réservé, sorti, àVérifier, àRéparer, indisponible, perdu, archivé`
  (rawValue snake/texte aligné DB).
- **ItemCondition** (état) : `neuf, bon, moyen, mauvais`.
- **TrackingType** (type de suivi) : `global` (petits éléments en quantité : assiettes,
  sardines, piquets…), `spécifique` (objets suivis individuellement : tente SG1, malle
  cuisine, réchaud…).
- **Branch** : `LJ, SG, PC, Groupe`.

### 4.2 Tables Supabase (migrations à fournir)

On étend le projet existant. Tables MVP :

- `categories` (id, group_id, name)
- `locations` (id, group_id, name)
- `items` — enrichissement de l'inventaire : id, group_id, name, description, category_id,
  location_id, tracking_type, quantity_total, quantity_available, status, condition,
  branch, event_id (nullable), image_path (Storage), notes, last_checked_at, timestamps.
- `qr_codes` (id, code unique, item_id nullable, status assigned/unassigned/disabled)
- `movement_history` (id, item_id, user_id, action, event_id nullable, created_at)

Bucket Storage `item-images` pour les photos.

**Transition** : les anciennes valeurs de statut de `inventory_items`
(`available/checked_out/…`) sont mappées vers les nouveaux statuts dans la migration.
La table `qr_tags` existante est reprise/migrée vers `qr_codes`.

### 4.3 Modèles Swift

`Item`, `ItemCategory`, `ItemLocation`, `QRCode`, `MovementHistory` — `Codable`,
`CodingKeys` snake_case ↔ colonnes Postgres, alignés sur les tables ci‑dessus.

---

## 5. Modules MVP

### 5.1 Navigation

`TabView` à 5 onglets, tint `primaryBlue`, onglet actif bleu SGDF :
**Dashboard · Matériel · Scan · Intendance · Camp**. Intendance et Camp affichent un
placeholder « Bientôt » (vue native, pas un écran vide cassé).

### 5.2 Dashboard

Cartes statistiques (grandes, arrondies) : total matériel, disponibles, sortis, à
réparer ; section alertes ; raccourcis rapides (Ajouter matériel = bouton orange,
Scanner = bouton bleu, Créer événement = désactivé/placeholder en MVP). Titres en
`textPrimary`, fond `background`.

### 5.3 Matériel

Écrans : `MaterialListView`, `MaterialDetailView`, `MaterialFormView`,
`MaterialImagePickerView`, `MaterialStatusBadge`, `MaterialFilterView`.

Fonctionnalités MVP : liste, recherche par nom, filtres (catégorie, statut,
localisation), ajout, édition, suppression/archivage, image (upload Storage + affichage
dans la fiche), badge de statut, QR code associé affiché, historique des mouvements
(lecture). Suivi `global` (quantités) vs `spécifique` (unitaire) géré dans le formulaire
et l'affichage.

### 5.4 QR / Scan

Écrans : `QRScannerView` (AVFoundation), `QRCodeDetailView`, `AssignQRCodeView`,
`QRCodeGeneratorView` (CoreImage).

Parcours :
1. Scan d'un QR.
2. QR associé → ouverture directe de la fiche matériel.
3. QR vierge → choix : associer à un matériel existant **ou** créer un nouveau matériel ;
   le QR est ensuite lié.
4. Changement rapide de statut après scan : sortir / rentrer / à réparer / perdu /
   vérifier (écrit un `movement_history` + met à jour le statut de l'item).

Génération : un QR unique par matériel (CoreImage), affiché dans la fiche, exportable.

---

## 6. Ordre de construction (incréments livrables)

À chaque étape, le projet compile et tourne.

1. **DesignSystem complet** + `Color(hex:)` privé.
2. **App shell** : `ScoutManagerApp`, `RootView` (login → TabView), TabView 5 onglets
   (Intendance/Camp en placeholder), target renommée.
3. **Intégration SDK Supabase** + `SupabaseService` + login porté sur le SDK.
4. **Migrations SQL** (schéma étendu + transition) + modèles Swift + services.
5. **Dashboard** (stats).
6. **Matériel** : liste → détail → formulaire → image → filtres/recherche.
7. **QR/Scan** : scan → fiche → association vierge → génération → statut rapide.

---

## 7. Garde‑fous

- Aucune couleur hors `DesignSystem/`. Avant toute UI : vérifier que les couleurs
  viennent de `SGDFColors`/`StatusColorMapper`/`SGDFTheme`.
- `#003a5d` visible et dominant sur chaque écran modifié.
- Chaque couleur respecte son rôle (pas d'orange pour une validation, pas de rouge pour
  un filtre).
- Boutons grands et lisibles, statuts immédiatement compréhensibles, fiches simples à
  remplir, scan accessible en un clic depuis la TabBar.
- Pas de design web, pas d'effet gadget, beaucoup de blanc, bleu SGDF dominant.

---

## 8. Hors périmètre (phases suivantes)

Événements/sorties/camps (checklists départ/retour), Intendance (recettes, menus, liste
de courses, ajustement par nombre de personnes), Programme de camp (activités jour par
jour), historique avancé, gestion multi‑groupes/rôles fine. L'architecture (dossiers
`Events/`, `Intendance/`, `Program/`, tables `events/recipes/activities/…`) est prévue
mais non implémentée en MVP‑1.
