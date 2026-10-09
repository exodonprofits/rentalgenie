-- rg_09: link every rent payment to its tenant (pre-launch audit F-05)
--
-- Tenants see rent_log rows only through rent_log_select_tenant_self, which matches
-- tenant_id or tenant_email. None of the writers (add-payment, the Lease & Rent Center
-- modal and drawer, rg_confirm_incoming_payment) set either, so every payment logged
-- since August was invisible in the tenant portal.
--
-- Fix: a BEFORE INSERT OR UPDATE trigger fills lease_id, tenant_id and tenant_email from
-- the matching lease when the writer left them empty, then a one-off backfill of the
-- existing unlinked rows. It only fills NULLs; it never overwrites a link a writer set.
--
-- Matching lease: the given lease_id if present, otherwise a non-archived lease of the
-- same company and property with the same tenant name (case and spaces ignored),
-- preferring the latest lease that started on or before the payment's due/paid date,
-- then the latest lease overall.
--
-- The trigger is named so it fires after trg_rent_log_company and
-- trg_rent_log_owner_property, which fill company_id and property_id.

create or replace function public.rg_rent_log_fill_tenant_link()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_lease uuid;
  v_tenant uuid;
  v_email text;
  ref_date date;
begin
  if new.tenant_id is not null
     and coalesce(new.tenant_email, '') <> ''
     and new.lease_id is not null then
    return new;
  end if;

  if new.lease_id is not null then
    select id, tenant_id, tenant_email into v_lease, v_tenant, v_email
      from leases
     where id = new.lease_id and company_id = new.company_id;
  elsif new.company_id is not null
        and new.property_id is not null
        and coalesce(trim(new.tenant_name), '') <> '' then
    ref_date := coalesce(new.applied_to_due_date, new.due_date, new.date_paid, current_date);
    select id, tenant_id, tenant_email into v_lease, v_tenant, v_email
      from leases
     where company_id = new.company_id
       and property_id = new.property_id
       and archived_at is null
       and lower(trim(tenant_name)) = lower(trim(new.tenant_name))
     order by (lease_start is not null and lease_start <= ref_date) desc,
              lease_start desc nulls last,
              inserted_at desc nulls last
     limit 1;
  end if;

  if v_lease is not null then
    new.lease_id := coalesce(new.lease_id, v_lease);
    new.tenant_id := coalesce(new.tenant_id, v_tenant);
    if coalesce(new.tenant_email, '') = '' then
      new.tenant_email := nullif(v_email, '');
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function public.rg_rent_log_fill_tenant_link() from public, anon, authenticated;

create trigger trg_rent_log_tenant_link
  before insert or update on public.rent_log
  for each row execute function public.rg_rent_log_fill_tenant_link();

-- Backfill (applied 2026-10-09 as a separate statement after the trigger): a no-op update
-- re-runs the trigger on rows with no tenant link. It linked 26 rows (Aug 20 - Sep 25 2026).
update public.rent_log
   set tenant_name = tenant_name
 where tenant_id is null
   and coalesce(tenant_email, '') = '';
