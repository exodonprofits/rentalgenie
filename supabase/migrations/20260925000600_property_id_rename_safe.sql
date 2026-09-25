-- Property identity: match on property_id, and make renaming a property safe
--
-- Every table that stores a property already has a property_id with a foreign key, and every row
-- was already correct (audited: 0 missing, 0 dangling, 1 stale name). But several places still
-- matched on the property NAME, so renaming a property would have silently broken them:
--   * rg_rent_schedule matched rent_log to the lease's property by name, so after a rename every
--     past payment stopped counting and the whole history would show as unpaid.
--   * Rows keep the old property_name, and most pages still filter by name.
-- This migration:
--   1. rg_rent_schedule: payments match on property_id (name only for rows with no id).
--   2. rg_cascade_property_rename: renaming a property updates property_name everywhere.
--   3. tenant_documents / tenant_messages get a property_id (backfilled, filled on insert).
--   4. set_company_id_from_property read properties.organization_id, which doesn't exist, so a
--      rent_log insert without company_id failed. It now reads company_id.
--   5. set_owner_and_property_ids resolves a name within the row's company only.
--   6. Occupancy sync works by property_id and counts holdover / month-to-month as occupied.
--   7. One stale application name is corrected.

-- 1. Rent schedule: payments by property_id --------------------------------------------------
create or replace function public.rg_rent_schedule(p_company_id uuid default null::uuid, p_as_of date default current_date)
 returns table(property_id uuid, property_name text, company_id uuid, lease_id uuid, tenant_name text, lease_state text, rent_amount numeric, due_day integer, grace_days integer, lease_end date, charge_end date, due_date date, paid numeric, balance numeric)
 language sql
 stable
 set search_path to 'public'
as $function$
with lease_pick as (
  select distinct on (p.id)
    p.id as property_id, p.name as property_name, p.company_id,
    l.id as lease_id, l.tenant_name,
    lower(coalesce(l.status, ''))     as lstatus,
    lower(coalesce(l.lease_type, '')) as ltype,
    l.lease_start, l.lease_end, l.terminated_date,
    l.rent_amount::numeric as rent_amount,
    coalesce(l.rent_due_day, l.due_day, extract(day from l.lease_start)::int) as due_day,
    coalesce(l.grace_period, l.late_fee_grace_days, 0)::int as grace_days
  from public.properties p
  join public.leases l
    on l.property_id = p.id
    or (l.property_id is null and l.property_name = p.name
        and l.company_id is not distinct from p.company_id)
  where p.archived_at is null
    and l.archived_at is null
    and (p_company_id is null or p.company_id = p_company_id)
    and l.lease_start is not null
    and l.lease_start <= p_as_of
    and coalesce(l.rent_amount, 0) > 0
  order by p.id, l.lease_start desc
),
windowed as (
  select lp.*,
    case
      when lp.terminated_date is not null then least(lp.terminated_date, p_as_of)
      when lp.lstatus = 'terminated'      then least(coalesce(lp.lease_end, p_as_of), p_as_of)
      else p_as_of
    end as charge_end,
    case
      when lp.terminated_date is not null or lp.lstatus = 'terminated' then 'ended'
      when lp.ltype like '%month%' or lp.ltype = 'm2m'
        or lp.lstatus in ('month_to_month', 'holdover')             then 'month_to_month'
      when lp.lease_end is not null and lp.lease_end < p_as_of      then 'holdover'
      else 'active'
    end as lease_state
  from lease_pick lp
),
dues as (
  select w.property_id,
         (m::date + (least(w.due_day,
            extract(day from (m + interval '1 month' - interval '1 day'))::int) - 1)) as due_date
  from windowed w
  cross join lateral generate_series(
    date_trunc('month', w.lease_start),
    date_trunc('month', w.charge_end),
    interval '1 month') as m
),
pay as (
  select w.property_id, r.applied_to_due_date as due_date, sum(r.amount::numeric) as paid
  from windowed w
  join public.rent_log r
    on (r.property_id = w.property_id
        or (r.property_id is null and r.property_name = w.property_name))
   and r.company_id is not distinct from w.company_id
   and r.archived_at is null
   and r.applied_to_due_date is not null
  group by w.property_id, r.applied_to_due_date
)
select
  w.property_id, w.property_name, w.company_id, w.lease_id, w.tenant_name, w.lease_state,
  w.rent_amount, w.due_day, w.grace_days, w.lease_end, w.charge_end,
  d.due_date,
  coalesce(pay.paid, 0),
  greatest(w.rent_amount - coalesce(pay.paid, 0), 0)
from windowed w
join dues d on d.property_id = w.property_id
left join pay on pay.property_id = d.property_id and pay.due_date = d.due_date
where d.due_date >= w.lease_start and d.due_date <= w.charge_end;
$function$;

-- 3. property_id on tenant_documents / tenant_messages ---------------------------------------
alter table public.tenant_documents add column if not exists property_id uuid
  references public.properties(id) on delete set null;
alter table public.tenant_messages add column if not exists property_id uuid
  references public.properties(id) on delete set null;

update public.tenant_documents d set property_id = p.id
  from public.properties p
 where d.property_id is null and p.company_id = d.company_id and p.name = d.property_name;
update public.tenant_messages m set property_id = p.id
  from public.properties p
 where m.property_id is null and p.company_id = m.company_id and p.name = m.property_name;

