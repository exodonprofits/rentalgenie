-- Tenant write scope
--
-- Closes three holes in the tenant-facing write policies:
--   1. leases_insert_own / leases_update_own / leases_delete_own only checked created_by, so any
--      signed-in user (a tenant included) could create a lease under any company's ID. That row
--      showed up in the other landlord's lease list and rent schedule, and would also satisfy any
--      "tenant must have a lease with this company" check.
--   2. Tenants could insert maintenance requests and messages tagged with any company_id,
--      property_id or tenant_id; the policies only checked tenant_email.
--   3. tenants_update_self let a tenant rewrite every column of their own row.
--
-- Applied as separate statements so a failure in one section doesn't roll back the others.

-- 1. Leases: creating, editing or deleting "your own" lease also requires access to its company.
alter policy leases_insert_own on public.leases
  with check (created_by = auth.uid() and public.rg_company_access(company_id));

alter policy leases_update_own on public.leases
  using      (created_by = auth.uid() and public.rg_company_access(company_id))
  with check (created_by = auth.uid() and public.rg_company_access(company_id));

alter policy leases_delete_own on public.leases
  using (created_by = auth.uid() and public.rg_company_access(company_id));

-- 2. Tenant inserts must point at a company (and property, when given) the tenant actually
--    leases from. Archived leases don't count; ended/terminated ones still do, so a tenant who
--    has moved out can still ask about a deposit.
create or replace function public.rg_tenant_can_file(p_company_id uuid, p_property_id uuid, p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
set row_security to 'off'
as $$
  select p_company_id is not null
    -- tenant_id, when given, must be the caller's own row. Same rule as tenants_select_self, so
    -- tenants whose row isn't linked to their auth user yet (matched by email) still pass.
    and (p_tenant_id is null or exists (
      select 1 from public.tenants t
      where t.id = p_tenant_id
        and (t.auth_user_id = auth.uid()
             or (t.auth_user_id is null and lower(t.email) = public.rg_auth_email()))
    ))
    and exists (
      select 1
      from public.leases l
      where l.company_id = p_company_id
        and l.archived_at is null
        and (p_property_id is null or l.property_id = p_property_id)
        and (lower(l.tenant_email) = public.rg_auth_email()
             or (l.tenant_id is not null and l.tenant_id = public.rg_tenant_id_for_auth_user()))
    );
$$;

revoke all on function public.rg_tenant_can_file(uuid, uuid, uuid) from public, anon;
grant execute on function public.rg_tenant_can_file(uuid, uuid, uuid) to authenticated;

alter policy maintenance_requests_insert_tenant_self on public.maintenance_requests
  with check (lower(tenant_email) = public.rg_auth_email()
              and public.rg_tenant_can_file(company_id, property_id, tenant_id));

-- tenant_messages has no property_id. sender must stay 'tenant' so a tenant can't post as the landlord.
alter policy tenant_messages_insert_tenant_self on public.tenant_messages
  with check (lower(tenant_email) = public.rg_auth_email()
              and sender = 'tenant'
              and public.rg_tenant_can_file(company_id, null, tenant_id));

-- 3. Tenants editing their own row may change phone only. Landlords (access to a company on one
--    of this tenant's leases), the service role and the SQL editor are unaffected. Compares the
--    whole row minus phone so columns added later are locked by default.
create or replace function public.rg_tenants_limit_self_update()
returns trigger
language plpgsql
security definer
set search_path to 'public'
set row_security to 'off'
as $$
begin
  if auth.uid() is null or old.auth_user_id is distinct from auth.uid() then
    return new;
  end if;
  if exists (select 1 from public.leases l
             where lower(l.tenant_email) = lower(old.email)
               and public.rg_company_access(l.company_id)) then
    return new;
  end if;
  if (to_jsonb(new) - 'phone') is distinct from (to_jsonb(old) - 'phone') then
    raise exception 'Tenants can only update their phone number.' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_tenants_limit_self_update on public.tenants;
create trigger trg_tenants_limit_self_update
  before update on public.tenants
  for each row execute function public.rg_tenants_limit_self_update();
