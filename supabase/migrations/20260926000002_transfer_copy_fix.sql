-- Fix for 20260926000001_sharing.sql (already applied on the live project):
-- transfer_copy() spliced its boolean flag into the SQL with format('%s'),
-- which renders false as the bare word f, so every redeem_transfer() failed
-- with 'column "f" does not exist' (found in live QA, 2026-09-26). The
-- sharing file itself is corrected too; this file only replaces the
-- function where the old version is installed.
--
-- Run it once in the Supabase SQL editor after the sharing file. Safe to
-- re-run (idempotent).

create or replace function public.transfer_copy(
  p_table text,
  p_from uuid,
  p_to uuid,
  p_where text,
  p_include_deleted boolean default false
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  execute format(
    'insert into public.%1$I '
    'select c.* from public.%1$I s '
    'cross join lateral jsonb_populate_record(null::public.%1$I, '
    '  to_jsonb(s) || jsonb_build_object(''owner_id'', $2::uuid)) c '
    'where s.owner_id = $1 and (%2$s) and ($3 or s.deleted_at is null) '
    'on conflict (owner_id, id) do nothing',
    p_table, p_where)
  -- The flag is a bound parameter: format('%s') renders false as the bare
  -- word f ("column f does not exist" — found in live QA 2026-09-26).
  using p_from, p_to, p_include_deleted;
end;
$$;

revoke all on function public.transfer_copy(text, uuid, uuid, text, boolean)
  from public, anon, authenticated;
