-- ScoutManager — Catégories : code de préfixe, sous-catégories, codes inventaire auto.
-- À EXÉCUTER dans le SQL editor Supabase, APRÈS RELECTURE.
-- ADDITIF UNIQUEMENT (backend partagé avec CampManager). Idempotent.
-- ============================================================================

-- 1. Code de catégorie (préfixe de tag), additif & nullable -------------------
alter table public.categories
  add column if not exists code text;

-- Unicité insensible à la casse sur les codes renseignés
create unique index if not exists categories_code_key
  on public.categories (upper(code)) where code is not null;

-- Le code doit être 2 à 4 lettres majuscules (préfixe de tag scannable)
alter table public.categories drop constraint if exists categories_code_format_chk;
alter table public.categories
  add constraint categories_code_format_chk
  check (code is null or code ~ '^[A-Z]{2,4}$');

-- 2. Sous-catégories (niveau 2) ----------------------------------------------
create table if not exists public.subcategories (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now()
);

-- 3. Lien item -> sous-catégorie (nullable) ----------------------------------
alter table public.inventory_items
  add column if not exists subcategory_id uuid references public.subcategories(id) on delete set null;

-- 4. RLS sous-catégories : lecture authentifiée, écriture admin/manager/member
alter table public.subcategories enable row level security;

drop policy if exists subcategories_select_auth on public.subcategories;
create policy subcategories_select_auth on public.subcategories
  for select to authenticated using (true);

drop policy if exists subcategories_write_roles on public.subcategories;
create policy subcategories_write_roles on public.subcategories
  for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- 5. Génération atomique du prochain code inventaire pour une catégorie -------
create or replace function public.next_inventory_code(p_category_id uuid)
returns text
language plpgsql
as $$
declare
  v_code text;
  v_seq  int;
begin
  select upper(code) into v_code from public.categories where id = p_category_id;
  if v_code is null then
    raise exception 'Catégorie % sans code', p_category_id;
  end if;
  -- verrou par catégorie (durée transaction) pour éviter les collisions
  perform pg_advisory_xact_lock(hashtext(v_code));
  select coalesce(max(
           (regexp_replace(inventory_code, '^' || v_code || '-', ''))::int
         ), 0) + 1
    into v_seq
    from public.inventory_items
   where inventory_code ~ ('^' || v_code || '-[0-9]+$');
  return v_code || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

-- Garde-fou d'unicité sur les codes générés (format PRÉFIXE-NNNN, 4 chiffres).
-- Exclut volontairement les anciens codes TAG-000000 (6 chiffres).
create unique index if not exists inventory_items_inventory_code_key
  on public.inventory_items (inventory_code)
  where inventory_code ~ '^[A-Z]{2,4}-[0-9]{4}$';

-- 6. Seed d'exemple (à adapter / remplacer par tes vraies catégories) ---------
-- Décommente et ajuste si tu veux des données de démo :
-- insert into public.categories (name, code) values ('Tentes', 'TEN')
--   on conflict do nothing;
-- insert into public.categories (name, code) values ('Cuisine', 'CUI')
--   on conflict do nothing;
