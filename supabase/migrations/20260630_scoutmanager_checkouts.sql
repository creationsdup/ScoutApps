-- ScoutMatériel — bon de sortie (panier) — ADDITIF
-- ============================================================================
-- À EXÉCUTER dans le SQL editor Supabase. Idempotent. Backend partagé : additif
-- uniquement. Réutilise inventory_items.quantity_available/status + item_movements.
--   * 'checked_out' / 'available' = ItemStatus.sorti / .disponible
--   * 'checkout' / 'return'       = MovementAction
-- ============================================================================

create table if not exists public.checkouts (
  id          uuid primary key default gen_random_uuid(),
  label       text not null,
  notes       text,
  status      text not null default 'open',
  created_by  uuid,
  created_at  timestamptz not null default now(),
  returned_at timestamptz
);
alter table public.checkouts drop constraint if exists checkouts_status_chk;
alter table public.checkouts add constraint checkouts_status_chk
  check (status in ('open','returned')) not valid;

create table if not exists public.checkout_items (
  id                uuid primary key default gen_random_uuid(),
  checkout_id       uuid not null references public.checkouts(id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items(id) on delete cascade,
  quantity          integer not null,
  quantity_returned integer not null default 0
);

alter table public.checkouts      enable row level security;
alter table public.checkout_items enable row level security;

do $$ declare t text;
begin
  foreach t in array array['checkouts','checkout_items'] loop
    execute format('drop policy if exists %I_select_auth on public.%I', t, t);
    execute format('create policy %I_select_auth on public.%I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_write_roles on public.%I', t, t);
    execute format($f$create policy %I_write_roles on public.%I for all to authenticated
      using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))
      with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','manager','member')))$f$, t, t);
  end loop;
end $$;

-- Création d'un bon : insère bon + lignes, décrémente dispo, pose statut, journalise. Anti-survente.
create or replace function public.create_checkout(p_label text, p_notes text, p_items jsonb)
returns uuid language plpgsql security invoker as $$
declare
  v_checkout_id uuid; v_item jsonb; v_item_id uuid; v_qty integer; v_avail integer;
begin
  insert into public.checkouts (label, notes, status, created_by)
    values (p_label, p_notes, 'open', auth.uid()) returning id into v_checkout_id;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_item->>'item_id')::uuid;
    v_qty := (v_item->>'quantity')::integer;
    if v_qty is null or v_qty <= 0 then raise exception 'Quantité invalide'; end if;
    select coalesce(quantity_available, quantity) into v_avail
      from public.inventory_items where id = v_item_id for update;
    if v_avail is null then raise exception 'Item introuvable'; end if;
    if v_avail < v_qty then raise exception 'Stock insuffisant (dispo %, demandé %)', v_avail, v_qty; end if;
    insert into public.checkout_items (checkout_id, inventory_item_id, quantity)
      values (v_checkout_id, v_item_id, v_qty);
    update public.inventory_items
       set quantity_available = v_avail - v_qty,
           status = case when (v_avail - v_qty) <= 0 then 'checked_out' else 'available' end
     where id = v_item_id;
    insert into public.item_movements (item_id, action, user_id, event_id)
      values (v_item_id, 'checkout', auth.uid(), null);
  end loop;
  return v_checkout_id;
end; $$;
grant execute on function public.create_checkout(text, text, jsonb) to authenticated;

-- Retour partiel d'une ligne : crédite dispo, journalise, ferme le bon si tout rendu.
create or replace function public.return_checkout_line(p_checkout_item_id uuid, p_qty integer)
returns void language plpgsql security invoker as $$
declare
  v_cid uuid; v_item_id uuid; v_qty integer; v_returned integer; v_remaining integer; v_ret integer; v_total integer;
begin
  select checkout_id, inventory_item_id, quantity, quantity_returned
    into v_cid, v_item_id, v_qty, v_returned
    from public.checkout_items where id = p_checkout_item_id for update;
  if v_cid is null then raise exception 'Ligne introuvable'; end if;
  v_remaining := v_qty - v_returned;
  v_ret := least(greatest(p_qty, 0), v_remaining);
  if v_ret <= 0 then return; end if;
  update public.checkout_items set quantity_returned = v_returned + v_ret where id = p_checkout_item_id;
  select quantity into v_total from public.inventory_items where id = v_item_id for update;
  update public.inventory_items
     set quantity_available = least(coalesce(quantity_available,0) + v_ret, v_total), status = 'available'
   where id = v_item_id;
  insert into public.item_movements (item_id, action, user_id, event_id)
    values (v_item_id, 'return', auth.uid(), null);
  if not exists (select 1 from public.checkout_items where checkout_id = v_cid and quantity_returned < quantity) then
    update public.checkouts set status = 'returned', returned_at = now() where id = v_cid;
  end if;
end; $$;
grant execute on function public.return_checkout_line(uuid, integer) to authenticated;

-- Tout rendre : rend le restant de chaque ligne (réutilise la fonction ligne).
create or replace function public.return_checkout_all(p_checkout_id uuid)
returns void language plpgsql security invoker as $$
declare v_line record;
begin
  for v_line in select id, quantity, quantity_returned from public.checkout_items
                where checkout_id = p_checkout_id and quantity_returned < quantity loop
    perform public.return_checkout_line(v_line.id, v_line.quantity - v_line.quantity_returned);
  end loop;
end; $$;
grant execute on function public.return_checkout_all(uuid) to authenticated;
