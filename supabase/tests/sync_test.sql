-- Run against a throwaway Postgres: psql -v ON_ERROR_STOP=1 -f sync_test.sql
-- Stubs the bits Supabase provides (auth.users, auth.uid(), roles), loads the migration, then checks the rules.
\set ON_ERROR_STOP on
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
grant usage on schema auth, public to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
\i ../migrations/0001_sync.sql
\i ../migrations/0002_sync_names.sql
\i ../migrations/0003_owner_only_actions.sql
grant select on all tables in schema public to authenticated, anon;  -- Supabase grants these by default; RLS does the filtering

insert into auth.users values ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b'), ('00000000-0000-0000-0000-00000000000d'),
  ('00000000-0000-0000-0000-00000000000c');
insert into shops (id, name) values ('11111111-1111-1111-1111-111111111111', 'Shop'), ('22222222-2222-2222-2222-222222222222', 'Other');
insert into shop_members values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'owner', true),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000b', 'cashier', true),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000d', 'manager', true);

create function pg_temp.expect_fail(sql text, msg text) returns void language plpgsql as $$
begin
  begin execute sql; exception when others then return; end;
  raise exception 'EXPECTED FAILURE DID NOT HAPPEN: %', msg;
end $$;
create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if not ok then raise exception 'FAILED: %', msg; end if; raise notice 'ok: %', msg; end $$;

set role authenticated;
set test.uid = '00000000-0000-0000-0000-00000000000a';  -- owner

select push_docs('11111111-1111-1111-1111-111111111111', 'A', '[
  {"coll":"products","id":"p1","data":{"name":"Rice"},"hlc":"0002-0000-A"},
  {"coll":"bill_lines","id":"b1","data":{"total":100},"hlc":"0001-0000-A"}]');
select pg_temp.check((select count(*) from sync_docs) = 2, 'owner push stores 2 docs');

-- re-send of an append-only bill with changed data is a no-op
select push_docs('11111111-1111-1111-1111-111111111111', 'A', '[{"coll":"bill_lines","id":"b1","data":{"total":999},"hlc":"0009-0000-A"}]');
select pg_temp.check((select data->>'total' from sync_docs where id = 'b1') = '100', 'append-only record never changes');
select pg_temp.check((select count(*) from sync_docs) = 2, 're-send adds no row');

-- older hlc loses, newer wins
select push_docs('11111111-1111-1111-1111-111111111111', 'B', '[{"coll":"products","id":"p1","data":{"name":"Old"},"hlc":"0001-0000-B"}]');
select pg_temp.check((select data->>'name' from sync_docs where id = 'p1') = 'Rice', 'older edit loses');
select push_docs('11111111-1111-1111-1111-111111111111', 'B', '[{"coll":"products","id":"p1","data":{"name":"New"},"hlc":"0003-0000-B"}]');
select pg_temp.check((select data->>'name' from sync_docs where id = 'p1') = 'New', 'newer edit wins');

-- an edited record is delivered again to a pulling device (seq moved forward)
select pg_temp.check((select count(*) from pull_docs('11111111-1111-1111-1111-111111111111', 0)) = 2, 'pull sees both docs');
select pg_temp.check((select seq from sync_docs where id = 'p1') > (select seq from sync_docs where id = 'b1'), 'edited doc has a later seq');
select pg_temp.check((select count(*) from pull_docs('11111111-1111-1111-1111-111111111111', (select seq from sync_docs where id = 'p1'))) = 0, 'cursor at last seq returns nothing');

-- 101 docs refused
select pg_temp.expect_fail($q$select push_docs('11111111-1111-1111-1111-111111111111', 'A',
  (select jsonb_agg(jsonb_build_object('coll','bills','id','x'||g,'data','{}'::jsonb,'hlc','1')) from generate_series(1,101) g))$q$,
  '101 documents refused');
select pg_temp.check((select count(*) from sync_docs) = 2, 'refused batch stored nothing');

-- direct writes are not allowed
select pg_temp.expect_fail($q$insert into sync_docs (shop_id, coll, id, data, device_id) values ('11111111-1111-1111-1111-111111111111','bills','z','{}','A')$q$, 'direct insert blocked');
select pg_temp.expect_fail($q$update sync_docs set data = '{}'$q$, 'direct update blocked');

