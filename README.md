# Scout Inventaire — iOS (SwiftUI)

App iOS native pour le parcours terrain de l'inventaire matériel scout :
**scanner un QR → fiche objet → action terrain**. Même backend Supabase que
[CampManager](../CampManager) (web + mobile Expo).

## Stack

- SwiftUI, iOS 17+, Xcode 16+ (testé Xcode 26).
- **Aucune dépendance externe** : accès Supabase via REST (PostgREST) + Auth
  (GoTrue) en `URLSession`.
- Scan via VisionKit `DataScannerViewController` (caméra) + saisie manuelle de
  secours.

## Configuration

1. Ouvre `ScoutInventory.xcodeproj` dans Xcode.
2. Renseigne ta clé Supabase `anon` dans `ScoutInventory/Config.swift`
   (`supabaseAnonKey`). Récupère-la depuis
   `CampManager/apps/web/.env.local` → `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
   L'URL du projet est déjà renseignée.
   - La clé `anon` est faite pour être embarquée côté client ; la sécurité est
     assurée par les politiques RLS Postgres.
3. Sélectionne un simulateur iOS (ou ton iPhone) et lance (⌘R).
   - La caméra ne fonctionne pas sur simulateur : utilise la **saisie manuelle**
     du code (`TAG-000001`). Sur un vrai appareil, le scan caméra fonctionne.

## Architecture

```
ScoutInventory/
  ScoutInventoryApp.swift     point d'entrée @main
  Config.swift                URL + clé anon Supabase
  Models/Domain.swift         modèles métier (miroir du package shared TS)
  Services/
    SupabaseService.swift     auth + REST (lectures + createMovement)
    AppState.swift            état global (session, rôle, façade)
  Views/
    RootView.swift            aiguillage login / scan
    LoginView.swift           connexion email + mot de passe
    ScanView.swift            caméra + saisie + résolution du tag
    ItemDetailView.swift      fiche objet + actions terrain
```

## Parcours implémenté (v1)

1. **Connexion** email / mot de passe (Supabase Auth).
2. **Scan** d'un `TAG-000001` (caméra ou saisie) → résolution via `qr_tags`.
3. Tag assigné → **fiche objet** ; vierge / désactivé / inconnu → message clair.
4. **Actions** Sortir / Retour / Nettoyage / Réparation → mise à jour du statut
   puis insertion du mouvement (ordre idempotent), via la couche `shared`.
5. **Garde-fou rôle** : un `viewer` voit les actions grisées (lecture seule).

## Limites connues / suite

- v1 **online-first** : la file offline (rejeu des actions hors réseau) est la
  prochaine étape.
- Pas d'icône d'app ni d'asset catalog (placeholder de dev).
- Dépôt git **local** uniquement (pas de remote configuré).
