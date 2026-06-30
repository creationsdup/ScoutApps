# ScoutManager MVP-1 Plan 1 — Progress Ledger

Plan: docs/superpowers/plans/2026-06-29-scoutmanager-mvp1-foundation.md
Branch: feature/scoutmanager-mvp1

Scaffolding: complete (commit a07dc2e..HEAD) — ScoutManager/ synchronized group wired,
  PRODUCT_MODULE_NAME=ScoutManager, bundle id com.scout.manager.
Blocked-on-user: ScoutManagerTests target must be created in Xcode before TDD tasks.

- Task 1 (Color+Hex): not started
- Task 2 (SGDFColors): not started
- Task 3 (ItemStatus + StatusColorMapper): not started
- Task 4 (SGDFTheme): not started
- Task 5 (Components): not started
- Task 6 (App shell + nav): not started

--- update ---
Design System (Tasks 1-5): implemented (commit 1ad46de), clean build SUCCEEDED.
  DEVIATION: status enum named SGDFItemStatus (collision with ScoutInventory/Models/Domain.swift ItemStatus).
  TECH DEBT: retire Domain.swift + rename ScoutManager domain types to spec names when ScoutInventory screens are retired (Plan 2 / Task 6).
  Review: in progress.

Task DS (design system): COMPLETE — review clean (Approved). commits 1ad46de + 5953454 (onColor fix).
  Minor .white finding fixed via SGDFColors.onColor token.
Task 6 (nav shell): starting. base SHA 5953454.
  Note: must RETIRE old colliding screens (ScoutInventory RootView/MainTabView/ScanView/
  MaterialListView/ItemDetailView/EventsListView + ScoutInventoryApp @main); KEEP AppState,
  LoginView, SupabaseService, Config, Domain.swift.

Task 6 (nav shell): COMPLETE — review Approved (no Critical/Important; 2 minor rename-vs-create notes).
  commit c9390dd. App now boots on ScoutManagerApp @main → RootView (login ↔ 5-tab MainTabView).
=== PLAN 1 (Foundation) COMPLETE ===
  Final whole-branch review deferred until branch is finished/merged (continuing to Plan 2 on same branch).

PLAN 2 (Supabase SDK + auth port + data) — starting.
  User decisions: SPM package added by user in Xcode (instructions given); SQL migrations authored by me, run by user.
  Pending user action: add supabase-swift package (blocks SDK code tasks).
  Open decision: schema strategy (extend existing tables vs new tables + migrate) — asking.

PLAN 2 authored: docs/.../plan2-supabase-data.md + supabase/migrations/20260629_scoutmanager_mvp1.sql (committed).
  Schema strategy = extend existing tables.
  BLOCKED on user: (1) add supabase-swift SPM package in Xcode, (2) review+run the SQL migration.
  Tasks A-C-E (code) need the package; Task D (SQL) needs user execution. None dispatchable yet.

