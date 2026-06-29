# ScoutManager MVP‑1 — Plan 3 : Dashboard

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Remplacer le placeholder de l'onglet Dashboard par un vrai tableau de bord :
cartes statistiques du matériel + raccourcis rapides, branché sur `ItemService`.

**Architecture:** `DashboardView → DashboardViewModel → ItemService → SDK`. Ajout d'un
`AppRouter` (sélection d'onglet) pour que les raccourcis changent d'onglet.

## Global Constraints

- iOS 17+, SwiftUI. Couleurs uniquement via le Design System (aucun littéral).
- `#003a5d` dominant (titres, bouton principal). Raccourci création = orange.
- Statistiques via `ItemService` ; en cas d'erreur (ex. SQL pas encore exécuté) →
  état dégradé lisible, **pas de crash**.
- Couleurs des stats via `StatusColorMapper` / tokens SGDF (dispo→lightGreen, sorti→orange,
  à réparer→red, total→primaryBlue).

## Files
Créés : `ScoutManager/App/AppRouter.swift`, `ScoutManager/ViewModels/DashboardViewModel.swift`,
`ScoutManager/Views/Dashboard/DashboardView.swift`.
Modifiés : `ScoutManager/App/MainTabView.swift` (TabView(selection:), Dashboard réel),
`ScoutManager/App/ScoutManagerApp.swift` (injecter `AppRouter`).

## Tasks
- **Task F (Dashboard)** : AppRouter + ViewModel + View + câblage TabView. Vérif build +
  smoke-test runtime. Voir le brief d'implémentation pour le code exact.

> Plans suivants : Plan 4 Matériel (liste/détail/formulaire/filtres), Plan 5 Scan/QR.
