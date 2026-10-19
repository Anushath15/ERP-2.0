-- ASK ERP 2.0: the cloud enforces "owner only" actions itself (docs/threat-model.md), so a changed program or a direct API call by a
-- cashier or manager cannot cancel a bill, write off a due, or change the shop profile / shared settings.
-- Run once in Supabase > SQL Editor, after 0001 and 0002.

create or replace function public.push_docs(p_shop uuid, p_device text, p_docs jsonb)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  d jsonb;
  v_role text;
begin
  select role into v_role from shop_members where shop_id = p_shop and user_id = auth.uid() and active;
  if v_role is null then raise exception 'not a member of this shop' using errcode = '42501'; end if;
  if exists (select 1 from devices where shop_id = p_shop and device_id = p_device and revoked) then
    raise exception 'this computer was removed by the owner' using errcode = '42501';
  end if;
  if jsonb_typeof(p_docs) <> 'array' or jsonb_array_length(p_docs) > 100 then
    raise exception 'a batch holds at most 100 documents' using errcode = '22023';
  end if;
  insert into devices (shop_id, device_id) values (p_shop, p_device) on conflict do nothing;
  -- one push per shop at a time, so seq order equals commit order and a pull cursor never skips rows
  perform pg_advisory_xact_lock(hashtextextended(p_shop::text, 0));

  for d in select * from jsonb_array_elements(p_docs) loop
    if v_role = 'cashier' and d->>'coll' in ('products','categories','customers','dealers') then
      raise exception 'cashiers cannot change %', d->>'coll' using errcode = '42501';
    end if;
    if v_role <> 'owner' and d->>'coll' = 'settings' then
      raise exception 'only the owner can change shop settings' using errcode = '42501';
    end if;
    if v_role <> 'owner' and d->>'coll' = 'bill_cancellations' then
      raise exception 'only the owner can cancel bills' using errcode = '42501';
    end if;
    if v_role <> 'owner' and d->>'coll' = 'ledger_entries' and d->'data'->>'kind' = 'writeOff' then
      raise exception 'only the owner can write off dues' using errcode = '42501';
    end if;
    -- a bill is marked cancelled in the bill itself too: only the owner may turn that on
    if v_role <> 'owner' and d->>'coll' = 'bills' and coalesce(d->'data'->>'cancelled', '0') in ('1', 'true')
       and not exists (select 1 from sync_docs s where s.shop_id = p_shop and s.coll = 'bills' and s.id = d->>'id'
                       and coalesce(s.data->>'cancelled', '0') in ('1', 'true')) then
      raise exception 'only the owner can cancel bills' using errcode = '42501';
    end if;
    if public.is_append_only(d->>'coll') then
      insert into sync_docs (shop_id, coll, id, data, hlc, deleted, device_id)
      values (p_shop, d->>'coll', d->>'id', d->'data', coalesce(d->>'hlc',''), false, p_device)
      on conflict do nothing;
    else
      insert into sync_docs (shop_id, coll, id, data, hlc, deleted, device_id)
      values (p_shop, d->>'coll', d->>'id', d->'data', coalesce(d->>'hlc',''),
              coalesce((d->>'deleted')::boolean, false), p_device)
      on conflict (shop_id, coll, id) do update
        set data = excluded.data, hlc = excluded.hlc, deleted = excluded.deleted, device_id = excluded.device_id,
            seq = (select nextval(pg_get_serial_sequence('public.sync_docs','seq'))), server_at = now()
        where excluded.hlc > sync_docs.hlc;
    end if;
  end loop;
  return now();
end $$;
revoke execute on function public.push_docs from public, anon;
grant execute on function public.push_docs to authenticated;
