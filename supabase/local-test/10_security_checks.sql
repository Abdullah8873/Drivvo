-- Security checks for the MotoLog SQL, run by tool/sql_test.sh on a LOCAL
-- Postgres after 00_supabase_stub.sql and every migration. Each check runs
-- as a simulated Supabase user (role `authenticated` + JWT sub) and raises
-- "FAIL: …" when the server allows something it shouldn't (or refuses
-- something it should allow). Never run this on the live project.

\set ON_ERROR_STOP 1

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create schema t;
grant usage on schema t to anon, authenticated;

-- Act as user p (null = anon), like PostgREST does for a request's JWT.
create function t.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p::text, ''), false);
  perform set_config('role', case when p is null then 'anon' else 'authenticated' end, false);
end;
$$;

create function t.ok(p_cond boolean, p_name text) returns void language plpgsql as $$
begin
  if p_cond is not true then
    raise exception 'FAIL: %', p_name;
  end if;
  raise notice 'ok - %', p_name;
end;
$$;

-- p_sql must fail with an error whose SQLSTATE or message matches p_pattern.
create function t.throws(p_sql text, p_pattern text, p_name text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlstate ~ p_pattern or sqlerrm ~* p_pattern then
      raise notice 'ok - % (% %)', p_name, sqlstate, sqlerrm;
      return;
    end if;
    raise exception 'FAIL: % — unexpected error % %', p_name, sqlstate, sqlerrm;
  end;
  raise exception 'FAIL: % — no error', p_name;
end;
$$;

create function t.val(p_sql text) returns text language plpgsql as $$
declare
  v text;
begin
  execute p_sql into v;
  return v;
end;
$$;

grant execute on all functions in schema t to anon, authenticated;

-- Users: A owner, B stranger, C driver member of A, D custom-profile member
-- of A (Users + Profiles edit), E and F transfer buyers.
insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com', now()),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com', now()),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com', now()),
  ('00000000-0000-0000-0000-00000000000d', 'd@example.com', now()),
  ('00000000-0000-0000-0000-00000000000e', 'e@example.com', now()),
  ('00000000-0000-0000-0000-00000000000f', 'f@example.com', now());

-- ---------------------------------------------------------------------------
-- Owner A sets up data, members and invitations (through RLS, as A)
-- ---------------------------------------------------------------------------

select t.as_user('00000000-0000-0000-0000-00000000000a');
insert into public.vehicles (id, created_at, updated_at, name, "type") values
  ('v1', now(), now(), 'Bike', 'motorcycle'),
  ('v2', now(), now(), 'Car', 'car');
insert into public.refuelings (id, created_at, updated_at, vehicle_id, "date", odometer, total_cost) values
  ('r1', now(), now(), 'v1', now(), 100, 10),
  ('r2', now(), now(), 'v2', now(), 200, 20);
insert into public.attachments (id, created_at, updated_at, vehicle_id, parent_table, parent_id, file_name, mime_type, size_bytes, storage_path) values
  ('att1', now(), now(), 'v1', 'refuelings', 'r1', 'a.jpg', 'image/jpeg', 10,
   '00000000-0000-0000-0000-00000000000a/att1/a.jpg');
insert into public.access_profiles (id, created_at, updated_at, name, permissions) values
  ('p1', now(), now(), 'Office',
   '{"vehicleScope":"all","recordScope":"all","areas":{"users":["view","register","edit"],"profiles":["view","register","edit"],"refueling":["view"]}}');
insert into public.account_members (id, created_at, updated_at, email, profile_id, vehicle_ids) values
  ('m-c', now(), now(), 'C@Example.com', 'builtin:driver', '["v1"]'),
  ('m-d', now(), now(), 'd@example.com', 'p1', '[]');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000c');
select public.accept_invitation('00000000-0000-0000-0000-00000000000a', 'm-c');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000d');
select public.accept_invitation('00000000-0000-0000-0000-00000000000a', 'm-d');
reset role;

select t.ok(
  (select count(*) from public.account_members where status = 'active') = 2,
  'invitations accepted through accept_invitation()');

-- ---------------------------------------------------------------------------
-- Stranger B: no reads, writes, deletes or probing of A's account
-- ---------------------------------------------------------------------------

select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.ok((select count(*) from public.vehicles) = 0, 'B sees none of A''s vehicles');
select t.ok((select count(*) from public.refuelings) = 0, 'B sees none of A''s refuelings');
select t.ok((select count(*) from public.account_members) = 0, 'B sees none of A''s members (emails)');
select t.throws($$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-0000-0000-0000-00000000000a', 'rx', now(), now(), 'v1', now(), 1, 1)$$,
  '42501', 'B cannot insert into A''s account');
