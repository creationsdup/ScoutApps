-- ScoutManager — Phase 2 : RPC transactionnelle de génération de la liste de courses
-- ============================================================================
-- À EXÉCUTER dans le SQL editor Supabase, APRÈS les migrations camp_intendance.
-- ADDITIF : crée une fonction. Ne modifie aucune table existante.
--
-- Remplace l'agrégation côté app + delete/insert non atomiques par UNE fonction
-- Postgres : le corps s'exécute dans une seule transaction implicite, donc le
-- DELETE des lignes `auto` et le réINSERT sont atomiques (un échec d'insert
-- annule aussi le delete — plus de perte de lignes).
--
-- `security invoker` (défaut) : la fonction s'exécute avec les droits de
-- l'appelant, donc la RLS de `shopping_items` s'applique — un viewer (write
-- refusé) reçoit une erreur, en miroir de `canWrite`. C'est voulu.
--
-- Sémantique identique à l'ancienne version Swift :
--   * itère chaque occurrence (repas × recette) via meals⋈meal_recipes⋈recipes
--     ⋈recipe_ingredients (une recette utilisée dans N repas compte N fois) ;
--   * facteur = ceil(participants / max(1, servings_base)) PAR recette ;
--   * agrège par (nom insensible à la casse, unité), somme des quantités mises
--     à l'échelle ; quantité NULL si aucune occurrence n'avait de quantité ;
--   * participants = max(1, camps.participants_count, défaut 1) ;
--   * remplace les lignes source='auto', préserve les lignes source='manual'.
-- ============================================================================

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
    join public.meal_recipes mr     on mr.meal_id  = m.id
    join public.recipes r           on r.id        = mr.recipe_id
    join public.recipe_ingredients ri on ri.recipe_id = r.id
   where m.camp_id = p_camp_id
   group by lower(ri.name), ri.unit;
end;
$$;

grant execute on function public.regenerate_shopping_auto(uuid) to authenticated;
