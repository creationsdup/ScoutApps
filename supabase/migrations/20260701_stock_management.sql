-- 20260701_stock_management.sql
-- Gestion de stock (cycle 1/3) : colonnes ADDITIVES uniquement. Backend partagé
-- avec CampManager — aucune mutation de données/colonnes/enum existants.
-- À exécuter dans le SQL editor Supabase APRÈS les migrations précédentes.

-- 1. Stock sur inventory_items (nullables, additives) -------------------------
alter table public.inventory_items
  add column if not exists minimum_threshold integer,
  add column if not exists unit              text;

-- Contrainte de validation de l'unité (NOT VALID : n'invalide pas l'existant).
-- Valeurs = rawValues de l'enum Swift ItemUnit.
alter table public.inventory_items drop constraint if exists inventory_items_unit_chk;
alter table public.inventory_items
  add constraint inventory_items_unit_chk
  check (unit is null or unit in ('piece','lot','boite','paquet','metre','litre','autre')) not valid;
-- Après vérif des données existantes, tu peux valider :
--   alter table public.inventory_items validate constraint inventory_items_unit_chk;

-- 2. Journal des ajustements sur item_movements ------------------------------
--    `action` est un text libre : la valeur 'adjustment' ne nécessite aucune
--    migration d'enum. On ajoute la quantité (delta signé) et une note libre.
alter table public.item_movements
  add column if not exists quantity integer,
  add column if not exists note     text;