select t.throws($$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-0000-0000-0000-00000000000a', 'r1', now(), now() + interval '1 hour', 'v1', now(), 1, 1)
  on conflict (owner_id, id) do update set total_cost = excluded.total_cost$$,
  '42501', 'B cannot upsert over A''s row');
update public.refuelings set total_cost = 999 where owner_id = '00000000-0000-0000-0000-00000000000a';
delete from public.refuelings where owner_id = '00000000-0000-0000-0000-00000000000a';
select t.ok(not public.sync_row_exists('vehicles', '00000000-0000-0000-0000-00000000000a', 'v1'),
  'sync_row_exists() tells B nothing about A''s rows');
select t.ok(not public.can_access('00000000-0000-0000-0000-00000000000a', 'refueling', 'view', 'v1', null),
  'can_access() is false for B');
select t.ok(not public.can_read_attachment_object('00000000-0000-0000-0000-00000000000a/att1/a.jpg'),
  'B cannot read A''s file');
select t.ok((select count(*) from public.my_invitations()) = 0, 'B has no invitations');
select t.ok((select count(*) from public.my_memberships()) = 0, 'B has no memberships');
select t.throws($$select public.account_display_name('00000000-0000-0000-0000-00000000000a')$$,
  '42501', 'B cannot look up A''s name/email');
select t.throws($$select public.profile_permissions('00000000-0000-0000-0000-00000000000a', 'p1')$$,
  '42501', 'profile_permissions() is internal');
select t.throws($$select public.transfer_copy('vehicles', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'true')$$,
  '42501', 'transfer_copy() (dynamic SQL) is not callable');
select t.throws($$select public.sync_usage_recount()$$, '42501', 'sync_usage_recount() is internal');
select t.throws($$select public.sync_usage_add('00000000-0000-0000-0000-00000000000b', -999999, false)$$,
  '42501', 'sync_usage_add() is internal');
select t.throws($$select count(*) from public.transfers$$, '42501', 'transfers table is closed');
select t.throws($$select count(*) from public.sync_usage$$, '42501', 'sync_usage table is closed');
select t.throws($$select count(*) from public.transfer_attempts$$, '42501', 'transfer_attempts table is closed');
select public.leave_account('00000000-0000-0000-0000-00000000000a'); -- no-op for a non-member
reset role;

select t.ok(
  (select sum(total_cost) from public.refuelings where owner_id = '00000000-0000-0000-0000-00000000000a') = 30,
  'A''s refuelings untouched by B''s update/delete');
select t.ok(
  (select count(*) from public.account_members where status = 'active') = 2,
  'leave_account() by a non-member changed nothing');

-- anon (publishable key, no sign-in)
select t.as_user(null);
select t.ok((select count(*) from public.vehicles) = 0, 'anon reads nothing');
select t.throws($$select public.redeem_transfer('AAAAAAAA')$$, '42501', 'anon cannot call redeem_transfer()');
select t.throws($$select public.my_invitations()$$, '42501', 'anon cannot call my_invitations()');
reset role;

-- ---------------------------------------------------------------------------
-- Driver C: assigned vehicle only, own records only
-- ---------------------------------------------------------------------------

select t.as_user('00000000-0000-0000-0000-00000000000c');
select t.ok((select string_agg(id, ',' order by id) from public.vehicles) = 'v1', 'driver sees only the assigned vehicle');
select t.ok((select count(*) from public.refuelings) = 0, 'driver sees none of the owner''s records');
select t.ok(public.sync_row_exists('vehicles', '00000000-0000-0000-0000-00000000000a', 'v1'),
  'sync_row_exists() still works for a member');
insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
values ('00000000-0000-0000-0000-00000000000a', 'rc1', now(), now(), 'v1', now(), 150, 5);
select t.ok((select created_by from public.refuelings where id = 'rc1') = '00000000-0000-0000-0000-00000000000c',
  'member row stamped created_by = member');
select t.throws($$
  insert into public.refuelings (owner_id, id, created_at, updated_at, vehicle_id, "date", odometer, total_cost)
  values ('00000000-0000-0000-0000-00000000000a', 'rc2', now(), now(), 'v2', now(), 1, 1)$$,
  '42501', 'driver cannot add to an unassigned vehicle');
