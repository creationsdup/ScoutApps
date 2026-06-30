-- ScoutManager — Projet 2 : flux matériel partagé camp <-> inventaire (ADDITIF)
-- ============================================================================
-- À EXÉCUTER dans le SQL editor Supabase, APRÈS les migrations précédentes.
-- Backend partagé avec CampManager : additif uniquement. Réutilise inventory_items,
-- item_movements, camps. Idempotent.
--
-- camp_materials = liste de chargement matériel d'un camp (item entier).
-- Les RPC font 3 écritures (chargement + statut + mouvement) dans UNE transaction
-- (security invoker => RLS appliquée, miroir de canWrite).
--   * 'checked_out' / 'available' = rawValues DB de ItemStatus.sorti / .disponible
--   * 'checkout' / 'return'       = MovementAction (item_movements.action)
-- ============================================================================

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
