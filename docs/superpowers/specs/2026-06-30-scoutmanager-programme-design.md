# ScoutManager — Design : Programme de camp

**Date :** 2026‑06‑30
**Périmètre :** Spec B — module **Camp / Programme** (infos camp, planning journalier,
bibliothèque d'activités, lien matériel).
**Dépend de :** Spec A « Camp & Intendance » — réutilise l'entité **Camp** (table `camps`,
`CampStore`, sélecteur). À implémenter **après** le socle Camp.

---

## 1. Contexte et contraintes

Remplace l'onglet placeholder « Camp » par le module Programme. Mêmes contraintes que la
Spec A : **backend partagé / additif uniquement**, conception **défensive** vis‑à‑vis de
`events`, couches MVVM strictes, charte SGDF source unique de couleur, écriture gardée par
`SessionStore.canWrite`, `CodingKeys` snake_case, UI française.

Le module **réutilise le socle Camp** livré en Spec A : pas de nouvelle entité camp, on
branche le planning et les infos sur le `camp` sélectionné dans `CampStore`.

---

## 2. Architecture cible (ajouts)

```
ScoutManager/
  Models/
    Activity.swift        Activity (+ ActivityType enum)
    ProgramSlot.swift     ProgramSlot
  Services/
    ActivityService.swift   CRUD bibliothèque d'activités
    ProgramService.swift    CRUD program_slots + lien matériel
  ViewModels/
    ActivityLibraryViewModel
    ProgramPlanViewModel, ProgramSlotFormViewModel
    CampInfoViewModel
  Views/
    Program/
      ProgramHomeView        sélecteur de camp + onglets : Infos / Planning / Activités
      CampInfoView           fiche camp (réutilise Camp ; lecture + édition)
      ProgramPlanView        timeline jour × créneaux horaires
      ProgramSlotFormView    créneau : titre, activité liée, horaires, lieu, matériel
      ActivityLibraryView    catalogue réutilisable
      ActivityFormView       créer/éditer une activité
      SlotMaterialPickerView lier des items d'inventaire à un créneau
```

---

## 3. Modèle de données (SQL additif)

Fichier `supabase/migrations/20260630_scoutmanager_programme.sql`, idempotent, RLS calquée
sur `categories` (select `authenticated`, write `admin/manager/member`). `id uuid default
gen_random_uuid()`, `created_at timestamptz default now()`.

**`activities`** (bibliothèque, **non** scoped camp) — `name text not null, type text,
duration_min int, description text, branch text, material_notes text`.
`type` ∈ `jeu/grand_jeu/veillee/temps_spi/atelier/autre` (check `not valid`).

**`program_slots`** (planning) — `camp_id→camps on delete cascade, date date, start_time
time, end_time time, title text not null, activity_id uuid null→activities on delete set
null, location text, notes text`.

**`program_slot_materials`** (lien matériel) — `slot_id→program_slots on delete cascade,
inventory_item_id uuid→inventory_items(id) on delete cascade`, pk composite.
Table **de jointure additive** référençant l'`inventory_items` existante (lecture seule de
l'item) ; n'ajoute aucune colonne à `inventory_items`.

---

## 4. Modèles Swift

- `ActivityType: String, CaseIterable` — `jeu, grandJeu="grand_jeu", veillee, tempsSpi="temps_spi", atelier, autre` ; `label` FR.
- `Activity` / `ProgramSlot` : `Codable, Identifiable`, `CodingKeys` snake_case
  (`durationMin="duration_min"`, `materialNotes="material_notes"`, `campId="camp_id"`,
  `activityId="activity_id"`, `startTime="start_time"`, `endTime="end_time"`).
- `time` Postgres mappé en `String` `"HH:mm"` côté Swift (parsing léger pour l'affichage/tri).
- Création : `id = UUID().uuidString` client.

---

## 5. Surfaces (écrans) & flux

**Onglet Camp → `ProgramHomeView`.** En tête : sélecteur de camp (`CampStore`, partagé avec
l'Intendance). Si aucun camp : `EmptyStateView` renvoyant vers la création de camp (Spec A).
Trois sections (segmented ou sous‑navigation) :

| Section | Écran | Contenu |
|---------|-------|---------|
| **Infos** | `CampInfoView` | fiche du camp sélectionné (nom, lieu, dates, branche, effectifs) ; édition via `CampFormView` réutilisé. |
| **Planning** | `ProgramPlanView` | **timeline jour × créneaux** sur `[start_date…end_date]` ; chaque jour liste ses `program_slots` triés par `start_time` ; tap → `ProgramSlotFormView`. |
| **Activités** | `ActivityLibraryView` | bibliothèque réutilisable ; filtre par `type`/`branch` ; `ActivityFormView` en écriture. Depuis un créneau, on **pioche** une activité (pré‑remplit titre/durée/notes matériel). |

**Lien matériel.** Dans `ProgramSlotFormView`, `SlotMaterialPickerView` liste l'inventaire
(via `ItemService` existant) et permet de cocher les items nécessaires au créneau
(`program_slot_materials`). Affichage du matériel rattaché avec son `StatusColorMapper`
(disponible/sorti…). Optionnel : filtrer par `event_id == camp.event_id` si renseigné.

**Couleurs (charte) :** le Programme utilise le **violet** (`SGDFColors.violet` = rôle
« programme/réservé » de la charte) comme accent de section, sur fond d'identité bleu
primaire. Statuts matériel via `StatusColorMapper`. Aucune couleur en dur.

---

## 6. Découpage en incréments (pour le plan)

1. **Infos camp** : `ProgramHomeView` + sélecteur + `CampInfoView` (réutilise socle Camp).
2. **Bibliothèque d'activités** : `activities` + liste/filtre + formulaire.
3. **Planning** : `program_slots` + timeline jour×créneau + éditeur de créneau + pioche
   depuis la bibliothèque.
4. **Lien matériel** : `program_slot_materials` + `SlotMaterialPickerView`.

Chaque incrément : migration additive (si tables) → modèle → service → VM → vues →
build‑vérifié → revue.

---

## 7. Hors périmètre (cette spec)

- Génération automatique de programme / suggestions.
- Export PDF du planning.
- Feuille de présence / pointage des jeunes.
- Notifications/rappels d'horaires.
