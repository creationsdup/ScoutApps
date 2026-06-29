-- ScoutManager — MVP-1 : extension de schéma (stratégie « étendre l'existant »)
-- ============================================================================
-- À EXÉCUTER dans le SQL editor Supabase, APRÈS RELECTURE.
-- Conçu idempotent (réexécutable) : IF NOT EXISTS + drop/create pour les policies.
-- Ne crée PAS de nouvelles tables items/qr_codes : on réutilise inventory_items,
-- qr_tags, item_movements, events existantes. On ajoute categories + locations,
-- on enrichit inventory_items, et on convertit les valeurs de statut/état vers la
-- charte ScoutManager.
--
-- ⚠️ Les sections 3 et 4 MODIFIENT des données existantes (valeurs status/condition).
--    Relis-les avant exécution.
-- ⚠️ Les policies RLS (section 6/7) supposent une table public.profiles(id, role)
--    avec role ∈ admin/manager/member/viewer (cf. ton schéma actuel). Aligne-les
--    sur tes politiques existantes si besoin.
-- ============================================================================

-- 1. Tables de référence -----------------------------------------------------
create table if not exists public.categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.locations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

-- 2. Enrichissement de inventory_items (colonnes additives, nullables) --------
alter table public.inventory_items
  add column if not exists category_id        uuid references public.categories(id) on delete set null,
  add column if not exists location_id        uuid references public.locations(id)  on delete set null,
  add column if not exists tracking_type      text not null default 'specifique',
  add column if not exists quantity_available integer,
  add column if not exists branch             text,
  add column if not exists image_path         text,
  add column if not exists event_id           uuid references public.events(id) on delete set null,
  add column if not exists last_checked_at    timestamptz;

-- quantity_available initialisé depuis quantity (total) si nul
update public.inventory_items
   set quantity_available = quantity
 where quantity_available is null;

-- 3. Conversion des STATUTS vers la charte ScoutManager ----------------------
--    available/checked_out/cleaning_required/repair_required/missing/archived
update public.inventory_items
   set status = case status
       when 'available'         then 'disponible'
       when 'checked_out'       then 'sorti'
       when 'cleaning_required' then 'a_verifier'
       when 'repair_required'   then 'a_reparer'
       when 'missing'           then 'perdu'
       when 'archived'          then 'archive'
       else status
     end
 where status in ('available','checked_out','cleaning_required','repair_required','missing','archived');

-- 4. Conversion des ÉTATS (condition) ----------------------------------------
--    excellent/good/fair/damaged/broken  →  neuf/bon/moyen/mauvais
update public.inventory_items
   set condition = case condition
       when 'excellent' then 'neuf'
       when 'good'      then 'bon'
       when 'fair'      then 'moyen'
       when 'damaged'   then 'mauvais'
       when 'broken'    then 'mauvais'
       else condition
     end
 where condition in ('excellent','good','fair','damaged','broken');

-- 5. Contraintes de validation (NOT VALID : n'invalide pas l'existant) --------
alter table public.inventory_items drop constraint if exists inventory_items_tracking_type_chk;
alter table public.inventory_items
  add constraint inventory_items_tracking_type_chk
  check (tracking_type in ('global','specifique')) not valid;

alter table public.inventory_items drop constraint if exists inventory_items_branch_chk;
alter table public.inventory_items
  add constraint inventory_items_branch_chk
  check (branch is null or branch in ('LJ','SG','PC','Groupe')) not valid;
-- Après vérif des données, tu peux valider :
--   alter table public.inventory_items validate constraint inventory_items_tracking_type_chk;
--   alter table public.inventory_items validate constraint inventory_items_branch_chk;

-- 6. RLS sur les nouvelles tables (À ALIGNER sur tes politiques existantes) ---
alter table public.categories enable row level security;
alter table public.locations  enable row level security;

drop policy if exists categories_select_auth on public.categories;
create policy categories_select_auth on public.categories
  for select to authenticated using (true);

drop policy if exists locations_select_auth on public.locations;
create policy locations_select_auth on public.locations
  for select to authenticated using (true);

-- Écriture réservée aux rôles autorisés (miroir de can_write_inventory)
drop policy if exists categories_write_roles on public.categories;
create policy categories_write_roles on public.categories
  for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

drop policy if exists locations_write_roles on public.locations;
create policy locations_write_roles on public.locations
  for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- 7. Bucket Storage des images de matériel -----------------------------------
insert into storage.buckets (id, name, public)
  values ('item-images', 'item-images', true)
  on conflict (id) do nothing;

drop policy if exists item_images_read   on storage.objects;
create policy item_images_read on storage.objects
  for select using (bucket_id = 'item-images');

drop policy if exists item_images_insert on storage.objects;
create policy item_images_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'item-images');

drop policy if exists item_images_update on storage.objects;
create policy item_images_update on storage.objects
  for update to authenticated using (bucket_id = 'item-images');
