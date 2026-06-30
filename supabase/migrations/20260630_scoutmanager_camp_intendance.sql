-- ScoutManager — Phase 2 : Camp & Intendance (ADDITIF, backend partagé CampManager)
-- À exécuter dans le SQL editor Supabase. Idempotent.
-- Task M : table camps (socle pivot). Les tables Intendance s'ajouteront ici (tasks N+).

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

-- ============================================================================
-- Task N : Menus (repas) — tables meals + meal_recipes (ADDITIF)
-- ============================================================================
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

-- Lien N-N repas <-> recettes (la table recipes arrive en Task O ; on crée la
-- jointure dès maintenant, sans FK vers recipes pour ne pas dépendre de l'ordre).
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

-- ============================================================================
-- Task O : Recettes — tables recipes + recipe_ingredients (ADDITIF)
--   Bibliothèque réutilisable, NON liée à un camp.
-- ============================================================================
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

-- ============================================================================
-- Task P : Liste de courses — table shopping_items (ADDITIF)
--   source = 'auto' (généré depuis les menus) | 'manual' (ajouté à la main).
-- ============================================================================
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

-- ============================================================================
-- Task Q : Budget — table expenses (ADDITIF)
-- ============================================================================
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