update public.account_members set profile_id = 'builtin:administrator' where id = 'm-c';
-- Far-future timestamp from a member is replaced by the server clock.
update public.refuelings set updated_at = '9999-12-31', total_cost = 6 where id = 'rc1';
select t.ok((select updated_at from public.refuelings where id = 'rc1') < now() + interval '2 days',
  'member cannot pin a row with a far-future updated_at');
select t.ok((select total_cost from public.refuelings where id = 'rc1') = 6, 'member edit itself applied');
reset role;
select t.ok((select profile_id from public.account_members where id = 'm-c') = 'builtin:driver',
  'driver cannot see/raise their own membership');

-- The owner's own far-future timestamps are left alone (their devices,
-- their data).
select t.as_user('00000000-0000-0000-0000-00000000000a');
update public.refuelings set updated_at = '2999-01-01' where id = 'r2';
reset role;
select t.ok((select updated_at from public.refuelings where id = 'r2') = '2999-01-01', 'owner timestamps unchanged');

-- ---------------------------------------------------------------------------
-- D (custom profile with Users + Profiles edit): guard bypass (S2)
-- ---------------------------------------------------------------------------

select t.as_user('00000000-0000-0000-0000-00000000000d');
select t.throws($$
  update public.account_members
     set owner_id = '00000000-0000-0000-0000-00000000000d',
         profile_id = 'builtin:administrator', updated_at = now() + interval '1 minute'
   where owner_id = '00000000-0000-0000-0000-00000000000a' and id = 'm-d'$$,
  'own_membership', 'member cannot raise own membership via owner_id = self');
select t.throws($$
  update public.account_members set profile_id = 'builtin:administrator', updated_at = now() + interval '1 minute'
   where owner_id = '00000000-0000-0000-0000-00000000000a' and id = 'm-d'$$,
  'own_membership', 'member cannot raise own membership directly');
select t.throws($$
  update public.access_profiles
     set owner_id = '00000000-0000-0000-0000-00000000000d',
         permissions = '{"vehicleScope":"all","recordScope":"all","areas":{"refueling":["view","register","edit","delete"]}}',
         updated_at = now() + interval '1 minute'
   where owner_id = '00000000-0000-0000-0000-00000000000a' and id = 'p1'$$,
  'own_profile', 'member cannot widen own profile via owner_id = self');
select t.throws($$
  update public.access_profiles set permissions = '{}', updated_at = now() + interval '1 minute'
   where owner_id = '00000000-0000-0000-0000-00000000000a' and id = 'p1'$$,
  'own_profile', 'member cannot edit own profile directly');
-- Allowed: inviting someone else (Users register).
insert into public.account_members (owner_id, id, created_at, updated_at, email, profile_id, status)
values ('00000000-0000-0000-0000-00000000000a', 'm-x', now(), now(), 'x@example.com', 'builtin:driver', 'active');
reset role;
select t.ok((select status from public.account_members where id = 'm-x') = 'pending',
  'an invite written as active stays pending until accepted');
select t.ok((select profile_id from public.account_members where id = 'm-d') = 'p1', 'D still has p1');

-- ---------------------------------------------------------------------------
-- Row size cap and account quota (S3)
-- ---------------------------------------------------------------------------

select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.throws($$
  insert into public.vehicles (id, created_at, updated_at, name, "type", notes)
  values ('big', now(), now(), 'x', 'car', repeat('x', 70000))$$,
  'row_too_large', 'a 70 KB row is refused');
insert into public.vehicles (id, created_at, updated_at, name, "type", notes)
values ('ok', now(), now(), 'x', 'car', repeat('x', 1000));
reset role;
select t.ok((select row_bytes from public.sync_usage where owner_id = '00000000-0000-0000-0000-00000000000b') > 1000,
  'usage counts B''s insert');

-- Re-uploading the same row (skipped by last-write-wins) costs nothing.
create temp table usage_before as
  select row_bytes as bytes from public.sync_usage
  where owner_id = '00000000-0000-0000-0000-00000000000b';
grant select on usage_before to authenticated;
select t.as_user('00000000-0000-0000-0000-00000000000b');
insert into public.vehicles (id, created_at, updated_at, name, "type", notes)
select 'ok', created_at, updated_at, name, "type", notes from public.vehicles where id = 'ok'
on conflict (owner_id, id) do update set notes = excluded.notes;
reset role;
select t.ok((select row_bytes from public.sync_usage where owner_id = '00000000-0000-0000-0000-00000000000b')
            = (select bytes from usage_before), 'identical re-upload leaves usage unchanged');

