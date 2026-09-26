-- Live dry-run checks for 20260928000001_security_hardening.sql (run
-- 2026-09-26 on the real project: 92 ok, 0 FAIL, nothing persisted).
--
-- How to use (Supabase SQL editor, "Run without RLS" for the t.* tables):
--   begin;
--   <paste the migration>
--   <paste this file>
-- The last statement raises the whole result log, which rolls the
-- transaction back. Afterwards confirm nothing persisted, e.g.
-- `select to_regnamespace('t'), (select count(*) from auth.users
--  where email like 'sec-%@example.invalid');` → null, 0.
-- Simulated users are fake auth.users rows (00000000-5ec0-…); the real
-- owner is found as the owner of the "Honda 125" vehicle. Never run
-- this without the surrounding begin (it writes test rows).

-- ===================== LIVE DRY-RUN CHECKS (rolled back) =====================
create schema t;
grant usage on schema t to anon, authenticated;
create table t.log (n serial primary key, line text);
grant select, insert on t.log to anon, authenticated;
grant usage on sequence t.log_n_seq to anon, authenticated;
create table t.cfg (k text primary key, v text);
grant select on t.cfg to anon, authenticated;

create function t.as_user(p uuid) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p::text, ''), false);
  perform set_config('role', case when p is null then 'anon' else 'authenticated' end, false);
end $f$;
create function t.ok(p_cond boolean, p_name text) returns void language plpgsql as $f$
begin
  insert into t.log (line) values (case when p_cond is true then 'ok   ' else 'FAIL ' end || p_name);
end $f$;
create function t.works(p_sql text, p_name text) returns void language plpgsql as $f$
begin
  begin
    execute p_sql;
  exception when others then
    insert into t.log (line) values ('FAIL ' || p_name || ' [' || sqlstate || ' ' || sqlerrm || ']');
    return;
  end;
  insert into t.log (line) values ('ok   ' || p_name);
end $f$;
create function t.throws(p_sql text, p_pattern text, p_name text) returns void language plpgsql as $f$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlstate ~ p_pattern or sqlerrm ~* p_pattern then
      insert into t.log (line) values ('ok   ' || p_name || ' [' || sqlstate || ' ' || left(sqlerrm, 60) || ']');
    else
      insert into t.log (line) values ('FAIL ' || p_name || ' — wrong error [' || sqlstate || ' ' || sqlerrm || ']');
    end if;
    return;
  end;
  insert into t.log (line) values ('FAIL ' || p_name || ' — no error');
end $f$;
create function t.val(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  execute p_sql into v;
  return v;
end $f$;
grant execute on all functions in schema t to anon, authenticated;

-- ---- 0. Environment / existing data -------------------------------------
insert into t.cfg values ('real', (select owner_id::text from public.vehicles
  where name = 'Honda 125' and deleted_at is null order by created_at limit 1));
insert into t.log (line) values ('info postgres bypassrls = ' ||
  (select rolbypassrls::text from pg_roles where rolname = 'postgres'));
insert into t.log (line) values ('info accounts in sync_usage = ' ||
  (select count(*) from public.sync_usage) || ', largest = ' ||
  (select coalesce(max(row_bytes), 0) from public.sync_usage) || ' bytes');
select t.ok((select max(row_bytes) from public.sync_usage) < public.sync_row_quota_bytes(),
  'every existing account is under the 25 MB row quota');
select t.ok((select row_bytes from public.sync_usage where owner_id = (select v::uuid from t.cfg where k = 'real')) > 0,
  'owner''s real account has a usage row');
select t.ok(not exists (
  select 1 from (
    select octet_length(s::text) b from public.refuelings s union all
    select octet_length(s::text) from public.entries s union all
    select octet_length(s::text) from public.entry_items s union all
    select octet_length(s::text) from public.vehicles s union all
    select octet_length(s::text) from public.attachments s) x
  where b > public.sync_max_row_bytes()), 'no existing row is over 64 KB');
select t.ok((select file_size_limit from storage.buckets where id = 'attachments') = 3145728,
  'bucket attachments: file_size_limit = 3 MB');

-- Simulated users: A owner, B stranger, C driver of A, D custom profile of A,
-- E and F transfer buyers.
insert into auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at) values
  ('00000000-5ec0-4000-8000-00000000000a', 'authenticated', 'authenticated', 'sec-a@example.invalid', now(), now(), now()),
  ('00000000-5ec0-4000-8000-00000000000b', 'authenticated', 'authenticated', 'sec-b@example.invalid', now(), now(), now()),
  ('00000000-5ec0-4000-8000-00000000000c', 'authenticated', 'authenticated', 'sec-c@example.invalid', now(), now(), now()),
  ('00000000-5ec0-4000-8000-00000000000d', 'authenticated', 'authenticated', 'sec-d@example.invalid', now(), now(), now()),
  ('00000000-5ec0-4000-8000-00000000000e', 'authenticated', 'authenticated', 'sec-e@example.invalid', now(), now(), now()),
  ('00000000-5ec0-4000-8000-00000000000f', 'authenticated', 'authenticated', 'sec-f@example.invalid', now(), now(), now());