-- Fills property_id from (company_id, property_name). Definer so it also works for the service
-- role (the maintenance acknowledgment); it only ever looks inside the row's own company, and the
-- table's insert policy still decides whether the row may be written.
create or replace function public.rg_fill_property_id_by_company()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if new.property_id is null and new.property_name is not null and new.company_id is not null then
    select p.id into new.property_id
      from public.properties p
     where p.company_id = new.company_id and p.name = new.property_name
     order by p.created_at
     limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_rg_fill_property_id on public.tenant_documents;
create trigger trg_rg_fill_property_id before insert or update of property_name, company_id
  on public.tenant_documents for each row execute function public.rg_fill_property_id_by_company();
drop trigger if exists trg_rg_fill_property_id on public.tenant_messages;
create trigger trg_rg_fill_property_id before insert or update of property_name, company_id
  on public.tenant_messages for each row execute function public.rg_fill_property_id_by_company();

-- 2. Renaming a property renames it everywhere -----------------------------------------------
create or replace function public.rg_cascade_property_rename()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if new.name is not distinct from old.name then
    return null;
  end if;

  update public.leases                 set property_name = new.name where property_id = new.id;
  update public.rent_log               set property_name = new.name where property_id = new.id;
  update public.expenses               set property_name = new.name where property_id = new.id;
  update public.maintenance_requests   set property_name = new.name where property_id = new.id;
  update public.applications           set property_name = new.name where property_id = new.id;
  update public.hoa_history            set property_name = new.name where property_id = new.id;
  update public.property_hoa           set property_name = new.name where property_id = new.id;
  update public.incoming_rent_payments set property_name = new.name where property_id = new.id;
  update public.reimbursement_requests set property_name = new.name where property_id = new.id;
  update public.escrow_transactions    set property_name = new.name where property_id = new.id;
  update public.tenant_documents       set property_name = new.name
   where property_id = new.id or (property_id is null and company_id = new.company_id and property_name = old.name);
  update public.tenant_messages        set property_name = new.name
   where property_id = new.id or (property_id is null and company_id = new.company_id and property_name = old.name);
  -- tenants has no company or property id: rename the rows of this property's tenants only.
  update public.tenants t set property_name = new.name
   where t.property_name = old.name
     and exists (select 1 from public.leases l
                  where l.property_id = new.id and lower(l.tenant_email) = lower(t.email));
  return null;
end;
$$;

drop trigger if exists trg_rg_cascade_property_rename on public.properties;
create trigger trg_rg_cascade_property_rename after update of name on public.properties
  for each row execute function public.rg_cascade_property_rename();

-- 4. rent_log company fill -------------------------------------------------------------------
create or replace function public.set_company_id_from_property()
returns trigger
language plpgsql
as $function$
begin
  if new.company_id is null and new.property_id is not null then
    select company_id into new.company_id from public.properties where id = new.property_id;
  end if;
  return new;
end
$function$;

-- 5. Name lookup stays inside the row's company -----------------------------------------------
create or replace function public.set_owner_and_property_ids()
returns trigger
language plpgsql
as $function$
declare
  p record;
begin
  if (new.property_id is null) and (new.property_name is not null) then
    select id, owner_id into p
      from public.properties
     where name = new.property_name
       and (new.company_id is null or company_id = new.company_id)
     order by created_at desc
     limit 1;
    if p.id is not null then
      new.property_id := p.id;
      new.owner_id := p.owner_id;
    end if;
  end if;

  if (new.property_id is not null) and (new.owner_id is null) then
    select owner_id into new.owner_id from public.properties where id = new.property_id;
  end if;

  return new;
end
$function$;

-- 6. Occupancy sync by property_id -----------------------------------------------------------
create or replace function public.rg_sync_property_status(p_property_id uuid)
returns void
language plpgsql
as $$
declare
  v_occupied boolean;
begin
  if p_property_id is null then return; end if;
  select exists (
    select 1 from public.leases l
     where l.property_id = p_property_id
       and l.archived_at is null
       and lower(coalesce(l.status, '')) not in ('draft', 'terminated')
       and (l.lease_start is null or l.lease_start <= current_date)
       and (l.terminated_date is null or l.terminated_date > current_date)
       -- holdover and month-to-month keep the property occupied after lease_end
       and (l.lease_end is null or l.lease_end >= current_date
            or lower(coalesce(l.status, '')) in ('holdover', 'month_to_month', 'signed', 'active', 'current')
            or lower(coalesce(l.lease_type, '')) like '%month%')
  ) into v_occupied;

  update public.properties
     set status = case when v_occupied then 'occupied' else 'vacant' end
   where id = p_property_id;
end;
$$;

create or replace function public.trg_sync_property_status_from_leases()
returns trigger
language plpgsql
as $function$
begin
  if tg_op = 'DELETE' then
    perform public.rg_sync_property_status(old.property_id);
    return null;
  end if;
  perform public.rg_sync_property_status(new.property_id);
  if tg_op = 'UPDATE' and old.property_id is distinct from new.property_id then
    perform public.rg_sync_property_status(old.property_id);
  end if;
  return null;
end;
$function$;

select public.rg_sync_property_status(id) from public.properties;

-- 7. Stale names ------------------------------------------------------------------------------
update public.applications a set property_name = p.name
  from public.properties p
 where a.property_id = p.id and a.property_name is distinct from p.name;
