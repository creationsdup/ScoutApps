# ScoutManager — Plan 7 : Programme de camp

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.
> Pas de target XCTest : chaque task = livrable **build‑vérifié** (`xcodebuild build`) + revue.
> **Dépend du Plan 6** (socle Camp : table `camps`, `CampStore`, `CampPickerView`/`CampFormView`).

**Goal:** Remplacer le placeholder de l'onglet Camp par le module Programme : infos camp →
bibliothèque d'activités → planning journalier → lien matériel.

**Architecture:** `Views → ProgramPlanViewModel/ActivityLibraryViewModel/CampInfoViewModel →
ActivityService/ProgramService → SupabaseService.shared.client`. Réutilise `CampStore` (camp
sélectionné) et `ItemService` (inventaire) existants.

**Spec:** `docs/superpowers/specs/2026-06-30-scoutmanager-programme-design.md`.

## Global Constraints
- iOS 17+, SwiftUI. Couleurs **uniquement** via le Design System. Accent de section = **violet**
  (`SGDFColors.violet`, rôle « programme » de la charte) ; statuts matériel via `StatusColorMapper`.
- **Backend partagé — additif uniquement.** `program_slot_materials` est une jointure additive
  référençant `inventory_items(id)` ; aucune colonne ajoutée à `inventory_items`.
- `Codable` ↔ snake_case via `CodingKeys`. `time` Postgres ↔ `String "HH:mm"` côté Swift.
  `id = UUID().uuidString` client à la création.
- Écriture gardée par `SessionStore.canWrite`. Erreurs remontées. Pas d'édition `project.pbxproj`.

## SQL (à exécuter par l'utilisateur)
Fichier additif `supabase/migrations/20260630_scoutmanager_programme.sql` (créé en Task V/W),
RLS calquée sur `categories`. Checks `not valid`.

## Tasks

- **Task U — Infos camp.** `ProgramHomeView` (onglet Camp) : sélecteur de camp (réutilise
  `CampPickerView`/`CampStore` du Plan 6) + sections Infos/Planning/Activités. `CampInfoViewModel`,
  `CampInfoView` (fiche du camp sélectionné, édition via `CampFormView` réutilisé). État vide →
  renvoi création camp. Brancher l'onglet Camp sur `ProgramHomeView`. *Livrable :* voir/éditer la
  fiche du camp sélectionné depuis l'onglet Camp.

- **Task V — Bibliothèque d'activités.** SQL `activities`. Enum `ActivityType`. Modèle `Activity`.
  `ActivityService`. `ActivityLibraryViewModel`. `ActivityLibraryView` (liste + filtre type/branche)
  + `ActivityFormView`. *Livrable :* créer/filtrer/consulter des activités réutilisables.

- **Task W — Planning.** SQL `program_slots`. Modèle `ProgramSlot`. `ProgramService` (list par camp,
  upsert). `ProgramPlanViewModel`. `ProgramPlanView` (**timeline jour × créneaux** sur
  `[start_date…end_date]`, slots triés par `start_time`) + `ProgramSlotFormView` (titre, horaires,
  lieu, notes ; **pioche** une activité de la bibliothèque → pré-remplit titre/durée/notes).
  *Livrable :* construire le planning jour par jour, en piochant des activités.

- **Task X — Lien matériel.** SQL `program_slot_materials`. Étendre `ProgramService` (lier/délier
  items). `SlotMaterialPickerView` (liste l'inventaire via `ItemService`, cochage). Afficher le
  matériel rattaché dans `ProgramSlotFormView` avec son `StatusColorMapper`. *Livrable :* rattacher
  du matériel d'inventaire à un créneau.

> Même cycle par task : SQL additif (exécuté par l'utilisateur) → modèle → service → VM → vues →
> `xcodebuild build` propre → revue.
