-- Shared project: lock the old Rental Genie tables read-only
--
-- Rental Genie moved to its own project (xqmnaeujwumlcoyhgzuk) on Sept 30 2026; the live site has used
-- it since Oct 1. Stale Rental Genie pages still on the web server point here, so writes are closed off:
-- reads keep working (nothing breaks for viewing), every write fails loudly. The service role is
-- untouched. Before locking, every table was checksum-compared with the new project: identical.
--
-- Tested rolled back first: the landlord still reads every row (rent_log 118) and rg_rent_status;
-- inserts fail with 42501 and the archive functions are refused.
--
-- Left writable on purpose: companies and company_members (Salon Genie and the other products'
-- provisioning uses them) and receipts (empty, may belong to another product).
--
-- Rollback: the GRANT/CREATE statements at the bottom, commented out.

do $$
declare t text;
begin
  foreach t in array array[
    'properties','tenants','leases','rent_log','expense_recurring_rules','expenses','maintenance_requests',
    'tenant_documents','property_tax_history','property_insurance_history','tenant_messages',
    'reimbursement_requests','applications','application_messages','property_hoa','hoa_history',
    'property_mortgage_activity','property_finance_history','incoming_rent_payments','payment_settings',
    'tenant_payer_aliases'] loop
    execute format('revoke insert, update, delete, truncate on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- SECURITY DEFINER write functions bypass table grants; take them away from API roles.
revoke execute on function
  public.archive_expense(integer), public.archive_lease(uuid), public.archive_maintenance_request(integer),
  public.archive_property(uuid), public.archive_rent_log(uuid),
  public.unarchive_expense(integer), public.unarchive_lease(uuid), public.unarchive_maintenance_request(integer),
  public.unarchive_property(uuid), public.unarchive_rent_log(uuid),
  public.rg_confirm_incoming_payment(uuid, uuid, date, boolean), public.rg_dismiss_incoming_payment(uuid),
  public.tenant_set_preferred_payment_method(uuid, text), public.claim_my_applications()
  from public, anon, authenticated;

-- Storage is left alone: changing policies on storage.objects needs an exclusive lock on a table the
-- other products upload through, and the Rental Genie buckets here are empty. With table writes
-- closed, a stale page could at most upload a file nothing points to.

-- Rollback (only if Rental Genie ever has to fall back to this project):
--   grant insert, update, delete, truncate on <each table above> to authenticated;  (anon had select only)
--   grant execute on function <each function above> to authenticated;  (claim_my_applications: to public)