-- cashier: may write bills, not products; a bad doc rolls back the whole batch
set test.uid = '00000000-0000-0000-0000-00000000000b';
select push_docs('11111111-1111-1111-1111-111111111111', 'C', '[{"coll":"bills","id":"b2","data":{},"hlc":"1"}]');
select pg_temp.check((select count(*) from sync_docs) = 3, 'cashier can push a bill');
select pg_temp.expect_fail($q$select push_docs('11111111-1111-1111-1111-111111111111', 'C', '[
  {"coll":"bills","id":"b3","data":{},"hlc":"1"},{"coll":"products","id":"p9","data":{},"hlc":"1"}]')$q$, 'cashier product write blocked');
select pg_temp.check((select count(*) from sync_docs) = 3, 'failed batch is atomic (b3 not stored)');

-- outsider and wrong shop
set test.uid = '00000000-0000-0000-0000-00000000000c';
select pg_temp.expect_fail($q$select push_docs('11111111-1111-1111-1111-111111111111', 'D', '[]')$q$, 'non-member push blocked');
select pg_temp.check((select count(*) from sync_docs) = 0, 'non-member reads nothing');
set test.uid = '00000000-0000-0000-0000-00000000000a';
select pg_temp.expect_fail($q$select push_docs('22222222-2222-2222-2222-222222222222', 'A', '[]')$q$, 'owner of shop 1 cannot push to shop 2');

-- revoked device
reset role;
update devices set revoked = true where device_id = 'C';
set role authenticated; set test.uid = '00000000-0000-0000-0000-00000000000b';
select pg_temp.expect_fail($q$select push_docs('11111111-1111-1111-1111-111111111111', 'C', '[]')$q$, 'revoked device blocked');

-- anon can only ping
set role anon; set test.uid = '';
select pg_temp.check(ping() is not null, 'anon can call ping');
select pg_temp.expect_fail($q$select push_docs('11111111-1111-1111-1111-111111111111', 'A', '[]')$q$, 'anon cannot push');
select pg_temp.check((select count(*) from sync_docs) = 0, 'anon reads nothing');
-- (as the owner again)
set role authenticated; set test.uid = '00000000-0000-0000-0000-00000000000a';
-- a bill is edited (status, payment marks): the newer stamp wins, an older one loses
select push_docs('11111111-1111-1111-1111-111111111111', 'A', '[{"coll":"bills","id":"bb","data":{"paid":0},"hlc":"0001-0000-A"}]');
select push_docs('11111111-1111-1111-1111-111111111111', 'B', '[{"coll":"bills","id":"bb","data":{"paid":5},"hlc":"0002-0000-B"}]');
select push_docs('11111111-1111-1111-1111-111111111111', 'A', '[{"coll":"bills","id":"bb","data":{"paid":1},"hlc":"0001-0001-A"}]');
select pg_temp.check((select data->>'paid' from sync_docs where id = 'bb') = '5', 'bills follow last-writer-wins');

-- owner-only actions (docs/threat-model.md): cancel a bill, write off a due, shop settings
set role authenticated;
set test.uid = '00000000-0000-0000-0000-00000000000a';
select push_docs('11111111-1111-1111-1111-111111111111', 'A', '[{"coll":"bills","id":"bc","data":{"cancelled":0},"hlc":"0001-0000-A"}]');
do $$ declare r text; u text; begin
  foreach u in array array['00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000d'] loop
    perform set_config('test.uid', u, false);
    foreach r in array array['bill_cancellations','settings'] loop
      begin
        perform push_docs('11111111-1111-1111-1111-111111111111', 'X', jsonb_build_array(jsonb_build_object('coll', r, 'id', 'z1', 'data', '{}'::jsonb, 'hlc', '5')));
        raise exception 'NOT BLOCKED: % by %', r, u;
      exception when insufficient_privilege then null; end;
    end loop;
    begin
      perform push_docs('11111111-1111-1111-1111-111111111111', 'X', '[{"coll":"ledger_entries","id":"w1","data":{"kind":"writeOff"},"hlc":"5"}]');
      raise exception 'NOT BLOCKED: write-off by %', u;
    exception when insufficient_privilege then null; end;
    begin
      perform push_docs('11111111-1111-1111-1111-111111111111', 'X', '[{"coll":"bills","id":"bc","data":{"cancelled":1},"hlc":"9"}]');
      raise exception 'NOT BLOCKED: bill cancelled flag by %', u;
    exception when insufficient_privilege then null; end;
    -- ordinary work still goes through
    perform push_docs('11111111-1111-1111-1111-111111111111', 'X', jsonb_build_array(jsonb_build_object('coll', 'ledger_entries', 'id', 'pay-' || u, 'data', '{"kind":"payment"}'::jsonb, 'hlc', '5')));
  end loop;
  raise notice 'ok: cashier and manager cannot cancel bills, write off dues or change settings; payments still work';
end $$;
set test.uid = '00000000-0000-0000-0000-00000000000a';
select push_docs('11111111-1111-1111-1111-111111111111', 'A', '[{"coll":"bill_cancellations","id":"bcx","data":{},"hlc":"6"},{"coll":"ledger_entries","id":"w2","data":{"kind":"writeOff"},"hlc":"6"},{"coll":"settings","id":"shop.profile","data":{},"hlc":"6"},{"coll":"bills","id":"bc","data":{"cancelled":1},"hlc":"10"}]');
select pg_temp.check((select data->>'cancelled' from sync_docs where id = 'bc') = '1', 'the owner can cancel a bill, write off a due and change settings');
reset role;