-- 460 rows × 60 KB ≈ 27.6 MB > 25 MB: the whole batch is refused.
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.throws($$
  insert into public.readings (id, created_at, updated_at, vehicle_id, "date", odometer, notes)
  select 'q' || g, now(), now(), 'ok', now(), g, repeat(md5(g::text), 1875)
  from generate_series(1, 460) g$$,
  'quota_exceeded', 'a push that would pass the 25 MB quota is refused');
select t.ok((select count(*) from public.readings) = 0, 'refused batch left nothing behind');
-- 400 rows × 60 KB ≈ 24 MB fits.
insert into public.readings (id, created_at, updated_at, vehicle_id, "date", odometer, notes)
select 'q' || g, now(), now(), 'ok', now(), g, repeat(md5(g::text), 1875)
from generate_series(1, 400) g;
select t.throws($$
  insert into public.readings (id, created_at, updated_at, vehicle_id, "date", odometer, notes)
  select 'z' || g, now(), now(), 'ok', now(), g, repeat(md5(g::text), 1875)
  from generate_series(1, 40) g$$,
  'quota_exceeded', 'no new rows once the quota is reached');
-- Edits and soft deletes still work near the quota (20% headroom).
update public.readings set deleted_at = now(), updated_at = now() + interval '1 second';
select t.ok((select count(*) from public.readings where deleted_at is not null) = 400,
  'soft-deleting at the quota still works');
-- Hard deletes free the space.
delete from public.readings;
insert into public.readings (id, created_at, updated_at, vehicle_id, "date", odometer, notes)
select 'y' || g, now(), now(), 'ok', now(), g, 'short' from generate_series(1, 10) g;
reset role;
select t.ok((select row_bytes from public.sync_usage where owner_id = '00000000-0000-0000-0000-00000000000b') < 100000,
  'deleting rows frees usage');

-- The incremental numbers match a full recount.
create temp table usage_incremental as select owner_id, row_bytes from public.sync_usage;
select public.sync_usage_recount();
select t.ok(not exists (
  select 1 from usage_incremental i full join public.sync_usage u using (owner_id)
  where i.row_bytes is distinct from u.row_bytes), 'incremental usage = recount');

-- ---------------------------------------------------------------------------
-- Storage (S4)
-- ---------------------------------------------------------------------------

select t.ok((select file_size_limit from storage.buckets where id = 'attachments') = 3145728,
  'bucket file limit is 3 MB');

select t.as_user('00000000-0000-0000-0000-00000000000a');
insert into storage.objects (bucket_id, name, owner, metadata)
values ('attachments', '00000000-0000-0000-0000-00000000000a/att1/a.jpg',
        '00000000-0000-0000-0000-00000000000a', '{"size": 1000}');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.throws($$
  insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-0000-0000-0000-00000000000a/evil/x.jpg', '00000000-0000-0000-0000-00000000000b', null)$$,
  '42501', 'B cannot upload into A''s folder');
select t.ok((select count(*) from storage.objects) = 0, 'B cannot list A''s files');
select t.ok(not public.attachment_upload_allowed('00000000-0000-0000-0000-00000000000a/x/y.jpg', null),
  'attachment_upload_allowed() says nothing about A''s folder to B');
reset role;

-- Driver C attaches a photo to their own refueling in A's account.
select t.as_user('00000000-0000-0000-0000-00000000000c');
insert into public.attachments (owner_id, id, created_at, updated_at, vehicle_id, parent_table, parent_id, file_name, mime_type, size_bytes)
values ('00000000-0000-0000-0000-00000000000a', 'attc', now(), now(), 'v1', 'refuelings', 'rc1', 'c.jpg', 'image/jpeg', 10);
insert into storage.objects (bucket_id, name, owner, metadata)
values ('attachments', '00000000-0000-0000-0000-00000000000a/attc/c.jpg', '00000000-0000-0000-0000-00000000000c', '{"size": 1000}');
select t.ok(not public.can_read_attachment_object('00000000-0000-0000-0000-00000000000a/att1/a.jpg'),
  'driver cannot read the owner''s file on the owner''s record');
reset role;

-- Fill A's folder to 50 MB (as the service, like earlier uploads would).
insert into storage.objects (bucket_id, name, owner, metadata)
select 'attachments', '00000000-0000-0000-0000-00000000000a/fill' || g || '/f.jpg',
       '00000000-0000-0000-0000-00000000000a', '{"size": 3000000}'
from generate_series(1, 18) g;
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.throws($$
  insert into storage.objects (bucket_id, name, owner, metadata)
  values ('attachments', '00000000-0000-0000-0000-00000000000a/over/o.jpg', '00000000-0000-0000-0000-00000000000a', null)$$,
  '42501', 'upload refused once the folder holds 50 MB');
