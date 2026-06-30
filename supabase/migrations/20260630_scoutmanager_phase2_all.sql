-- ============================================================================
-- ScoutManager — Phase 2 : migration COMBINÉE (Intendance + Programme + RPC)
-- ============================================================================
-- À EXÉCUTER EN UNE FOIS dans le SQL editor Supabase.
--
-- Regroupe, dans le bon ordre de dépendances, les 3 migrations de la phase 2 :
--   1) Camp & Intendance  (camps, meals, meal_recipes, recipes, recipe_ingredients,
--                          shopping_items, expenses, food_stock, food_traceability)
--   2) Programme de camp   (activities, program_slots, program_slot_materials)
--   3) RPC transactionnelle de génération de la liste de courses
--
-- ADDITIF UNIQUEMENT — backend partagé avec CampManager : aucune table/colonne/enum
-- existant n'est modifié. Idempotent (create … if not exists / drop+create policy /
-- add constraint … not valid) : réexécutable sans erreur.
--
-- Sécurité : RLS activée sur chaque nouvelle table, select pour `authenticated`,
-- écriture réservée aux rôles admin/manager/member (miroir de `canWrite` côté app).
-- ============================================================================


-- ############################################################################
-- # PARTIE 1 — CAMP & INTENDANCE
-- ############################################################################

-- ---- Socle : table camps (pivot) ------------------------------------------
create table if not exists public.camps (
  id                 uuid primary key default gen_random_uuid(),
  event_id           uuid references public.events(id) on delete set null,
  name               text not null,
  location           text,
  start_date         date,
  end_date           date,
  branch             text,
  participants_count integer,
  encadrants_count   integer,
  created_by         uuid,
  created_at         timestamptz not null default now()
);

alter table public.camps drop constraint if exists camps_branch_chk;
alter table public.camps
  add constraint camps_branch_chk
  check (branch is null or branch in ('LJ','SG','PC','Groupe')) not valid;

alter table public.camps enable row level security;

drop policy if exists camps_select_auth on public.camps;
create policy camps_select_auth on public.camps
  for select to authenticated using (true);

drop policy if exists camps_write_roles on public.camps;
create policy camps_write_roles on public.camps
  for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- ---- Menus : meals + meal_recipes -----------------------------------------
create table if not exists public.meals (
  id         uuid primary key default gen_random_uuid(),
  camp_id    uuid not null references public.camps(id) on delete cascade,
  date       date not null,
  slot       text not null,
  title      text,
  notes      text,
  created_at timestamptz not null default now(),
  unique (camp_id, date, slot)
);

alter table public.meals drop constraint if exists meals_slot_chk;
alter table public.meals
  add constraint meals_slot_chk
  check (slot in ('petit_dej','midi','gouter','diner')) not valid;

