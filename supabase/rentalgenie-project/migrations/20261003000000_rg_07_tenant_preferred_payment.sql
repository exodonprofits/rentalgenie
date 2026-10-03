-- db: tenant_set_preferred_payment_method matches the lease the way the tenant can see it.
--
-- The tenant pages find a tenant's lease by tenant_id (tenants.auth_user_id) and fall back to the
-- email, the same two tests as the leases_select_tenant_self policy. The function only matched
-- tenant_email, so a tenant linked by id whose lease carried another email couldn't save a choice.
-- It now accepts either, skips archived leases, and only stores one of the methods the pages offer
-- (or null to clear it).

CREATE OR REPLACE FUNCTION public.tenant_set_preferred_payment_method(p_lease_id uuid, p_method text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_method text := nullif(trim(p_method), '');
begin
  if v_method is not null
     and v_method not in ('Zelle', 'Venmo', 'ACH', 'Check', 'Cash', 'Bank Transfer', 'Other') then
    raise exception 'Unsupported payment method: %', v_method using errcode = '22023';
  end if;

  update public.leases
  set tenant_preferred_payment_method = v_method,
      tenant_preferred_payment_method_updated_at = now()
  where id = p_lease_id
    and archived_at is null
    and (lower(tenant_email) = rg_auth_email()
         or (tenant_id is not null and tenant_id = rg_tenant_id_for_auth_user()));

  if not found then
    raise exception 'Lease not found or not owned by current tenant';
  end if;
end;
$function$;

revoke all on function public.tenant_set_preferred_payment_method(uuid, text) from public, anon;
grant execute on function public.tenant_set_preferred_payment_method(uuid, text) to authenticated;
