-- grants: same as the shared project. Row-level security does the scoping; anon may read
-- (and gets nothing back) from tables, may not touch the active_* views, and never writes.

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select, insert, update, delete, truncate, references, trigger on
  public.companies, public.company_members, public.properties, public.tenants, public.leases,
  public.rent_log, public.expense_recurring_rules, public.expenses, public.maintenance_requests,
  public.tenant_documents, public.property_tax_history, public.property_insurance_history,
  public.tenant_messages, public.reimbursement_requests, public.applications,
  public.application_messages, public.property_hoa, public.hoa_history, public.receipts,
  public.property_mortgage_activity, public.property_finance_history,
  public.incoming_rent_payments, public.payment_settings, public.tenant_payer_aliases,
  public.active_companies, public.active_expenses, public.active_leases,
  public.active_maintenance_requests, public.active_properties, public.active_rent_log,
  public.property_monthly_costs, public.public_listings
  to authenticated;

grant select, references, trigger on
  public.companies, public.company_members, public.properties, public.tenants, public.leases,
  public.rent_log, public.expense_recurring_rules, public.expenses, public.maintenance_requests,
  public.tenant_documents, public.property_tax_history, public.property_insurance_history,
  public.tenant_messages, public.reimbursement_requests, public.applications,
  public.application_messages, public.property_hoa, public.hoa_history, public.receipts,
  public.property_mortgage_activity, public.property_finance_history,
  public.incoming_rent_payments, public.payment_settings, public.public_listings
  to anon;

grant usage, select, update on all sequences in schema public to anon, authenticated;

-- functions
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function
  public.auto_unpublish_listing(), public.block_tenant_email_change(), public.claim_my_applications(),
  public.is_company_member(uuid), public.rg_auth_email(), public.rg_cascade_property_rename(),
  public.rg_fill_property_id_by_company(), public.rg_normalize_name(text),
  public.rg_sync_property_status(uuid), public.rg_tenant_id_for_auth_user(),
  public.rg_tenants_limit_self_update(), public.rg_try_uuid(text),
  public.set_company_id_from_property(), public.set_owner_and_property_ids(),
  public.trg_sync_property_status_from_leases(), public.trigger_maintenance_acknowledgment()
  to public;

grant execute on function
  public.archive_expense(integer), public.archive_lease(uuid), public.archive_maintenance_request(integer),
  public.archive_property(uuid), public.archive_rent_log(uuid),
  public.unarchive_expense(integer), public.unarchive_lease(uuid), public.unarchive_maintenance_request(integer),
  public.unarchive_property(uuid), public.unarchive_rent_log(uuid),
  public.rg_can_access_property(uuid), public.rg_company_access(uuid),
  public.rg_confirm_incoming_payment(uuid, uuid, date, boolean), public.rg_dismiss_incoming_payment(uuid),
  public.rg_is_tenant_of_company(uuid), public.rg_rent_schedule(uuid, date), public.rg_rent_status(uuid, date),
  public.rg_tenant_can_file(uuid, uuid, uuid), public.tenant_set_preferred_payment_method(uuid, text)
  to authenticated;

-- service role only (it keeps execute through the project defaults):
--   rg_fill_property_id_from_name, rg_ingest_payment_email, rg_maintenance_webhook_secret,
--   rg_set_company_owner, rg_store_inbox_verification, rg_sync_company_from_property

-- storage: private buckets, opened through signed links

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('maintenance-photos', 'maintenance-photos', false, 10485760,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif']),
  ('receipts', 'receipts', false, 10485760,
   array['application/pdf','image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif']),
  ('tenant-documents', 'tenant-documents', false, 20971520,
   array['application/pdf','image/jpeg','image/png','image/webp','image/heic','image/heif','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do nothing;

create policy "Users read own receipts" on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'receipts'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));
create policy "Users upload own receipts" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'receipts'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));
create policy rg_maint_photos_select on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'maintenance-photos'::text) AND (EXISTS ( SELECT 1
   FROM public.maintenance_requests m
  WHERE (jsonb_exists(m.photo_paths, objects.name) OR ((m.photo_urls)::text ~~ (('%'::text || objects.name) || '%'::text)))))));
create policy rg_receipts_landlord_insert on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'receipts'::text) AND ((storage.foldername(name))[1] = 'expenses'::text) AND public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[2]))));
create policy rg_receipts_landlord_select on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'receipts'::text) AND ((storage.foldername(name))[1] = 'expenses'::text) AND public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[2]))));
create policy rg_receipts_reimb_select on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'receipts'::text) AND (EXISTS ( SELECT 1
   FROM public.reimbursement_requests r
  WHERE ((r.receipt_path = objects.name) OR (r.receipt_url ~~ ('%'::text || objects.name)))))));
create policy rg_tenant_docs_delete on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'tenant-documents'::text) AND public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1]))));
create policy rg_tenant_docs_insert on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'tenant-documents'::text) AND public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1]))));
create policy rg_tenant_docs_select on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'tenant-documents'::text) AND (public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1])) OR (EXISTS ( SELECT 1
   FROM public.tenant_documents d
  WHERE ((d.file_path = objects.name) OR (d.file_url ~~ ('%'::text || objects.name))))))));
create policy rg_tenant_docs_update on storage.objects as permissive for update to authenticated
  using (((bucket_id = 'tenant-documents'::text) AND public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1]))))
  with check (((bucket_id = 'tenant-documents'::text) AND public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1]))));
create policy tenant_read_own_maintenance_photos on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'maintenance-photos'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
create policy tenant_upload_own_maintenance_photos on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'maintenance-photos'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