PLAN 2 execution:
  Package: ADDED headlessly (Xcode UI add hadn't persisted). Supabase 2.48.0 resolved. commit 17b5c89.
  Task AB (SDK client + auth port + legacy auth removal): dispatched. base SHA 17b5c89.
    Combines plan Tasks A+B. Deletes legacy AppState/SupabaseService/LoginView; keeps Domain.swift (UserRole).

Task AB (SDK auth port): COMPLETE — review Approved (no Critical/Important). commits bcd25d8 + 6935104 (login fix).
  Minor: login error-message edge case FIXED. SGDFColors.border ⚠ resolved (charted neutral #E3E6EB).
  Legacy auth removed; ScoutInventory/ now only Models/Domain.swift.
Task C (models + remove Domain.swift + rename ItemStatus): dispatching. base SHA 6935104.

Task C (models + remove Domain.swift + rename ItemStatus): DONE (commit 29b5885), build clean, ScoutInventory/ empty.
  Review: in progress.
Note: Task E (data services) can be CODED + build-verified without the SQL run (compile doesn't hit DB);
  runtime validation waits for user to run the SQL migration.

Task C: COMPLETE — review Approved (no Critical/Important). Minor QRCodeStatus/MovementAction rawValues
  resolved: SQL doesn't touch qr_tags/item_movements, values match existing tables.
Task E (data services Item/Image/QRCode): dispatching. base SHA 29b5885. Build-verifiable without SQL run.

Task E (data services): DONE (commit 4e1078d), build clean. SDK deviation: Encodable payload structs for updates.
  Review: in progress. After approval → PLAN 2 code complete.
Remaining to close MVP-1 Plan 2: (a) user runs SQL migration, (b) runtime login test on simulator/device,
  (c) final whole-branch review before finishing branch.

Task E: COMPLETE — review Approved. === PLAN 2 (code) COMPLETE ===
  Deferred findings (for final review / Plan 4-5, not current bugs):
   - ItemService.update sends full Item -> use partial payload when wiring Material UI (Plan 4).
   - ItemService.list: includeArchived:false + status:.archive -> silent empty (guard later).
   - QRCodeService: CIContext per call -> make static when scan UI lands (Plan 5).
   - MovementHistory CRUD not implemented yet -> Plan 5 (scan/movements).
Commits Plan 2: 17b5c89 (pkg), bcd25d8+6935104 (auth), 29b5885 (models), 4e1078d (services).
PENDING: user runs SQL migration; runtime login smoke test; final whole-branch review at branch finish.

RUNTIME SMOKE TEST: PASS. App boots to LoginView on simulator (iPhone 17 Pro), no crash.
  SGDF blue dominant, Config.isConfigured true (anon key read from Info.plist at runtime), SDK init OK.
  Screenshot: /tmp/sm_shot.png. Awaiting user: SQL migration run + real login test.

PLAN 3 (Dashboard) started. User: building Dashboard first; SQL not yet run (building in parallel).
  Task F (Dashboard: AppRouter + VM + View + TabView wiring): dispatching. base SHA = current HEAD.

Task F (Dashboard): DONE (commit 1cb7ce4), build clean. AppRouter + DashboardViewModel + DashboardView,
  TabView selection wired. Review: in progress.
  Visual verification = user-side (Dashboard is behind login; controller has no credentials).

Task F (Dashboard): COMPLETE. Review "Needs fixes" adjudicated:
  - Important (pbxproj non-buildable) = FALSE POSITIVE: synchronized group auto-includes files;
    Xcode merely relocated the intact SPM package sections (committed). Build clean on fresh clone.
  - Minor double-spinner: FIXED (942e4c1). GridItem spacing: left (acceptable).
  === PLAN 3 (Dashboard) COMPLETE ===
SQL: FIXED (47a3970) — status/condition were Postgres enums; now enum->text + convert + CHECK. User to re-run.

SCHEMA PIVOT (shared backend with CampManager): do NOT mutate status/condition values/types.
  - SQL now additive only: categories/locations, additive columns, +2 enum values (reserve/indisponible),
    RLS, bucket. Removed enum->text conversion + value migration (would break CampManager + dashboard_stats view).
  - ItemStatus rawValues -> DB enum (available/checked_out/cleaning_required/repair_required/missing/archived)
    + reserve/indisponible; French labels kept. ItemCondition -> excellent/good/fair/damaged/broken + FR labels.
  - commit a73b4d2. Case names unchanged -> StatusColorMapper/SGDFBadge/Dashboard unaffected.
  - This also fixes the Dashboard to match real data (filters by .disponible == "available").

PLAN 4 (Material) started. Task G (browse: list+search+filters+detail): dispatching. base SHA = current HEAD.
  Task H (form/edit + image) to follow.

SQL: USER RAN IT OK (real data now flows to Dashboard + Material list).
Task G (Material browse: list+search+filters+detail): DONE (commit 65de2d8), build clean, no deviations.
  Review: in progress. Task H brief (form/edit/image/archive) ready at scratchpad/material-form-brief.md.

Task G: COMPLETE — review Approved (no Critical/Important). Minors (for final review):
  - MaterialDetailView: ImageStorageService() per body eval (negligible struct alloc).
  - MaterialRow doc comment mentions quantity it doesn't render.
  - MaterialFilterView dismiss races async load (acceptable UX).
Task H (Material add/edit form + image + archive): dispatching. base SHA 65de2d8.

Task H (Material add/edit form + image + archive): DONE (commit 461ab8e), build clean, no deviations.
  Review: in progress. After approval -> PLAN 4 (Material) complete.

Task H review: "Needs fixes" — 2 Important (quantityAvailable reset on edit; archive error swallowed) + 1 Minor.
  Fixer applied all 3 (commit bf50302), build clean. Re-review in progress.
  (pbxproj ⚠ from reviewer = recurring false positive: synchronized folder group.)
Plan 5 Task J brief ready at scratchpad/scan-brief.md (AVFoundation scanner + resolve).

Task J (Scan core: AVFoundation scanner + manual entry + resolve->detail): dispatching. base SHA = HEAD (bf50302).
  Dispatched in parallel with Task H re-review (read-only); J is independent of the fix internals.

Task H: COMPLETE — re-review Approved (all 3 fixes correct, no regressions). === PLAN 4 (Material) COMPLETE ===

Task J (Scan core): COMPLETE — review Approved. 2 Minor FIXED (commit 8ccd113):
  camera re-arm on return (viewWillAppear + reset didScan) + session start/stop off-main.
Parallel work done: CLAUDE.md rewritten for ScoutManager (commit 6876fc5); Task K brief ready.
Task K (QR assign blank tag + generate/share): dispatching. base SHA = HEAD (6876fc5).

Task K (QR assign blank tag + generate/share): DONE (commit e4c63cc), build clean. String:Identifiable once (@retroactive). Review: in progress.
Task L (field quick actions + movements) brief ready at scratchpad/movement-brief.md; dispatch after Task K review.

Task K: COMPLETE — review Approved. Important (try? conflating net error vs no-tag) FIXED (commit 1036826).
  Minors deferred to final review: QR image regenerated per body recompute; AssignQRCodeView search on submit only.
Task L (field quick actions + movement journal + role guard): dispatching. base SHA = HEAD (1036826).

Task L: COMPLETE — review Approved (no Critical/Important). 2 Minor (debug logging, subview comment) deferred.
=== PLAN 5 (Scan/QR) COMPLETE === === MVP-1 FUNCTIONALLY COMPLETE ===
Smoke test: final build boots to login (SGDF blue, no crash). Authenticated screens = user-verifiable.
Whole-branch review: dispatching on full diff 988d9ec..HEAD.

WHOLE-BRANCH REVIEW (opus): "Fix-then-merge". Charter clean, secrets correct, SQL additive-safe.
  Fixed pre-merge (commit 15f8042): (Important) gate edit/archive on canWrite; (Minor) drop Archivé filter.
  All other minors OK-to-defer per review. SMOKE TEST passed (boot/login).
=== MVP-1 COMPLETE — branch ready to merge ===

=== PHASE 2 (Camp & Intendance + Programme) — branche feature/scoutmanager-phase2 ===
Specs: 2026-06-30 camp-intendance (A) + programme (B). Plans: plan6 (tasks M-T) + plan7 (U-X).
Task M (socle Camp): COMPLETE — review Approved après 1 fix.
  commits 7428aca (impl) .. d80c894 (fix: gate CampListView edit on canWrite + modern toast).
  Build OK. SQL camps additif (à exécuter par l'utilisateur). CampStore injecté à la racine.
Task N (Menus): COMPLETE — review Approved (no Critical/Important). commit 4333405. Build OK.
  SQL meals+meal_recipes appendu (additif). Carte Menus navigable. Minors différés (revue finale):
  - M1 DateFormatter dupliqué MealPlanView/MealEditorView (static, alloc 1×, bénin).
  - M2 isSaving=false après dismiss() (ignoré par SwiftUI, préférer defer).
  - M3 .sheet à 3 @State optionnels (chemin nil impossible en l'état; .sheet(item:) plus propre).
Task O (Recettes): COMPLETE — review Approved après fixes. commits 9390db8 (impl) .. a3647d9 (fix).
  2 Important corrigés (save repas/lien non-bloquant; parsing décimal FR ,->.) + 3 Minor (swipe gate,
  fiche localRecipe, Double.qtyDisplay dédup). Carte Recettes navigable. meal_recipes consommé. Build OK.
Task P (Courses): COMPLETE — review Approved (no Critical/Important). commit a8cda54. Build OK.
  Génération menus correcte (occurrences x ceil(participants/servings), auto remplacé / manuel gardé).
  Carte Courses navigable. Minors différés (revue finale):
  - factor Double(Int(ceil(...))) round-trip inutile (bénin).
  - ShoppingService.update envoie toute la ligne pour un toggle (préférer patch {checked}).
  - errorMessage partagé persiste après Annuler de ShoppingAddView (clear à .onDisappear/Annuler).
Task Q (Budget): COMPLETE — review Approved après fix. commits 008cca5 (impl) .. e4acb93 (fix).
  Important corrigé (liste VStack->List pour swipe-delete réel) + Minor (montants FR en édition).
  Carte Budget navigable. Build OK (contrôle). Reste seul placeholder: Registre.
Task R (Stock): COMPLETE — review Approved (no Critical/Important). commit dab59a8. Build OK.
  Péremption correcte (startOfDay, seuil 7j), List+onDelete+deleteDisabled. Carte Stock navigable.
  Minors différés: isSaving=false après dismiss() (form); double parse date dans expiryBadge.
PARALLÈLE: module Programme (Plan 7, tasks U-X) lancé en worktree isolé (agent autonome, base dab59a8-era).
Task S (Registre traçabilité): COMPLETE — review Approved (no Critical/Important). commit 290048d. Build OK (contrôle).
  Préservation photo double-verrouillée, List+onDelete+deleteDisabled, plus aucun placeholder hub.
  Minors différés: try? sur loadTransferable (pattern existant); DateFormatter dupliqué; sheet blank-on-nil (récurrent N/S).
Task T (scan code-barres EAN): COMPLETE — review Approved (no Critical/Important). commit 978dc73. Build OK.
  BarcodeScannerView ([.ean8,.ean13,.qr]) branché dans FoodTraceFormView. Pas de redeclaration String:Identifiable.
  Minors À CORRIGER avant revue finale: champ code-barres rétrogradé SGDFTextField->TextField (charte) ; config AVCaptureSession sur main (polish).
=== MODULE INTENDANCE (Tasks M-T) COMPLET sur feature/scoutmanager-phase2 ===
PROGRAMME (worktree worktree-agent-a45c46827880fd5fc, commits 1f96bf1..7880627): build vert, revue d'ensemble (opus) EN COURS avant merge.
PROGRAMME mergé dans feature/scoutmanager-phase2 (merge commit 3f474b6, --no-ff). Build fusionné OK. Worktree supprimé.
Revue Programme (opus): Approved avec 1 fix recommandé. À corriger:
  - IMPORTANT: ProgramSlotFormView.loadItems catch silencieux -> au save setItems([]) efface les liens. Durcir (flag linksLoaded).
  - Task X gap: afficher items rattachés avec StatusColorMapper dans le form.
  - Minors différés Programme: VM-layering (toléré, précédent MealEditorView), slots/activities stale-on-error, end<start, .sheet(item:).
Fix wave consolidée EN COURS (Programme Important + Task X + Task T SGDFTextField + garde horaire).
Fix wave consolidée: DONE (commit 5c50bee). Build OK. 4 fixes (loadItems guard, attached-material display, barcode SGDFTextField, time guard).
REVUE FINALE branche phase-2 (8ed2027..5c50bee, 17 commits, 61 fichiers): opus EN COURS (additivité SQL, charte, secrets, transverse).
REVUE FINALE (opus): ✅ Ready. SQL additivité PASS, 0 Critical/0 Important, secrets clean, canWrite complet.
  Minors OK-to-defer: Color.clear token (BudgetView listRowBackground), DateFormatter dupliqués, delete-then-insert non atomique,
  RecipeDetailViewModel.get via list().first, .sheet(isPresented:) vs item:, ShoppingService.update full-row.
=== PHASE 2 COMPLÈTE — merge dans main ===
CLEANUP (chore/phase2-cleanup, commit e0bd49b): mergé dans main. Build vérifié vert (indépendant) avant ET après merge.
  Fait: SGDFColors.clear (4 littéraux routés), SGDFDate partagé (13 formatters dupliqués supprimés, -48 lignes nettes),
  RecipeService.get(id:). Partiel/skip: .sheet(item:) (0 conversion — sheets add+edit partagés, wrapper non plus propre);
  FR display formatters non consolidés (prudence); atomicité delete-then-insert hors scope (RPC).
  Branches feature + cleanup supprimées. main = état final phase 2.
=== PHASE 2 + CLEANUP TERMINÉS, mergés dans main ===
RPC courses (feat/shopping-rpc, f3e6810): mergée dans main. Revue: équivalence sémantique/atomicité/RLS/additivité PASS, 0 Critical.
  regenerate_shopping_auto (security invoker). ShoppingService.regenerateAuto = 2 lignes (appel rpc). Build vérifié vert. Branche supprimée.

=== SCISSION ScoutMatériel + ScoutCamp (branche feat/split-scoutcamp) ===
Spec 2026-06-30-split-..., plan 2026-06-30-plan-split-... Approche A (package ScoutKit + 2 targets).
Tasks 1-5 (fichiers): ScoutKit package créé, commun déplacé (Models/Services/Stores/DesignSystem/
  Components/Config/Auth), sweep public (subagent, 46 fichiers), ScoutMateriel (3 onglets) + ScoutCamp
  (2 onglets) carvés, BarcodeScannerView déplacé vers ScoutCamp. Commits 465e192..387d0ce.
Task 6 (Xcode): utilisateur a wiré ScoutMateriel (package+groupes+display name) ; assistant a créé le
  target ScoutCamp via gem xcodeproj (39 fichiers, ScoutKit lié, base config Secrets, com.scout.camp,
  Info.plist, scheme partagé) + dédup ScoutKit + retrait doublons sources dans le bundle. Commits 2d31444, bc72006.
Task 7 (build): LES DEUX APPS BUILD SUCCEEDED (zéro fix public nécessaire — sweep complet).
Task 8: CLAUDE.md mis à jour (2 apps + ScoutKit). RESTE: smoke test des 2 apps par l'utilisateur (runtime).
=== SCISSION quasi terminée — manque smoke test runtime + merge dans main ===
Task 4 (auto-feed activité->chargement): COMPLETE — review Approved (no Critical/Important). commit f45860e. Build ScoutCamp OK.
  Minor différé: échec partiel de la boucle assign (self-healing via RPC idempotente, conforme au brief).
Task 5 (ScoutMatériel 'Sorti pour camp'): COMPLETE — review Approved (0 issue). commit cc733fd. Build ScoutMatériel OK.
=== PROJET 2 : 5 tasks complètes — revue finale de branche en cours ===
REVUE FINALE Projet 2 (opus): ✅ Ready. SQL additive PASS, atomicité/cohérence PASS, canWrite+RLS, 0 Critical/0 Important.
  Minors OK-to-defer: Row.inventory_items doc; add-sheet dismiss en erreur + flash; assign loop partiel; cross-camp single-item (hors scope v1).
=== PROJET 2 COMPLET — merge dans main ===

=== BON DE SORTIE (panier) — branche feat/checkout-cart ===
Spec 2026-06-30-checkout-cart ; plan 2026-06-30-plan-checkout-cart (5 tasks).
Task 1 (SQL checkouts/checkout_items + RPC create/return): COMPLETE (contrôleur, verbatim). additif. à exécuter dans Supabase.
Task 2 (ScoutKit Checkout models+service): COMPLETE — review Approved (0 issue). commit d6166f5. Build OK.
Tasks 3+4 (UI Sorties, arbre principal) + Task 5 (worktree) lancées EN PARALLÈLE.
Tasks 3+4 (UI Sorties): impl 01a54ad ; registration+fix FontStyle e60b6d2 ; build OK. Revue en cours.
Task 5 (indicateur fiche, worktree 9996fa2): mergé (a3ed951), build combiné OK. Revue en cours.
Task 5 (indicateur 'dans la sortie'): COMPLETE — review Approved (0 issue). mergé a3ed951.
Tasks 3+4: review Needs fixes -> fix wave 94cf46e (Important: list error banner; Minors: date header, picker dupe guard, dead setQty). Build OK.
  Note: M2 (SGDFBadge) écarté (SGDFBadge typé ItemStatus, pas CheckoutStatus). M5 différé (read try? acceptable).
=== 5 tasks complètes — revue finale de branche ===
REVUE FINALE (opus): ✅ Ready. SQL additive PASS, anti-survente+atomicité+cohérence PASS, canWrite+RLS, 0 Critical/0 Important.
  Minors OK-to-defer: status force available (par design), onAppear min(1,remaining) cosmétique, SGDFBadge non applicable, loadAvailable try?.
=== BON DE SORTIE COMPLET — merge dans main ===

=== PLAN: Stock Management (cycle 1/3) — branch feature/stock-management ===
Plan: docs/superpowers/plans/2026-06-30-stock-management.md
Base SHA: a75421e (plan commit). Subagent-driven execution starting.
Task 1: complete (commits a75421e..c9f43ad, review clean — Spec OK, Quality approved, 0 findings)
Task 2: complete (commits c9f43ad..26a30d5, review clean — Spec OK, Quality approved).
  NOTE: MovementAction.adjustment forced adding icon(for:) .adjustment case in MaterialDetailView (Task 4 Step 1) — pulled forward; Task 4 Step 1 is now a no-op.
  Minor (deferred): cosmetic re-alignment of icon(for:) case returns; Item/MovementHistory CodingKeys internal (pre-existing pattern, correct).
Task 3: complete (commits 26a30d5..36be580, review clean — Spec OK, Quality approved).
  Minor (deferred to final review): adjustStock get()+update() is non-atomic (TOCTOU) — matches existing project pattern (e.g. archive); acceptable for single-operator MVP, document before multi-user writes.
Task 4: complete (commits 36be580..6ad009d, review clean — Spec OK, Quality approved).
  Minor (deferred to final review): (a) adjustStock(by:) sets liveAvailable = updated.quantityAvailable (Int?) — if nil, silently falls back to stale value; consider guard-let. (b) StockCard note uses bare TextField instead of SGDFTextField (design-system consistency).
Task 5: complete (commits 6ad009d..5075510, review clean — Spec OK, Quality approved).
  Minor (no action): seuil/unit kept in memory on global->specifique switch; save() null-fills them; reasonable UX.
Task 6: complete (commits 5075510..afe0a1f, review clean — Spec OK, Quality approved).
  Minor (no action): redundant accessibilityLabel on Label (brief-prescribed, harmless).
=== ALL 6 TASKS COMPLETE — launching final whole-branch review ===
FINAL REVIEW (opus): NEEDS FIXES → 1 Important (stale duplicate quantity row) + 1 new Minor (global->specifique available>total).
FIX commit 1e97cc3 (build SUCCEEDED): hide static Quantité row for global; clamp quantityAvailable=min(existing,quantity) on save. Both verified.
DEFERRED to next cycle (final-review triage = OK to defer): TOCTOU adjustStock; liveAvailable guard (non-issue); SGDFTextField for note; seuil/unit in-memory on type switch; redundant accessibilityLabel; status-vs-availability after +adjust on checked_out item (by design).
=== STOCK MANAGEMENT (cycle 1/3) CODE COMPLETE — branch feature/stock-management ready; pending: user runs 20260701_stock_management.sql + runtime smoke test ===

=== PLAN: Dashboard Alerts + Sorties (cycle 2/3) — branch feature/dashboard-alerts-sorties ===
Plan: docs/superpowers/plans/2026-06-30-dashboard-alerts-sorties.md
Base SHA: e4728ee (plan commit). Subagent-driven execution starting.
C2-Task 1: complete (commits e4728ee..51f4b6f, review clean — Spec OK, Quality approved). Both schemes build.
  Minor (deferred): cutoff fallback to Date() if calendar arithmetic fails (negligible); per-call service allocation (matches project pattern).
C2-Task 2: complete (commits 51f4b6f..2fe04b6, review clean — Spec OK, Quality approved).
  Minor (no action): isLoading=false after do/catch rather than defer (functionally correct).
C2-Task 3: complete (commits 2fe04b6..cbe1ce9, review clean — Spec OK, Quality approved).
  Minor (no action): AlertCard struct placed before StatCard rather than after (cosmetic ordering, no functional impact).
C2-Task 4: complete (commits cbe1ce9..4f5aae9, review clean — Spec OK, Quality approved).
  Minor (no action): badges are colored text not pill capsules (spec-prescribed); revisit later.
C2-Task 5: complete (commits 4f5aae9..2b24543, review clean — Spec OK, Quality approved, 0 findings).
=== ALL 5 C2 TASKS COMPLETE — launching final whole-branch review ===
FINAL REVIEW (opus): READY TO MERGE — 0 Critical / 0 Important.
  New Minor (deferred): M-A stale alert list/counts after in-detail action until pull-to-refresh; M-B N+1 (lines per checkout + items per camp) harmless at scout-group scale.
  5 known minors: all DEFER (cutoff fallback, per-call service alloc, isLoading vs defer, AlertCard ordering, colored-text badges).

=== PLAN: Inventaire Rapide (cycle 3/3) — branch feature/inventaire-rapide ===
Plan: docs/superpowers/plans/2026-06-30-inventaire-rapide.md
Base SHA: b18de50 (plan commit). Subagent-driven execution starting.
C3-Task 1: complete (commits b18de50..59350c3, review clean — Spec OK, Quality approved). Both schemes build. `in` backticked.
  Minor (deferred): ISO8601DateFormatter() allocated per markChecked call (infrequent path; could be static).
C3-Task 2: complete (commits 59350c3..c84f782, review clean — Spec OK, Quality approved). File verified in ScoutInventory Sources build phase.
  Minor (deferred): loadReferentials() swallows single-source failure (error only if BOTH nil); resolve() unstructured Task -> scanMessage last-wins on concurrent scans.
C3-Task 3: complete (commits c84f782..9581cce, review clean — Spec OK, Quality approved). File in Sources phase; no camera; color-clean.
  Minor (no action): summaryRow uses .system(.title3,design:.rounded) like existing StatCard/AlertCard big-number pattern; SGDFTheme has no such token.
C3-Task 4: complete (commits 9581cce..c71d341, review clean — Spec OK, Quality approved, 0 findings).
=== ALL 4 C3 TASKS COMPLETE — launching final whole-branch review ===
FINAL REVIEW (opus): READY TO MERGE — 0 Critical / 0 Important.
  Fix commit 9fc3946 (both schemes build): removed dead InventoryScope enum; loadReferentials guard && -> || (surface single-source failure).
  Deferred minors: ISO8601 formatter per call; resolve() concurrent-task scanMessage last-wins; summaryRow .system font (matches StatCard pattern); archived item scanned shows as en-trop.
=== INVENTAIRE RAPIDE (cycle 3/3) READY — merging to main ===

=== PLAN: Catégories/sous-catégories, codes auto, vignettes — branch feature/categories-subcategories-codes ===
Plan: docs/superpowers/plans/2026-06-30-categories-subcategories-codes.md
Base SHA: 63bb643 (plan commit). Subagent-driven execution starting.
C4-Task 1: complete (commits 63bb643..573f242, review clean — Spec OK, Quality approved). SQL-only, additive+idempotent.
  Minor (deferred): code could contain regex metachar (admin-controlled, TEN/CUI safe); lpad(4) overflows at seq>=9999 (won't reach at scout scale); no explicit GRANT EXECUTE (Supabase grants PUBLIC by default).
C4-Task 2: complete (commits 573f242..126d1e9, review clean — Spec OK, Quality approved, 0 findings). Both schemes build.
C4-Task 3: complete (commits 126d1e9..d534d81, review clean — Spec OK, Quality approved, 0 findings). Both schemes build.
C4-Task 4: complete (commits d534d81..f188a44, review clean — Spec OK, Quality approved). Both schemes build.
  Minor (deferred, anticipated by brief): qrError @State + .alert in MaterialDetailView now unreachable (no failure mode); ScanResolution.unassigned/.disabled now dead return paths (enum kept intact per plan).
C4-Task 5: complete (commits f188a44..3089502, review clean — Spec OK, Quality approved). Both schemes build. Manual sim check deferred to QA.
  Minor (deferred, brief-mandated): loadReferentials surfaces error only if BOTH cats+locs nil; silent subcategory load failure gives no feedback.
C4-Task 6: complete (commits 3089502..4271eb4, review clean — Spec OK, Quality approved). Both schemes build. Manual sim check deferred to QA.
  Minor (deferred): MaterialRow instantiates ImageStorageService() per body eval (stateless URL builder, matches MaterialDetailView pattern; negligible).
=== ALL 6 C4 TASKS COMPLETE — launching final whole-branch review ===
FINAL REVIEW (opus): 0 Critical, 3 Important, 2 Minor.
  Fix commit df2d988 (both schemes build): (1) dropped always-true missingQR dashboard alert (+removed assignedItemIds round-trip); (2) DB CHECK categories.code ~ ^[A-Z]{2,4}$; (3) partial unique index on inventory_items(inventory_code) for ^[A-Z]{2,4}-[0-9]{4}$ (excludes legacy TAG-).
  Deferred minors: qrError/.alert + ScanResolution.unassigned/.disabled dead-but-inert; per-row ImageStorageService() alloc.
=== C4 FEATURE COMPLETE — branch feature/categories-subcategories-codes ready ===
C4-tweak: thumbnail leading inset reduced (photo hugs left). Both schemes build.

=== PLAN: Gestion catégories/sous-catégories — branch feature/category-management ===
Plan: docs/superpowers/plans/2026-06-30-category-management.md
Base SHA: 3d0abf1 (plan commit). Subagent-driven execution starting.
C5-Task 1: complete (commits 3d0abf1..a640250, review clean — Spec OK, Quality approved, 0 findings). Both schemes build. CategoryService CRUD+itemCount.
C5-Task 2: complete (commits a640250..2e4e1af, review clean — Spec OK, Quality approved). Both schemes build. VM in ScoutInventory target (grep=2 normal). [retry after transient API overload killed first attempt — clean re-dispatch]
  Minor (deferred): load() does N+1 itemCount queries (one per category); fine at scout scale.
C5-Task 3: complete (commits 2e4e1af..b939490, review clean — Spec OK, Quality approved). Both schemes build. View in target (grep=2).
  Minor (deferred, flag final review): two chained .alert modifiers on same view could shadow on iOS <16.4; alerts are mutually exclusive so low risk on iOS 16+.
C5-Task 4: complete (commits b939490..8f87e2d, review clean — Spec OK, Quality approved, 0 findings). Both schemes build. SessionStore injection confirmed at app root. Manual QA deferred.
  Note (out of scope): existing "+" add-item button is unconditional (viewer can add items) — pre-existing pattern, not introduced here.
=== ALL 4 C5 TASKS COMPLETE — launching final whole-branch review ===
FINAL REVIEW (opus): 0 Critical, 1 Important. All deferred-minor checks verified clean (FK on delete cascade/set null confirmed; code-lock solid; UI/DB regex agree; null grouping safe; iOS target 17 so dual-alert fine).
  Fix commit f463caa (both schemes build): added .confirmationDialog before deleting category (with N-objets-détachés count) and subcategory — spec §2/§4 compliance.
=== C5 FEATURE COMPLETE — merging to main + pushing to GitHub ===

=== PLAN: Sélection multiple + déplacement matériel — branch feature/multi-select-move-material ===
Plan: docs/superpowers/plans/2026-06-30-multi-select-move-material.md
Base SHA: 7435a3e (plan commit). Subagent-driven execution starting.
Task 1: complete (commits 7435a3e..05a3e3f, review clean — Spec OK, Quality approved, 0 findings). Build OK. ItemService.move + MovePayload (explicit null encode).
Task 2: complete (commits 05a3e3f..f5e4bce, review clean — Spec OK, Quality approved). Build OK. VM.move returns error string (does not touch errorMessage), reloads on success.
Task 3: complete (commits f5e4bce..f80067d, review clean — Spec OK, Quality approved). Build OK. Selection mode + MoveItemsSheet in MaterialListView, local alert, canWrite-gated. Manual QA deferred.
  Minor (deferred, flag final review): checkmark uses primaryBlue (overloaded token) — cosmetic only.
=== ALL 3 TASKS COMPLETE — launching final whole-branch review ===
FINAL REVIEW (opus): 0 Critical, 0 Important, 4 Minor (polish). Merge-ready.
Toolbar reorg (user request, build OK, simulator-verified): collapsed secondary actions into a ••• menu (Sélectionner / Organiser); move action "Déplacer (N)" moved from .bottomBar (was hidden behind TabView tab bar — bug) to topBarTrailing; selection mode shows Annuler + "N sélectionné(s)" principal + Déplacer (N). Menu gated canWrite.
