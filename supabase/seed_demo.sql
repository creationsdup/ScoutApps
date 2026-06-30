-- ScoutManager — Jeu de données de DÉMO (à exécuter dans le SQL editor Supabase
-- APRÈS les 3 migrations). Idempotent (UUID fixes + on conflict do nothing).
-- Pour repartir propre : delete from public.qr_tags; delete from public.inventory_items;
--                        delete from public.locations; delete from public.categories;
-- ============================================================================

-- Catégories ------------------------------------------------------------------
insert into public.categories (id, name) values
  ('11111111-0000-0000-0000-000000000001', 'Tentes'),
  ('11111111-0000-0000-0000-000000000002', 'Cuisine'),
  ('11111111-0000-0000-0000-000000000003', 'Couchage'),
  ('11111111-0000-0000-0000-000000000004', 'Outils')
on conflict (id) do nothing;

-- Lieux -----------------------------------------------------------------------
insert into public.locations (id, name) values
  ('22222222-0000-0000-0000-000000000001', 'Local'),
  ('22222222-0000-0000-0000-000000000002', 'Cave'),
  ('22222222-0000-0000-0000-000000000003', 'Remorque'),
  ('22222222-0000-0000-0000-000000000004', 'Étagère A')
on conflict (id) do nothing;

-- Matériel --------------------------------------------------------------------
-- 5 spécifiques (quantité 1) + 1 GLOBAL « Gamelles » (quantité 20) pour tester
-- le panier de quantités. status='available', condition='good'.
insert into public.inventory_items
  (id, inventory_code, name, description, category_id, location_id,
   tracking_type, quantity, quantity_available, status, condition, branch)
values
  ('33333333-0000-0000-0000-000000000001', 'TENTE-01', 'Tente 4 places', 'Tente patrouille',
   '11111111-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001',
   'specifique', 1, 1, 'available', 'good', 'SG'),
  ('33333333-0000-0000-0000-000000000002', 'RECHAUD-01', 'Réchaud à gaz', 'Réchaud 2 feux',
   '11111111-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000003',
   'specifique', 1, 1, 'available', 'good', 'Groupe'),
  ('33333333-0000-0000-0000-000000000003', 'GAMELLE-LOT', 'Gamelles inox', 'Lot de gamelles',
   '11111111-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000001',
   'global', 20, 20, 'available', 'good', 'Groupe'),
  ('33333333-0000-0000-0000-000000000004', 'SACDUVET-01', 'Sac de couchage', '-5°C',
   '11111111-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000004',
   'specifique', 1, 1, 'available', 'good', 'LJ'),
  ('33333333-0000-0000-0000-000000000005', 'HACHE-01', 'Hache', 'Hache de bûcheronnage',
   '11111111-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000002',
   'specifique', 1, 1, 'available', 'fair', 'PC'),
  ('33333333-0000-0000-0000-000000000006', 'BACHE-01', 'Bâche', 'Bâche 4x6m',
   '11111111-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000003',
   'specifique', 1, 1, 'available', 'good', 'Groupe')
on conflict (id) do nothing;

-- Tags QR ---------------------------------------------------------------------
-- TAG-000001 associé à la Tente (test Scan -> fiche) ; les 2 autres vierges.
insert into public.qr_tags (id, tag_code, status, assigned_item_id) values
  ('44444444-0000-0000-0000-000000000001', 'TAG-000001', 'assigned',
   '33333333-0000-0000-0000-000000000001'),
  ('44444444-0000-0000-0000-000000000002', 'TAG-000002', 'unassigned', null),
  ('44444444-0000-0000-0000-000000000003', 'TAG-000003', 'unassigned', null)
on conflict (tag_code) do nothing;