-- Lien N-N repas <-> recettes (sans FK vers recipes pour ne pas dépendre de l'ordre).
create table if not exists public.meal_recipes (
  meal_id    uuid not null references public.meals(id) on delete cascade,
  recipe_id  uuid not null,
  primary key (meal_id, recipe_id)
);

alter table public.meals       enable row level security;
alter table public.meal_recipes enable row level security;

drop policy if exists meals_select_auth on public.meals;
create policy meals_select_auth on public.meals for select to authenticated using (true);
drop policy if exists meals_write_roles on public.meals;
create policy meals_write_roles on public.meals for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

drop policy if exists meal_recipes_select_auth on public.meal_recipes;
create policy meal_recipes_select_auth on public.meal_recipes for select to authenticated using (true);
drop policy if exists meal_recipes_write_roles on public.meal_recipes;
create policy meal_recipes_write_roles on public.meal_recipes for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- ---- Recettes : recipes + recipe_ingredients (bibliothèque, non liée camp) -
create table if not exists public.recipes (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  servings_base integer not null default 1,
  instructions  text,
  branch        text,
  created_at    timestamptz not null default now()
);

alter table public.recipes drop constraint if exists recipes_branch_chk;
alter table public.recipes
  add constraint recipes_branch_chk
  check (branch is null or branch in ('LJ','SG','PC','Groupe')) not valid;

create table if not exists public.recipe_ingredients (
  id         uuid primary key default gen_random_uuid(),
  recipe_id  uuid not null references public.recipes(id) on delete cascade,
  name       text not null,
  quantity   numeric,
  unit       text,
  created_at timestamptz not null default now()
);

alter table public.recipes            enable row level security;
alter table public.recipe_ingredients enable row level security;

drop policy if exists recipes_select_auth on public.recipes;
create policy recipes_select_auth on public.recipes for select to authenticated using (true);
drop policy if exists recipes_write_roles on public.recipes;
create policy recipes_write_roles on public.recipes for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

drop policy if exists recipe_ingredients_select_auth on public.recipe_ingredients;
create policy recipe_ingredients_select_auth on public.recipe_ingredients for select to authenticated using (true);
drop policy if exists recipe_ingredients_write_roles on public.recipe_ingredients;
create policy recipe_ingredients_write_roles on public.recipe_ingredients for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- ---- Liste de courses : shopping_items ------------------------------------
create table if not exists public.shopping_items (
  id         uuid primary key default gen_random_uuid(),
  camp_id    uuid not null references public.camps(id) on delete cascade,
  name       text not null,
  quantity   numeric,
  unit       text,
  checked    boolean not null default false,
  source     text not null default 'manual',
  created_at timestamptz not null default now()
);

alter table public.shopping_items drop constraint if exists shopping_items_source_chk;
alter table public.shopping_items
  add constraint shopping_items_source_chk
  check (source in ('auto','manual')) not valid;

alter table public.shopping_items enable row level security;

drop policy if exists shopping_items_select_auth on public.shopping_items;
create policy shopping_items_select_auth on public.shopping_items for select to authenticated using (true);
drop policy if exists shopping_items_write_roles on public.shopping_items;
create policy shopping_items_write_roles on public.shopping_items for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- ---- Budget : expenses ----------------------------------------------------
create table if not exists public.expenses (
  id             uuid primary key default gen_random_uuid(),
  camp_id        uuid not null references public.camps(id) on delete cascade,
  label          text not null,
  category       text,
  amount_planned numeric,
  amount_real    numeric,
  created_at     timestamptz not null default now()
);

alter table public.expenses drop constraint if exists expenses_category_chk;
alter table public.expenses
  add constraint expenses_category_chk
  check (category is null or category in ('alimentaire','materiel','transport','autre')) not valid;

alter table public.expenses enable row level security;

drop policy if exists expenses_select_auth on public.expenses;
create policy expenses_select_auth on public.expenses for select to authenticated using (true);
drop policy if exists expenses_write_roles on public.expenses;
create policy expenses_write_roles on public.expenses for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- ---- Stock / réserve alimentaire : food_stock -----------------------------
create table if not exists public.food_stock (
  id          uuid primary key default gen_random_uuid(),
  camp_id     uuid not null references public.camps(id) on delete cascade,
  name        text not null,
  quantity    numeric,
  unit        text,
  expiry_date date,
  location    text,
  created_at  timestamptz not null default now()
);

alter table public.food_stock enable row level security;

drop policy if exists food_stock_select_auth on public.food_stock;
create policy food_stock_select_auth on public.food_stock for select to authenticated using (true);
drop policy if exists food_stock_write_roles on public.food_stock;
create policy food_stock_write_roles on public.food_stock for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- ---- Registre de traçabilité : food_traceability --------------------------
create table if not exists public.food_traceability (
  id            uuid primary key default gen_random_uuid(),
  camp_id       uuid not null references public.camps(id) on delete cascade,
  product_name  text not null,
  brand         text,
  supplier      text,
  lot_number    text,
  barcode       text,
  quantity      numeric,
  received_date date,
  expiry_date   date,
  meal_id       uuid references public.meals(id) on delete set null,
  photo_path    text,
  created_at    timestamptz not null default now()
);

alter table public.food_traceability enable row level security;

drop policy if exists food_traceability_select_auth on public.food_traceability;
create policy food_traceability_select_auth on public.food_traceability for select to authenticated using (true);
drop policy if exists food_traceability_write_roles on public.food_traceability;
create policy food_traceability_write_roles on public.food_traceability for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));


