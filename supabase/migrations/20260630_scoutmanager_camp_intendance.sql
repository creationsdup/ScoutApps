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