delete from storage.objects where name like '00000000-0000-0000-0000-00000000000a/fill1%';
insert into storage.objects (bucket_id, name, owner, metadata)
values ('attachments', '00000000-0000-0000-0000-00000000000a/after/o.jpg', '00000000-0000-0000-0000-00000000000a', null);
reset role;
select t.ok(true, 'upload allowed again after deleting files');

-- ---------------------------------------------------------------------------
-- Transfer codes (S6)
-- ---------------------------------------------------------------------------

select t.as_user('00000000-0000-0000-0000-00000000000a');
create temp table code as select code from public.create_transfer('v1');
reset role;
grant select on code to authenticated;

-- Buyer E guesses: unknown codes return no rows and are counted.
select t.as_user('00000000-0000-0000-0000-00000000000e');
select t.ok((select count(*) from public.redeem_transfer('AAAA-AAA' || g)) = 0, 'wrong code ' || g || ' → no rows')
from generate_series(2, 9) g;
select t.ok((select count(*) from public.redeem_transfer('BBBBBBB2')) = 0, 'wrong code 9 → no rows');
select t.ok((select count(*) from public.redeem_transfer('BBBBBBB3')) = 0, 'wrong code 10 → no rows');
select t.throws($$select * from public.redeem_transfer('BBBBBBB4')$$,
  'transfer_rate_limited', '11th wrong code within an hour is refused');
select t.throws(format('select * from public.redeem_transfer(%L)', (select code from code)),
  'transfer_rate_limited', 'even the right code waits out the limit');
reset role;
select t.ok((select count(*) from public.transfer_attempts) = 10, 'attempts recorded despite the empty result');

-- Buyer F redeems the real code.
select t.as_user('00000000-0000-0000-0000-00000000000f');
select t.ok((select vehicle_id from public.redeem_transfer((select code from code))) = 'v1', 'buyer redeems the code');
select t.ok((select count(*) from public.vehicles) = 1, 'buyer got the vehicle');
select t.ok((select count(*) from public.refuelings where created_by is null) = 2,
  'buyer got the vehicle''s records (owner''s + member''s) as their own');
select t.ok((select count(*) from public.attachments) = 2, 'buyer got the attachment rows');
select t.ok(public.can_read_attachment_object('00000000-0000-0000-0000-00000000000a/att1/a.jpg'),
  'buyer may download the transferred file (to re-home it)');
select t.throws(format('select * from public.redeem_transfer(%L)', (select code from code)),
  'transfer_used|vehicle_exists', 'a code works once');
reset role;
select t.ok((select row_bytes from public.sync_usage where owner_id = '00000000-0000-0000-0000-00000000000f') > 0,
  'transferred rows count toward the buyer''s quota');

-- Code creation is capped at 20 per day.
select t.as_user('00000000-0000-0000-0000-00000000000a');
do $$ begin for i in 1..19 loop perform public.create_transfer('v2'); end loop; end $$;
select t.throws($$select * from public.create_transfer('v2')$$,
  'transfer_rate_limited', '21st code in a day is refused');
reset role;

-- ---------------------------------------------------------------------------
-- Profiles and account deletion
-- ---------------------------------------------------------------------------

select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.throws($$insert into public.profiles (id, first_name) values ('00000000-0000-0000-0000-00000000000b', repeat('x', 101))$$,
  'profiles_field_lengths', 'a 101-character first name is refused');
insert into public.profiles (id, first_name) values ('00000000-0000-0000-0000-00000000000b', 'Bee');
select t.throws($$insert into public.profiles (id, first_name) values ('00000000-0000-0000-0000-00000000000a', 'Mallory')$$,
  '42501', 'B cannot write A''s profile');
select public.delete_my_account();
reset role;
select t.ok(not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-00000000000b'),
  'delete_my_account() works with the usage triggers in place');
select t.ok(not exists (select 1 from public.sync_usage where owner_id = '00000000-0000-0000-0000-00000000000b'),
  'usage row removed with the account');

-- ---------------------------------------------------------------------------
-- Every public table has RLS; no SECURITY DEFINER function lacks search_path
-- ---------------------------------------------------------------------------

select t.ok(not exists (
  select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  'RLS enabled on every public table');
select t.ok(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  'every SECURITY DEFINER function pins search_path');
select t.ok(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')
    and p.prorettype <> 'trigger'::regtype),
  'anon can execute no SECURITY DEFINER function');