-- ############################################################################
-- # PARTIE 2 — PROGRAMME DE CAMP
-- ############################################################################

-- activities : bibliothèque réutilisable, NON liée à un camp
create table if not exists public.activities (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  type          text,
  duration_min  integer,
  description    text,
  branch        text,
  material_notes text,
  created_at    timestamptz not null default now()
);
alter table public.activities drop constraint if exists activities_type_chk;
alter table public.activities add constraint activities_type_chk
  check (type is null or type in ('jeu','grand_jeu','veillee','temps_spi','atelier','autre')) not valid;
alter table public.activities drop constraint if exists activities_branch_chk;
alter table public.activities add constraint activities_branch_chk
  check (branch is null or branch in ('LJ','SG','PC','Groupe')) not valid;

-- program_slots : créneaux du planning d'un camp
create table if not exists public.program_slots (
  id          uuid primary key default gen_random_uuid(),
  camp_id     uuid not null references public.camps(id) on delete cascade,
  date        date not null,
  start_time  time,
  end_time    time,
  title       text not null,
  activity_id uuid references public.activities(id) on delete set null,
  location    text,
  notes       text,
  created_at  timestamptz not null default now()
);

-- program_slot_materials : lien créneau <-> matériel d'inventaire (jointure additive)
create table if not exists public.program_slot_materials (
  slot_id           uuid not null references public.program_slots(id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items(id) on delete cascade,
  primary key (slot_id, inventory_item_id)
);

alter table public.activities             enable row level security;
alter table public.program_slots          enable row level security;
alter table public.program_slot_materials enable row level security;

drop policy if exists activities_select_auth on public.activities;
create policy activities_select_auth on public.activities
  for select to authenticated using (true);
drop policy if exists activities_write_roles on public.activities;
create policy activities_write_roles on public.activities
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

drop policy if exists program_slots_select_auth on public.program_slots;
create policy program_slots_select_auth on public.program_slots
  for select to authenticated using (true);
drop policy if exists program_slots_write_roles on public.program_slots;
create policy program_slots_write_roles on public.program_slots
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

drop policy if exists program_slot_materials_select_auth on public.program_slot_materials;
create policy program_slot_materials_select_auth on public.program_slot_materials
  for select to authenticated using (true);
drop policy if exists program_slot_materials_write_roles on public.program_slot_materials;
create policy program_slot_materials_write_roles on public.program_slot_materials
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));


-- ############################################################################
-- # PARTIE 3 — RPC TRANSACTIONNELLE : génération de la liste de courses
-- ############################################################################
-- Le corps s'exécute dans une seule transaction implicite : le DELETE des lignes
-- `auto` et le réINSERT sont atomiques. `security invoker` => la RLS de
-- shopping_items s'applique (un viewer reçoit une erreur, miroir de canWrite).
-- Sémantique : occurrences (repas × recette) ; facteur = ceil(participants /
-- max(1, servings_base)) par recette ; agrégation par (nom insensible casse, unité) ;
-- quantité NULL si aucune occurrence n'a de quantité ; lignes `manual` préservées.

create or replace function public.regenerate_shopping_auto(p_camp_id uuid)
returns void
language plpgsql
security invoker
as $$
declare
  v_participants integer;
