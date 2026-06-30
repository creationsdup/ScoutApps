-- Élargit la contrainte de format du code inventaire.
--
-- Contexte : `inventory_items` est partagé avec CampManager, dont la contrainte
-- `inventory_code_format` impose le format 3 parties `CAT-NOM-NNN`
-- (^[A-Z]{3,5}-[A-Z]{3,5}-[0-9]{3,6}$), ex. ANIMA-BALLE-073. L'app iOS génère
-- ses codes via `next_inventory_code` au format 2 parties `PREFIXE-NNNN`
-- (^[A-Z]{2,4}-[0-9]{4}$), ex. ANIM-0001 — ce qui violait la contrainte et
-- empêchait toute création de matériel depuis l'app.
--
-- Cette migration remplace la contrainte par un SUR-ENSEMBLE qui accepte les
-- DEUX formats. Relaxation pure : aucune ligne existante n'est invalidée et les
-- insertions CampManager (format 3 parties) restent valides.

alter table public.inventory_items
  drop constraint if exists inventory_code_format;

alter table public.inventory_items
  add constraint inventory_code_format check (
       inventory_code ~ '^[A-Z]{3,5}-[A-Z]{3,5}-[0-9]{3,6}$'  -- format CampManager existant
    or inventory_code ~ '^[A-Z]{2,4}-[0-9]{4}$'               -- format app iOS (ex. ANIM-0001)
  );
