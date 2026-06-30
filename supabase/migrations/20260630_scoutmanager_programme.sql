-- ScoutManager — Phase 2 : Programme de camp (ADDITIF, backend partagé CampManager)
-- À exécuter dans le SQL editor Supabase. Idempotent. Réutilise camps + inventory_items.
-- ============================================================================
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

-- select pour authenticated, write pour admin/manager/member (sur les 3 tables)
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
