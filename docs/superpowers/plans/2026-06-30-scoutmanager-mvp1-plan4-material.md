# ScoutManager MVP‑1 — Plan 4 : Matériel

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Remplacer le placeholder de l'onglet Matériel par le module cœur : liste +
recherche/filtres → fiche détail → formulaire ajout/édition + image.

**Architecture:** `Views → MaterialListViewModel/MaterialFormViewModel → ItemService /
ImageStorageService → SDK`.

## Global Constraints
- iOS 17+, SwiftUI. Couleurs uniquement via le Design System (aucun littéral).
- `#003a5d` dominant ; statut via `SGDFBadge`/`StatusColorMapper`.
- Erreur de chargement → état lisible, pas de crash.
- rawValues statut/état = enums existants de la base (cf. `Item`/`ItemStatus`/`ItemCondition`).
- Pas de `project.pbxproj` à éditer (groupes synchronisés).

## Tasks
- **Task G — Parcourir** : `MaterialListViewModel`, `MaterialListView` (+ row), `MaterialFilterView`,
  `MaterialDetailView` (lecture) ; brancher l'onglet Matériel. Recherche par nom, filtres
  catégorie/statut/localisation, fiche (image, badge, champs).
- **Task H — Éditer** : `MaterialFormViewModel`, `MaterialFormView` (ajout/édition), sélection
  d'image (PhotosPicker → `ImageStorageService`), bouton Ajouter (liste) + Modifier/Archiver
  (détail) via `ItemService.create/update/archive`.

> QR dans la fiche + historique des mouvements : Plan 5 (Scan/QR) — nécessite une lecture
> tag↔item et l'écriture des mouvements.