begin
  -- Effectif du camp (plancher 1). Si le camp n'existe pas / pas d'accès : no-op.
  select greatest(1, coalesce(participants_count, 1))
    into v_participants
    from public.camps
   where id = p_camp_id;

  if not found then
    return;
  end if;

  -- Remplace atomiquement les lignes générées ; les lignes manuelles restent.
  delete from public.shopping_items
   where camp_id = p_camp_id
     and source = 'auto';

  insert into public.shopping_items (camp_id, name, quantity, unit, checked, source)
  select p_camp_id,
         min(ri.name)                                              as name,
         case when bool_or(ri.quantity is not null)
              then sum(coalesce(ri.quantity, 0)
                       * ceil(v_participants::numeric / greatest(1, r.servings_base)))
              else null
         end                                                       as quantity,
         ri.unit                                                   as unit,
         false                                                     as checked,
         'auto'                                                    as source
    from public.meals m
    join public.meal_recipes mr       on mr.meal_id   = m.id
    join public.recipes r             on r.id         = mr.recipe_id
    join public.recipe_ingredients ri on ri.recipe_id = r.id
   where m.camp_id = p_camp_id
   group by lower(ri.name), ri.unit;
end;
$$;

grant execute on function public.regenerate_shopping_auto(uuid) to authenticated;


-- ############################################################################
-- # PARTIE 4 — FLUX MATÉRIEL PARTAGÉ camp <-> inventaire
-- ############################################################################
-- camp_materials = liste de chargement matériel d'un camp (item entier). Les RPC
-- font 3 écritures (chargement + statut + mouvement) dans UNE transaction
-- (security invoker => RLS appliquée).
--   * 'checked_out' / 'available' = rawValues DB de ItemStatus.sorti / .disponible
--   * 'checkout' / 'return'       = MovementAction (item_movements.action)

create table if not exists public.camp_materials (
  camp_id            uuid not null references public.camps(id) on delete cascade,
  inventory_item_id  uuid not null references public.inventory_items(id) on delete cascade,
  added_by           uuid,
  added_at           timestamptz not null default now(),
  primary key (camp_id, inventory_item_id)
);

alter table public.camp_materials enable row level security;

drop policy if exists camp_materials_select_auth on public.camp_materials;
create policy camp_materials_select_auth on public.camp_materials
  for select to authenticated using (true);

drop policy if exists camp_materials_write_roles on public.camp_materials;
create policy camp_materials_write_roles on public.camp_materials
  for all to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')));

-- Assignation : ajoute au chargement, passe l'item 'sorti', journalise un checkout.
create or replace function public.assign_material_to_camp(p_camp_id uuid, p_item_id uuid)
returns void
language plpgsql
security invoker
as $$
begin
  insert into public.camp_materials (camp_id, inventory_item_id, added_by)
    values (p_camp_id, p_item_id, auth.uid())
    on conflict (camp_id, inventory_item_id) do nothing;
  update public.inventory_items set status = 'checked_out' where id = p_item_id;
  insert into public.item_movements (item_id, action, user_id, event_id)
    values (p_item_id, 'checkout', auth.uid(),
            (select event_id from public.camps where id = p_camp_id));
end;
$$;
grant execute on function public.assign_material_to_camp(uuid, uuid) to authenticated;

-- Retour : retire du chargement, repasse 'disponible', journalise un return.
create or replace function public.return_material_from_camp(p_camp_id uuid, p_item_id uuid)
returns void
language plpgsql
security invoker
as $$
begin
  delete from public.camp_materials
   where camp_id = p_camp_id and inventory_item_id = p_item_id;
  update public.inventory_items set status = 'available' where id = p_item_id;
  insert into public.item_movements (item_id, action, user_id, event_id)
    values (p_item_id, 'return', auth.uid(),
            (select event_id from public.camps where id = p_camp_id));
end;
$$;
grant execute on function public.return_material_from_camp(uuid, uuid) to authenticated;

-- ============================================================================
-- FIN — phase 2 + flux matériel partagé. Exécution unique, idempotente, additive.
-- ============================================================================
