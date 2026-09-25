-- MotoLog schema v7: part number / brand on service items.
--
-- Adds `part_number` to `entry_items` (local drift schema v7), a plain
-- client-writable nullable column — no server stamping, no RLS change
-- (the existing entry_items policies already cover every column).
--
-- Requires 20260924000001_sync_tables.sql (creates entry_items).
-- Run it once in the Supabase SQL editor. Safe to re-run (idempotent).

alter table public.entry_items add column if not exists part_number text;
