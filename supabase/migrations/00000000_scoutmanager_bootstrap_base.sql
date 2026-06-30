-- ScoutManager — SOCLE / BOOTSTRAP (pour un projet Supabase VIERGE et dédié)
-- ============================================================================
-- À EXÉCUTER EN PREMIER, avant 20260629_scoutmanager_mvp1.sql puis
-- 20260630_scoutmanager_phase2_all.sql.
--
-- Recrée le socle que le backend CampManager fournissait (et que les autres
-- migrations supposent déjà présent) : enums item_status/condition, et les tables
-- profiles, events, inventory_items (colonnes de base), qr_tags, item_movements.
-- Reconstitué à partir des modèles Swift de l'app. Idempotent.
--
-- ⚠️ N'exécute PAS ça sur une base contenant déjà une autre application.
-- ============================================================================

-- 1) Enums --------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'item_status') then
    create type public.item_status as enum
      ('available','reserve','checked_out','cleaning_required','repair_required','indisponible','missing','archived');
  end if;
  if not exists (select 1 from pg_type where typname = 'condition') then
    create type public.condition as enum ('excellent','good','fair','damaged','broken');
  end if;
end $$;

-- 2) profiles (id = utilisateur auth ; role pilote canWrite/RLS) ---------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  role       text not null default 'viewer',
  created_at timestamptz not null default now()
);
alter table public.profiles drop constraint if exists profiles_role_chk;
alter table public.profiles add constraint profiles_role_chk
  check (role in ('admin','manager','member','viewer')) not valid;

alter table public.profiles enable row level security;
drop policy if exists profiles_select_auth on public.profiles;
create policy profiles_select_auth on public.profiles for select to authenticated using (true);
drop policy if exists profiles_self_write on public.profiles;
create policy profiles_self_write on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- NB (base PARTAGÉE avec une autre app) : on n'ajoute PAS de trigger sur auth.users
-- (un trigger/fonction `handle_new_user` y existe sûrement déjà — on ne l'écrase pas).
-- Crée ton profil scout à la main après login (cf. bas de fichier).

-- 3) events (l'app n'en référence que l'id — pont optionnel) -------------------
create table if not exists public.events (
  id         uuid primary key default gen_random_uuid(),
  name       text,
  created_at timestamptz not null default now()
);
alter table public.events enable row level security;
drop policy if exists events_select_auth on public.events;
create policy events_select_auth on public.events for select to authenticated using (true);
drop policy if exists events_write_roles on public.events;
create policy events_write_roles on public.events for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- 4) inventory_items (COLONNES DE BASE ; MVP-1 ajoutera category_id, location_id,
--    tracking_type, quantity_available, branch, image_path, event_id, last_checked_at) -
create table if not exists public.inventory_items (
  id             uuid primary key default gen_random_uuid(),
  inventory_code text not null,
  name           text not null,
  description    text,
  quantity       integer not null default 1,
  status         public.item_status not null default 'available',
  condition      public.condition  not null default 'good',
  created_at     timestamptz not null default now()
);
alter table public.inventory_items enable row level security;
drop policy if exists inventory_items_select_auth on public.inventory_items;
create policy inventory_items_select_auth on public.inventory_items for select to authenticated using (true);
drop policy if exists inventory_items_write_roles on public.inventory_items;
create policy inventory_items_write_roles on public.inventory_items for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- 5) qr_tags (étiquettes QR) --------------------------------------------------
create table if not exists public.qr_tags (
  id               uuid primary key default gen_random_uuid(),
  tag_code         text not null unique,
  status           text not null default 'unassigned',
  assigned_item_id uuid references public.inventory_items(id) on delete set null,
  created_at       timestamptz not null default now()
);
alter table public.qr_tags drop constraint if exists qr_tags_status_chk;
alter table public.qr_tags add constraint qr_tags_status_chk
  check (status in ('unassigned','assigned','disabled')) not valid;
alter table public.qr_tags enable row level security;
drop policy if exists qr_tags_select_auth on public.qr_tags;
create policy qr_tags_select_auth on public.qr_tags for select to authenticated using (true);
drop policy if exists qr_tags_write_roles on public.qr_tags;
create policy qr_tags_write_roles on public.qr_tags for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- 6) item_movements (journal des mouvements) ----------------------------------
create table if not exists public.item_movements (
  id         uuid primary key default gen_random_uuid(),
  item_id    uuid not null references public.inventory_items(id) on delete cascade,
  action     text not null,
  user_id    uuid,
  event_id   uuid references public.events(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.item_movements enable row level security;
drop policy if exists item_movements_select_auth on public.item_movements;
create policy item_movements_select_auth on public.item_movements for select to authenticated using (true);
drop policy if exists item_movements_write_roles on public.item_movements;
create policy item_movements_write_roles on public.item_movements for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- ============================================================================
-- APRÈS ce socle : exécuter 20260629_scoutmanager_mvp1.sql puis
-- 20260630_scoutmanager_phase2_all.sql.
--
-- Après avoir créé ton compte (Authentication > Users, ou login dans l'app), crée
-- ton profil scout avec le rôle admin. Remplace <TON_UUID> par ton id utilisateur
-- (Authentication > Users > copie l'UID) :
--   insert into public.profiles (id, role) values ('<TON_UUID>', 'admin')
--     on conflict (id) do update set role = 'admin';
-- ============================================================================
