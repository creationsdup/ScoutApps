# ScoutManager MVP‑1 — Plan 5 : Scan / QR

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Remplacer le placeholder de l'onglet Scan par le parcours QR : scanner →
fiche objet ; QR vierge → associer/créer ; génération de QR ; changement rapide de statut.

**Architecture:** `QRScannerView → ScannerViewModel → QRCodeService / ItemService`.
Scan caméra via **AVFoundation** (`AVCaptureSession`), + saisie manuelle (le simulateur n'a
pas de caméra). Génération via `QRCodeService.generateImage` (CoreImage).

## Global Constraints
- iOS 17+, SwiftUI. Couleurs uniquement via le Design System (aucun littéral).
- Scan = identité bleu SGDF (`#003a5d`).
- Permission caméra : `NSCameraUsageDescription` déjà présent dans l'Info.plist.
- Format d'étiquette validé par `TagCode.parse` (`TAG-000001`).
- Garde-fou rôle (Task L) : actions d'écriture gated par `SessionStore.canWrite`.
- Pas de `project.pbxproj` à éditer (groupes synchronisés).

## Tasks
- **Task J — Scan + résolution** : `ScannerViewModel`, `QRScannerView` (caméra AVFoundation +
  saisie) → résout via `QRCodeService.tag(byCode:)` + `ItemService.get(id:)` → ouvre
  `MaterialDetailView` ; messages clairs (vierge/désactivé/inconnu/invalide). Branche l'onglet Scan.
- **Task K — QR vierge + génération** : `AssignQRCodeView` (associer un tag vierge à un objet
  existant ou en créer un), `QRCodeGeneratorView` (afficher/exporter le QR d'un objet) ; lien
  depuis la fiche.
- **Task L — Statut rapide + mouvements** : `MovementService` (PATCH statut idempotent puis
  insert `item_movements`), actions rapides après scan (sortir/rentrer/réparer/perdu/vérifier),
  gated par `canWrite`.

> Après le Plan 5, le MVP‑1 est complet → revue globale de branche + finalisation.