-- ---- (a) Owner sync upserts ---------------------------------------------
select t.as_user('00000000-5ec0-4000-8000-00000000000a');
select t.works($q$
  insert into public.vehicles (id, created_at, updated_at, name, "type") values
    ('sec-v1', now(), now(), 'Bike', 'motorcycle'), ('sec-v2', now(), now(), 'Car', 'car')
  on conflict (owner_id, id) do update set name = excluded.name, updated_at = excluded.updated_at$q$,
  'A: upsert 2 new vehicles');
select t.works($q$
  insert into public.refuelings (id, created_at, updated_at, vehicle_id, "date", odometer, total_cost) values
    ('sec-r1', now(), now(), 'sec-v1', now(), 100, 10), ('sec-r2', now(), now(), 'sec-v2', now(), 200, 20)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, updated_at = excluded.updated_at$q$,
  'A: upsert 2 new refuelings');
select t.works($q$
  insert into public.refuelings (id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('sec-r1', now(), now() + interval '5 seconds', 'sec-v1', now(), 100, 11)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, updated_at = excluded.updated_at$q$,
  'A: upsert newer edit over own row');
select t.ok((select total_cost from public.refuelings where id = 'sec-r1') = 11, 'A: newer edit applied');
select t.works($q$
  insert into public.refuelings (id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('sec-r1', now(), now() - interval '1 hour', 'sec-v1', now(), 100, 99)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, updated_at = excluded.updated_at$q$,
  'A: upsert older edit (accepted, skipped)');
select t.ok((select total_cost from public.refuelings where id = 'sec-r1') = 11, 'A: older edit ignored (LWW)');
select t.works($q$
  insert into public.attachments (id, created_at, updated_at, vehicle_id, parent_table, parent_id, file_name, mime_type, size_bytes, storage_path)
  values ('sec-att1', now(), now(), 'sec-v1', 'refuelings', 'sec-r1', 'a.jpg', 'image/jpeg', 10,
          '00000000-5ec0-4000-8000-00000000000a/sec-att1/a.jpg')$q$, 'A: attachment row');
select t.works($q$
  insert into public.access_profiles (id, created_at, updated_at, name, permissions) values
  ('sec-p1', now(), now(), 'Office',
   '{"vehicleScope":"all","recordScope":"all","areas":{"users":["view","register","edit"],"profiles":["view","register","edit"],"refueling":["view"]}}')$q$,
  'A: custom profile');
select t.works($q$
  insert into public.account_members (id, created_at, updated_at, email, profile_id, vehicle_ids) values
    ('sec-m-c', now(), now(), 'SEC-C@example.invalid', 'builtin:driver', '["sec-v1"]'),
    ('sec-m-d', now(), now(), 'sec-d@example.invalid', 'sec-p1', '[]')$q$, 'A: invite C (driver) and D');
reset role;
select t.ok((select row_bytes from public.sync_usage where owner_id = '00000000-5ec0-4000-8000-00000000000a') > 0,
  'A: usage counted');

-- Real owner account: identical re-upload is free, a newer upload applies.
create table t.real_row as
  select r.* from public.refuelings r
  where r.owner_id = (select v::uuid from t.cfg where k = 'real') and r.deleted_at is null
  order by r.date desc limit 1;
grant select on t.real_row to authenticated;
insert into t.cfg values ('real_usage', (select row_bytes::text from public.sync_usage
  where owner_id = (select v::uuid from t.cfg where k = 'real')));
select t.as_user((select v::uuid from t.cfg where k = 'real'));
select t.works($q$
  insert into public.refuelings select * from t.real_row
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, notes = excluded.notes, updated_at = excluded.updated_at$q$,
  'real owner: identical re-upload of a real refueling');
select t.works($q$
  insert into public.refuelings select * from t.real_row
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, updated_at = excluded.updated_at + interval '1 second'$q$,
  'real owner: newer upsert of a real refueling');
select t.ok((select updated_at from public.refuelings r where r.owner_id = (select owner_id from t.real_row) and r.id = (select id from t.real_row))
            = (select updated_at + interval '1 second' from t.real_row), 'real owner: newer upsert applied');
reset role;
select t.ok(abs((select row_bytes from public.sync_usage where owner_id = (select v::uuid from t.cfg where k = 'real'))
            - (select v::bigint from t.cfg where k = 'real_usage')) < 50, 'real owner: usage unchanged by re-upload/edit (±50 B)');

-- ---- (b) Members: allowed and forbidden writes --------------------------
select t.as_user('00000000-5ec0-4000-8000-00000000000c');
select t.works($q$select public.accept_invitation('00000000-5ec0-4000-8000-00000000000a', 'sec-m-c')$q$, 'C accepts invitation');
reset role;
select t.as_user('00000000-5ec0-4000-8000-00000000000d');
select t.works($q$select public.accept_invitation('00000000-5ec0-4000-8000-00000000000a', 'sec-m-d')$q$, 'D accepts invitation');
reset role;

select t.as_user('00000000-5ec0-4000-8000-00000000000c');
select t.ok((select string_agg(id, ',') from public.vehicles where owner_id = '00000000-5ec0-4000-8000-00000000000a') = 'sec-v1',
  'driver sees only the assigned vehicle');
select t.ok((select count(*) from public.refuelings where owner_id = '00000000-5ec0-4000-8000-00000000000a') = 0,
  'driver sees none of the owner''s records');
select t.ok(public.sync_row_exists('vehicles', '00000000-5ec0-4000-8000-00000000000a', 'sec-v1'),
  'sync_row_exists() still answers for a member');
select t.works($q$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-rc1', now(), now(), 'sec-v1', now(), 150, 5)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, updated_at = excluded.updated_at$q$,
  'driver: upsert refueling on assigned vehicle');
select t.ok((select created_by from public.refuelings where id = 'sec-rc1') = '00000000-5ec0-4000-8000-00000000000c',
  'driver: created_by stamped = member');
select t.works($q$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-rc1', now(), now(), 'sec-v1', now(), 150, 6)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, updated_at = excluded.updated_at$q$,
  'driver: edit own record');
select t.throws($q$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-rc2', now(), now(), 'sec-v2', now(), 1, 1)$q$,
  '42501', 'driver: add to unassigned vehicle denied');
select t.throws($q$
  update public.refuelings set deleted_at = now(), updated_at = now() + interval '10 seconds' where id = 'sec-rc1'$q$,
  '42501', 'driver: soft delete denied (no Delete right)');
select t.throws($q$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-r1', now(), now() + interval '1 hour', 'sec-v1', now(), 1, 1)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost, updated_at = excluded.updated_at$q$,
  '42501', 'driver: overwrite owner''s row denied');
select t.throws($q$
  insert into public.access_profiles (owner_id, id, created_at, updated_at, name, permissions)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-px', now(), now(), 'X', '{}')$q$,
  '42501', 'driver: add profile denied');
select t.throws($q$select public.profile_permissions('00000000-5ec0-4000-8000-00000000000a', 'sec-p1')$q$, '42501', 'driver: profile_permissions() denied');
select t.throws($q$select public.transfer_copy('vehicles', '00000000-5ec0-4000-8000-00000000000a', '00000000-5ec0-4000-8000-00000000000c', 'true')$q$, '42501', 'driver: transfer_copy() denied');
select t.throws($q$select public.sync_usage_add('00000000-5ec0-4000-8000-00000000000c', -999, false)$q$, '42501', 'driver: sync_usage_add() denied');
select t.throws($q$select public.sync_usage_recount()$q$, '42501', 'driver: sync_usage_recount() denied');
select t.throws($q$select count(*) from public.transfers$q$, '42501', 'driver: read transfers denied');
select t.throws($q$select count(*) from public.sync_usage$q$, '42501', 'driver: read sync_usage denied');
select t.throws($q$select count(*) from public.transfer_attempts$q$, '42501', 'driver: read transfer_attempts denied');
-- S9: far-future timestamp from a member is clamped.
select t.works($q$update public.refuelings set updated_at = '9999-12-31', total_cost = 7 where id = 'sec-rc1'$q$, 'driver: edit with far-future updated_at');
select t.ok((select updated_at from public.refuelings where id = 'sec-rc1') < now() + interval '2 days', 'S9: member far-future updated_at clamped');
select t.ok((select total_cost from public.refuelings where id = 'sec-rc1') = 7, 'S9: the member''s edit itself applied');
update public.account_members set profile_id = 'builtin:administrator' where id = 'sec-m-c';
reset role;
select t.ok((select profile_id from public.account_members where id = 'sec-m-c') = 'builtin:driver', 'driver cannot raise own membership');

-- S2: custom profile with Users + Profiles edit.
select t.as_user('00000000-5ec0-4000-8000-00000000000d');
select t.throws($q$
  update public.account_members set owner_id = '00000000-5ec0-4000-8000-00000000000d',
    profile_id = 'builtin:administrator', updated_at = now() + interval '1 minute'
  where owner_id = '00000000-5ec0-4000-8000-00000000000a' and id = 'sec-m-d'$q$,
  'own_membership', 'S2: member cannot raise own membership via owner_id = self');
select t.throws($q$
  update public.access_profiles set owner_id = '00000000-5ec0-4000-8000-00000000000d', permissions = '{}',
    updated_at = now() + interval '1 minute'
  where owner_id = '00000000-5ec0-4000-8000-00000000000a' and id = 'sec-p1'$q$,
  'own_profile', 'S2: member cannot edit own profile via owner_id = self');
select t.works($q$
  insert into public.account_members (owner_id, id, created_at, updated_at, email, profile_id, status)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-m-x', now(), now(), 'sec-x@example.invalid', 'builtin:driver', 'active')$q$,
  'D (Users register) may invite someone else');
reset role;
select t.ok((select status from public.account_members where id = 'sec-m-x') = 'pending', 'invite written as active stays pending');

-- Stranger B.
select t.as_user('00000000-5ec0-4000-8000-00000000000b');
select t.ok((select count(*) from public.vehicles where owner_id <> '00000000-5ec0-4000-8000-00000000000b') = 0, 'stranger sees no other account''s vehicles');
select t.ok(not public.sync_row_exists('vehicles', '00000000-5ec0-4000-8000-00000000000a', 'sec-v1'), 'S5: sync_row_exists() tells a stranger nothing');
select t.throws($q$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-r1', now(), now() + interval '1 hour', 'sec-v1', now(), 1, 1)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost$q$, '42501', 'stranger cannot upsert over A''s row');
reset role;

-- ---- (c) New limits -----------------------------------------------------
-- Row size + 25 MB account quota (stranger B's own account).
select t.as_user('00000000-5ec0-4000-8000-00000000000b');
select t.throws($q$insert into public.vehicles (id, created_at, updated_at, name, "type", notes)
  values ('sec-big', now(), now(), 'x', 'car', repeat('x', 70000))$q$, 'row_too_large', 'S3: a 70 KB row is refused');
select t.works($q$insert into public.vehicles (id, created_at, updated_at, name, "type") values ('sec-ok', now(), now(), 'x', 'car')$q$, 'B: normal vehicle');
select t.throws($q$
  insert into public.readings (id, created_at, updated_at, vehicle_id, "date", odometer, notes)
  select 'sec-q' || g, now(), now(), 'sec-ok', now(), g, repeat(md5(g::text), 1875) from generate_series(1, 460) g$q$,
  'quota_exceeded', 'S3: a 27.6 MB push is refused (25 MB quota)');
select t.ok((select count(*) from public.readings where id like 'sec-q%') = 0, 'S3: refused batch left nothing');
select t.works($q$
  insert into public.readings (id, created_at, updated_at, vehicle_id, "date", odometer, notes)
  select 'sec-q' || g, now(), now(), 'sec-ok', now(), g, repeat(md5(g::text), 1875) from generate_series(1, 400) g$q$,
  'S3: a 24 MB push fits');
select t.throws($q$
  insert into public.readings (id, created_at, updated_at, vehicle_id, "date", odometer, notes)
  select 'sec-z' || g, now(), now(), 'sec-ok', now(), g, repeat(md5(g::text), 1875) from generate_series(1, 40) g$q$,
  'quota_exceeded', 'S3: no new rows once the quota is reached');
select t.works($q$update public.readings set deleted_at = now(), updated_at = now() + interval '1 second' where id like 'sec-q%'$q$,
  'S3: soft delete at the quota still works');
select t.works($q$delete from public.readings where id like 'sec-q%'$q$, 'S3: hard delete at the quota works');
reset role;
select t.ok((select row_bytes from public.sync_usage where owner_id = '00000000-5ec0-4000-8000-00000000000b') < 100000, 'S3: deleting frees usage');

-- Storage: 50 MB per account folder.
select t.as_user('00000000-5ec0-4000-8000-00000000000a');
select t.works($q$insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-5ec0-4000-8000-00000000000a/sec-att1/a.jpg', '00000000-5ec0-4000-8000-00000000000a', '{"size": 1000}')$q$,
  'A: upload into own folder');
reset role;
select t.as_user('00000000-5ec0-4000-8000-00000000000b');
select t.throws($q$insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-5ec0-4000-8000-00000000000a/evil/x.jpg', '00000000-5ec0-4000-8000-00000000000b', null)$q$,
  '42501', 'stranger cannot upload into A''s folder');
select t.ok(not public.attachment_upload_allowed('00000000-5ec0-4000-8000-00000000000a/x/y.jpg', null), 'attachment_upload_allowed() says nothing about A to B');
reset role;
select t.as_user('00000000-5ec0-4000-8000-00000000000c');
select t.works($q$insert into public.attachments (owner_id, id, created_at, updated_at, vehicle_id, parent_table, parent_id, file_name, mime_type, size_bytes)
  values ('00000000-5ec0-4000-8000-00000000000a', 'sec-attc', now(), now(), 'sec-v1', 'refuelings', 'sec-rc1', 'c.jpg', 'image/jpeg', 10)$q$,
  'driver: attachment row on own record');
select t.works($q$insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-5ec0-4000-8000-00000000000a/sec-attc/c.jpg', '00000000-5ec0-4000-8000-00000000000c', '{"size": 1000}')$q$,
  'driver: photo upload into the owner''s folder');
select t.ok(not public.can_read_attachment_object('00000000-5ec0-4000-8000-00000000000a/sec-att1/a.jpg'), 'driver cannot read the owner''s file');
reset role;
select t.as_user('00000000-5ec0-4000-8000-00000000000a');
select t.works($q$insert into storage.objects (bucket_id, name, owner, metadata)
  select 'attachments', '00000000-5ec0-4000-8000-00000000000a/sec-fill' || g || '/f.jpg', '00000000-5ec0-4000-8000-00000000000a', '{"size": 3000000}'
  from generate_series(1, 17) g$q$, 'A: 17 × 3 MB uploads (51 MB, under 52.4 MB) allowed');
select t.throws($q$insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-5ec0-4000-8000-00000000000a/sec-over/o.jpg', '00000000-5ec0-4000-8000-00000000000a', '{"size": 3000000}')$q$,
  '42501', 'S4: owner upload past 50 MB refused');
reset role;
select t.as_user('00000000-5ec0-4000-8000-00000000000c');
select t.throws($q$insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-5ec0-4000-8000-00000000000a/sec-attc/d.jpg', '00000000-5ec0-4000-8000-00000000000c', '{"size": 3000000}')$q$,
  '42501', 'S4: member upload into a full owner folder refused');
reset role;
select t.as_user('00000000-5ec0-4000-8000-00000000000e');
select t.works($q$insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-5ec0-4000-8000-00000000000e/sec-e/e.jpg', '00000000-5ec0-4000-8000-00000000000e', '{"size": 3000000}')$q$,
  'S4: another account''s quota is separate');
reset role;

-- Transfers: rate limits, and a real redeem still works.
create table t.code (code text);
grant select, insert on t.code to authenticated;
select t.as_user('00000000-5ec0-4000-8000-00000000000a');
insert into t.code select code from public.create_transfer('sec-v1');
reset role;
select t.as_user('00000000-5ec0-4000-8000-00000000000e');
select t.ok((select count(*) from public.redeem_transfer('ZZZZZZZ' || g)) = 0, 'S6: wrong code ' || g || ' → no rows')
from generate_series(2, 9) g;
select t.ok((select count(*) from public.redeem_transfer('YYYYYYY2')) = 0, 'S6: wrong code 9b → no rows');
select t.ok((select count(*) from public.redeem_transfer('YYYYYYY3')) = 0, 'S6: wrong code 10 → no rows');
select t.throws($q$select * from public.redeem_transfer('YYYYYYY4')$q$, 'transfer_rate_limited', 'S6: 11th wrong code in an hour refused');
select t.throws($q$select * from public.redeem_transfer((select code from t.code))$q$, 'transfer_rate_limited', 'S6: even the right code waits');
reset role;
select t.ok((select count(*) from public.transfer_attempts where user_id = '00000000-5ec0-4000-8000-00000000000e') = 10, 'S6: 10 attempts recorded');
select t.as_user('00000000-5ec0-4000-8000-00000000000f');
select t.ok((select vehicle_id from public.redeem_transfer((select code from t.code))) = 'sec-v1', 'transfer: buyer redeems the right code');
select t.ok((select count(*) from public.refuelings where owner_id = '00000000-5ec0-4000-8000-00000000000f') = 2, 'transfer: buyer got owner''s + member''s records');
reset role;
select t.ok((select row_bytes from public.sync_usage where owner_id = '00000000-5ec0-4000-8000-00000000000f') > 0, 'transfer: counted toward the buyer');
select t.as_user('00000000-5ec0-4000-8000-00000000000a');
select t.works($q$do $d$ begin for i in 1..19 loop perform public.create_transfer('sec-v2'); end loop; end $d$$q$, 'S6: codes 2–20 in a day allowed');
select t.throws($q$select * from public.create_transfer('sec-v2')$q$, 'transfer_rate_limited', 'S6: 21st code in a day refused');
reset role;

-- Profiles, account deletion, global invariants.
select t.as_user('00000000-5ec0-4000-8000-00000000000b');
select t.throws($q$insert into public.profiles (id, first_name) values ('00000000-5ec0-4000-8000-00000000000b', repeat('x', 101))$q$,
  'profiles_field_lengths', 'S12: 101-char first name refused');
select t.works($q$select public.delete_my_account()$q$, 'delete_my_account() works with the usage triggers');
reset role;
select t.ok(not exists (select 1 from public.sync_usage where owner_id = '00000000-5ec0-4000-8000-00000000000b'), 'usage row removed with the account');
create table t.inc as select owner_id, row_bytes from public.sync_usage;
select public.sync_usage_recount();
select t.ok(not exists (select 1 from t.inc i full join public.sync_usage u using (owner_id)
  where i.row_bytes is distinct from u.row_bytes), 'incremental usage = full recount (all accounts)');
select t.ok(not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity), 'RLS on every public table');
select t.ok(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')
    and p.prorettype <> 'trigger'::regtype), 'anon can execute no SECURITY DEFINER function');
select t.as_user(null);
select t.throws($q$select * from public.redeem_transfer('AAAAAAAA')$q$, '42501', 'anon cannot call redeem_transfer()');
reset role;

do $$
declare
  v_fail int := (select count(*) from t.log where line like 'FAIL%');
  v_ok int := (select count(*) from t.log where line like 'ok%');
begin
  raise exception E'DRY RUN (rolled back): % ok, % FAIL\n%', v_ok, v_fail,
    (select string_agg(line, E'\n' order by n) from t.log);
end $$;
