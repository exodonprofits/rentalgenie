-- foreign keys

alter table public.companies add constraint companies_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id);
alter table public.company_members add constraint company_members_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
alter table public.company_members add constraint company_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.properties add constraint fk_user FOREIGN KEY (user_id) REFERENCES auth.users(id);
alter table public.properties add constraint properties_company_fk FOREIGN KEY (company_id) REFERENCES companies(id);
alter table public.properties add constraint properties_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.properties add constraint properties_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.leases add constraint leases_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id);
alter table public.leases add constraint leases_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.leases add constraint leases_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.leases add constraint leases_property_fk FOREIGN KEY (property_id) REFERENCES properties(id);
alter table public.leases add constraint leases_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id);
alter table public.rent_log add constraint rent_log_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id);
alter table public.rent_log add constraint rent_log_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.rent_log add constraint rent_log_property_fk FOREIGN KEY (property_id) REFERENCES properties(id);
alter table public.rent_log add constraint rent_log_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id);
alter table public.expenses add constraint expenses_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id);
alter table public.expenses add constraint expenses_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.expenses add constraint expenses_property_fk FOREIGN KEY (property_id) REFERENCES properties(id);
alter table public.expenses add constraint fk_expenses_recurring_rule FOREIGN KEY (recurring_rule_id) REFERENCES expense_recurring_rules(id) ON DELETE SET NULL;
alter table public.maintenance_requests add constraint maintenance_requests_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id);
alter table public.maintenance_requests add constraint maintenance_requests_property_fk FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.maintenance_requests add constraint maintenance_requests_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id);
alter table public.tenant_documents add constraint tenant_documents_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.tenant_documents add constraint tenant_documents_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id);
alter table public.property_tax_history add constraint property_tax_history_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.property_insurance_history add constraint property_insurance_history_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.tenant_messages add constraint tenant_messages_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.tenant_messages add constraint tenant_messages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id);
alter table public.reimbursement_requests add constraint reimbursement_requests_expense_id_fkey FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE SET NULL;
alter table public.reimbursement_requests add constraint reimbursement_requests_maintenance_request_id_fkey FOREIGN KEY (maintenance_request_id) REFERENCES maintenance_requests(id) ON DELETE SET NULL;
alter table public.applications add constraint applications_applicant_user_id_fkey FOREIGN KEY (applicant_user_id) REFERENCES auth.users(id);
alter table public.applications add constraint applications_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.applications add constraint applications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id);
alter table public.application_messages add constraint application_messages_application_id_fkey FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE;
alter table public.property_hoa add constraint property_hoa_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON UPDATE CASCADE ON DELETE CASCADE;
alter table public.hoa_history add constraint hoa_history_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON UPDATE CASCADE ON DELETE CASCADE;
alter table public.receipts add constraint receipts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.property_mortgage_activity add constraint property_mortgage_activity_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.property_finance_history add constraint property_finance_history_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.incoming_rent_payments add constraint incoming_rent_payments_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.payment_settings add constraint payment_settings_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.tenant_payer_aliases add constraint tenant_payer_aliases_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
alter table public.tenant_payer_aliases add constraint tenant_payer_aliases_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;

-- views

create or replace view public.active_companies with (security_invoker=true) as
 SELECT companies.id,
    companies.name,
    companies.created_at,
    companies.owner_user_id,
    companies.archived_at,
    companies.archived_by
   FROM companies
  WHERE (companies.archived_at IS NULL);

create or replace view public.active_expenses with (security_invoker=true) as
 SELECT expenses.id,
    expenses.property_name,
    expenses.date_paid,
    expenses.category,
    expenses.amount,
    expenses.note,
    expenses.vendor,
    expenses.company_id,
    expenses.receipt_url,
    expenses.is_planned,
    expenses.source,
    expenses.recurring_rule_id,
    expenses.details,
    expenses.property_id,
    expenses.owner_id,
    expenses.archived_at,
    expenses.archived_by
   FROM expenses
  WHERE (expenses.archived_at IS NULL);

create or replace view public.active_leases with (security_invoker=true) as
 SELECT leases.id,
    leases.property_name,
    leases.tenant_name,
    leases.lease_start,
    leases.lease_end,
    leases.rent_amount,
    leases.notes,
    leases.inserted_at,
    leases.tenant_email,
    leases.terms,
    leases.status,
    leases.sent_at,
    leases.signed_at,
    leases.sent_by,
    leases.signed_by,
    leases.rent_due_day,
    leases.late_fee_amount,
    leases.late_fee_grace_days,
    leases.due_day,
    leases.late_fee,
    leases.grace_period,
    leases.tenant_phone,
    leases.company_id,
    leases.management_type,
    leases.management_company_name,
    leases.management_company_email,
    leases.management_company_phone,
    leases.management_fee_type,
    leases.management_fee_value,
    leases.management_fee_cap,
    leases.management_fee_notes,
    leases.rent_collection_method,
    leases.rent_collection_notes,
    leases.management_fee_effective_start,
    leases.management_fee_effective_end,
    leases.property_id,
    leases.owner_id,
    leases.archived_at,
    leases.archived_by
   FROM leases
  WHERE (leases.archived_at IS NULL);

create or replace view public.active_maintenance_requests with (security_invoker=true) as
 SELECT maintenance_requests.id,
    maintenance_requests.property_name,
    maintenance_requests.tenant_email,
    maintenance_requests.issue_description,
    maintenance_requests.urgency_level,
    maintenance_requests.status,
    maintenance_requests.notes,
    maintenance_requests.created_at,
    maintenance_requests.company_id,
    maintenance_requests.assigned_vendor,
    maintenance_requests.estimated_cost,
    maintenance_requests.scheduled_at,
    maintenance_requests.completed_at,
    maintenance_requests.user_id,
    maintenance_requests.property_id,
    maintenance_requests.owner_id,
    maintenance_requests.archived_at,
    maintenance_requests.archived_by
   FROM maintenance_requests
  WHERE (maintenance_requests.archived_at IS NULL);

create or replace view public.active_properties with (security_invoker=true) as
 SELECT properties.id,
    properties.user_id,
    properties.name,
    properties.occupancy_status AS status,
    properties.address,
    properties.created_at,
    properties.notes,
    properties.purchase_date,
    properties.purchase_price,
    properties.is_financed,
    properties.monthly_payment,
    properties.lender_name,
    properties.loan_term,
    properties.financing_notes,
    properties.lender_portal_url,
    properties.loan_balance,
    properties.interest_rate,
    properties.loan_start_date,
    properties.loan_end_date,
    properties.company_id,
    properties.owner_id,
    properties.current_tenant,
    properties.current_rent,
    properties.property_type,
    properties.units,
    properties.year_built,
    properties.square_feet,
    properties.bedrooms,
    properties.bathrooms,
    properties.ownership_type,
    properties.down_payment,
    properties.closing_costs,
    properties.rehab_cost,
    properties.mortgage_pi,
    properties.tax_monthly,
    properties.insurance_monthly,
    properties.hoa_monthly,
    properties.pmi_monthly,
    properties.util_water,
    properties.util_gas,
    properties.util_electric,
    properties.util_trash,
    properties.util_lawn,
    properties.util_internet,
    properties.archived_at,
    properties.archived_by
   FROM properties
  WHERE (properties.archived_at IS NULL);

create or replace view public.active_rent_log with (security_invoker=true) as
 SELECT rent_log.id,
    rent_log.property_name,
    rent_log.tenant_name,
    rent_log.date_paid,
    rent_log.amount,
    rent_log.method,
    rent_log.note,
    rent_log.inserted_at,
    rent_log.company_id,
    rent_log.rent_period,
    rent_log.lease_id,
    rent_log.due_date,
    rent_log.applied_to_due_date,
    rent_log.tenant_email,
    rent_log.property_id,
    rent_log.owner_id,
    rent_log.archived_at,
    rent_log.archived_by
   FROM rent_log
  WHERE (rent_log.archived_at IS NULL);

create or replace view public.property_monthly_costs with (security_invoker=true) as
 SELECT properties.id,
    properties.name,
    ((((COALESCE(properties.mortgage_pi, (0)::numeric) + COALESCE(properties.tax_monthly, (0)::numeric)) + COALESCE(properties.insurance_monthly, (0)::numeric)) + COALESCE(properties.hoa_monthly, (0)::numeric)) + COALESCE(properties.pmi_monthly, (0)::numeric)) AS total_monthly_cost
   FROM properties;

create or replace view public.public_listings as
 SELECT p.id,
    p.name,
    p.address,
    p.property_type,
    p.units,
    p.bedrooms,
    p.bathrooms,
    p.square_feet,
    p.year_built,
    p.listing_rent,
    p.listing_deposit,
    p.listing_available_date,
    p.listing_description,
    p.listing_photos,
    p.listing_pet_policy,
    p.listing_contact_email,
    p.listing_contact_phone,
    p.listing_published_at
   FROM properties p
  WHERE (p.is_public_listing = true);

-- triggers

CREATE TRIGGER trg_rg_set_company_owner BEFORE INSERT ON public.companies FOR EACH ROW EXECUTE FUNCTION rg_set_company_owner();
CREATE TRIGGER trg_auto_unpublish_listing BEFORE UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION auto_unpublish_listing();
CREATE TRIGGER trg_rg_cascade_property_rename AFTER UPDATE OF name ON public.properties FOR EACH ROW EXECUTE FUNCTION rg_cascade_property_rename();
CREATE TRIGGER trg_block_tenant_email_change BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION block_tenant_email_change();
CREATE TRIGGER trg_tenants_limit_self_update BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION rg_tenants_limit_self_update();
CREATE TRIGGER leases_sync_property_status AFTER INSERT OR DELETE OR UPDATE ON public.leases FOR EACH ROW EXECUTE FUNCTION trg_sync_property_status_from_leases();
CREATE TRIGGER trg_leases_owner_property BEFORE INSERT OR UPDATE ON public.leases FOR EACH ROW EXECUTE FUNCTION set_owner_and_property_ids();
CREATE TRIGGER trg_rent_log_company BEFORE INSERT OR UPDATE ON public.rent_log FOR EACH ROW EXECUTE FUNCTION set_company_id_from_property();
CREATE TRIGGER trg_rent_log_owner_property BEFORE INSERT OR UPDATE ON public.rent_log FOR EACH ROW EXECUTE FUNCTION set_owner_and_property_ids();
CREATE TRIGGER trg_expenses_owner_property BEFORE INSERT OR UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION set_owner_and_property_ids();
CREATE TRIGGER maintenance_request_ack_webhook AFTER INSERT ON public.maintenance_requests FOR EACH ROW EXECUTE FUNCTION trigger_maintenance_acknowledgment();
CREATE TRIGGER trg_rg_fill_property_id BEFORE INSERT OR UPDATE OF property_name, company_id ON public.tenant_documents FOR EACH ROW EXECUTE FUNCTION rg_fill_property_id_by_company();
CREATE TRIGGER trg_rg_sync_company BEFORE INSERT OR UPDATE OF property_id, company_id ON public.property_tax_history FOR EACH ROW EXECUTE FUNCTION rg_sync_company_from_property();
CREATE TRIGGER trg_rg_sync_company BEFORE INSERT OR UPDATE OF property_id, company_id ON public.property_insurance_history FOR EACH ROW EXECUTE FUNCTION rg_sync_company_from_property();
CREATE TRIGGER trg_rg_fill_property_id BEFORE INSERT OR UPDATE OF property_name, company_id ON public.tenant_messages FOR EACH ROW EXECUTE FUNCTION rg_fill_property_id_by_company();
CREATE TRIGGER trg_rg_fill_property_id BEFORE INSERT OR UPDATE OF property_name, property_id ON public.property_hoa FOR EACH ROW EXECUTE FUNCTION rg_fill_property_id_from_name();
CREATE TRIGGER trg_rg_fill_property_id BEFORE INSERT OR UPDATE OF property_name, property_id ON public.hoa_history FOR EACH ROW EXECUTE FUNCTION rg_fill_property_id_from_name();
CREATE TRIGGER trg_rg_sync_company BEFORE INSERT OR UPDATE OF property_id, company_id ON public.property_mortgage_activity FOR EACH ROW EXECUTE FUNCTION rg_sync_company_from_property();
CREATE TRIGGER trg_rg_sync_company BEFORE INSERT OR UPDATE OF property_id, company_id ON public.property_finance_history FOR EACH ROW EXECUTE FUNCTION rg_sync_company_from_property();

-- row level security

alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.properties enable row level security;
alter table public.tenants enable row level security;
alter table public.leases enable row level security;
alter table public.rent_log enable row level security;
alter table public.expense_recurring_rules enable row level security;
alter table public.expenses enable row level security;
alter table public.maintenance_requests enable row level security;
alter table public.tenant_documents enable row level security;
alter table public.property_tax_history enable row level security;
alter table public.property_insurance_history enable row level security;
alter table public.tenant_messages enable row level security;
alter table public.reimbursement_requests enable row level security;
alter table public.applications enable row level security;
alter table public.application_messages enable row level security;
alter table public.property_hoa enable row level security;
alter table public.hoa_history enable row level security;
alter table public.receipts enable row level security;
alter table public.property_mortgage_activity enable row level security;
alter table public.property_finance_history enable row level security;
alter table public.incoming_rent_payments enable row level security;
alter table public.payment_settings enable row level security;
alter table public.tenant_payer_aliases enable row level security;

create policy companies_insert_authenticated on public.companies as permissive for insert to authenticated
  with check (true);
create policy companies_select_member on public.companies as permissive for select to authenticated
  using ((EXISTS ( SELECT 1
   FROM company_members cm
  WHERE ((cm.company_id = companies.id) AND (cm.user_id = auth.uid())))));
create policy companies_select_owner on public.companies as permissive for select to authenticated
  using ((owner_user_id = auth.uid()));
create policy company_members_delete_self on public.company_members as permissive for delete to authenticated
  using ((user_id = auth.uid()));
create policy company_members_insert_self on public.company_members as permissive for insert to authenticated
  with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM companies c
  WHERE ((c.id = company_members.company_id) AND (c.owner_user_id = auth.uid()))))));
create policy company_members_select_self on public.company_members as permissive for select to authenticated
  using ((user_id = auth.uid()));
create policy properties_no_delete on public.properties as permissive for delete to authenticated
  using (false);
create policy properties_owner_select on public.properties as permissive for select to authenticated
  using ((owner_id = auth.uid()));
create policy properties_owner_write on public.properties as permissive for all to authenticated
  using ((owner_id = auth.uid()))
  with check ((owner_id = auth.uid()));
create policy properties_rw_company_member on public.properties as permissive for all to authenticated
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy tenants_rw_company_member_via_leases on public.tenants as permissive for all to authenticated
  using ((EXISTS ( SELECT 1
   FROM leases l
  WHERE ((lower(l.tenant_email) = lower(tenants.email)) AND is_company_member(l.company_id)))))
  with check ((EXISTS ( SELECT 1
   FROM leases l
  WHERE ((lower(l.tenant_email) = lower(tenants.email)) AND is_company_member(l.company_id)))));
create policy tenants_select_self on public.tenants as permissive for select to authenticated
  using (((auth_user_id = auth.uid()) OR ((auth_user_id IS NULL) AND (lower(email) = lower(COALESCE(auth.email(), (auth.jwt() ->> 'email'::text)))))));
create policy tenants_update_self on public.tenants as permissive for update to public
  using ((auth_user_id = auth.uid()))
  with check ((auth_user_id = auth.uid()));
create policy leases_delete_own on public.leases as permissive for delete to authenticated
  using (((created_by = auth.uid()) AND rg_company_access(company_id)));
create policy leases_insert_own on public.leases as permissive for insert to authenticated
  with check (((created_by = auth.uid()) AND rg_company_access(company_id)));
create policy leases_rw_company_member on public.leases as permissive for all to authenticated
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy leases_select_own on public.leases as permissive for select to authenticated
  using ((created_by = auth.uid()));
create policy leases_select_tenant_self on public.leases as permissive for select to public
  using (((lower(tenant_email) = rg_auth_email()) OR (tenant_id = rg_tenant_id_for_auth_user())));
create policy leases_update_own on public.leases as permissive for update to authenticated
  using (((created_by = auth.uid()) AND rg_company_access(company_id)))
  with check (((created_by = auth.uid()) AND rg_company_access(company_id)));
create policy rent_log_owner_select on public.rent_log as permissive for select to authenticated
  using ((EXISTS ( SELECT 1
   FROM properties p
  WHERE ((p.id = rent_log.property_id) AND (p.owner_id = auth.uid())))));
create policy rent_log_owner_write on public.rent_log as permissive for all to authenticated
  using ((EXISTS ( SELECT 1
   FROM properties p
  WHERE ((p.id = rent_log.property_id) AND (p.owner_id = auth.uid())))))
  with check ((EXISTS ( SELECT 1
   FROM properties p
  WHERE ((p.id = rent_log.property_id) AND (p.owner_id = auth.uid())))));
create policy rent_log_rw_company_member on public.rent_log as permissive for all to authenticated
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy rent_log_select_tenant_self on public.rent_log as permissive for select to public
  using (((lower(tenant_email) = rg_auth_email()) OR (tenant_id = rg_tenant_id_for_auth_user())));
create policy expenses_no_hard_delete on public.expenses as restrictive for delete to authenticated
  using (false);
create policy expenses_owner_select on public.expenses as permissive for select to authenticated
  using ((EXISTS ( SELECT 1
   FROM properties p
  WHERE ((p.id = expenses.property_id) AND (p.owner_id = auth.uid())))));
create policy expenses_owner_write on public.expenses as permissive for all to authenticated
  using ((EXISTS ( SELECT 1
   FROM properties p
  WHERE ((p.id = expenses.property_id) AND (p.owner_id = auth.uid())))))
  with check ((EXISTS ( SELECT 1
   FROM properties p
  WHERE ((p.id = expenses.property_id) AND (p.owner_id = auth.uid())))));
create policy expenses_rw_company_member on public.expenses as permissive for all to authenticated
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy maintenance_requests_insert_tenant_self on public.maintenance_requests as permissive for insert to authenticated
  with check (((lower(tenant_email) = rg_auth_email()) AND rg_tenant_can_file(company_id, property_id, tenant_id)));
create policy maintenance_requests_rw_company_member on public.maintenance_requests as permissive for all to authenticated
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy maintenance_requests_select_tenant_self on public.maintenance_requests as permissive for select to public
  using (((lower(tenant_email) = rg_auth_email()) OR (tenant_id = rg_tenant_id_for_auth_user())));
create policy tenant_documents_rw_company_member on public.tenant_documents as permissive for all to authenticated
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy tenant_documents_select_tenant_self on public.tenant_documents as permissive for select to public
  using (((lower(tenant_email) = rg_auth_email()) OR (tenant_id = rg_tenant_id_for_auth_user())));
create policy property_tax_history_rg_property_access on public.property_tax_history as permissive for all to authenticated
  using (rg_can_access_property(property_id))
  with check (rg_can_access_property(property_id));
create policy property_insurance_history_rg_property_access on public.property_insurance_history as permissive for all to authenticated
  using (rg_can_access_property(property_id))
  with check (rg_can_access_property(property_id));
create policy tenant_messages_insert_tenant_self on public.tenant_messages as permissive for insert to authenticated
  with check (((lower(tenant_email) = rg_auth_email()) AND (sender = 'tenant'::text) AND rg_tenant_can_file(company_id, NULL::uuid, tenant_id)));
create policy tenant_messages_rw_company_member on public.tenant_messages as permissive for all to public
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy tenant_messages_select_tenant_self on public.tenant_messages as permissive for select to public
  using (((lower(tenant_email) = rg_auth_email()) OR (tenant_id = rg_tenant_id_for_auth_user())));
create policy reimbursement_requests_insert_tenant_self on public.reimbursement_requests as permissive for insert to authenticated
  with check ((lower(tenant_email) = rg_auth_email()));
create policy reimbursement_requests_rw_company_member on public.reimbursement_requests as permissive for all to authenticated
  using (is_company_member(company_id))
  with check (is_company_member(company_id));
create policy reimbursement_requests_select_tenant_self on public.reimbursement_requests as permissive for select to public
  using (((lower(tenant_email) = rg_auth_email()) OR (tenant_id = rg_tenant_id_for_auth_user())));
create policy "applicant view own applications" on public.applications as permissive for select to authenticated
  using ((applicant_user_id = auth.uid()));
create policy "landlords manage their applications" on public.applications as permissive for select to authenticated
  using ((property_id IN ( SELECT p.id
   FROM properties p
  WHERE (p.owner_id = auth.uid()))));
create policy "landlords update their applications" on public.applications as permissive for update to authenticated
  using ((property_id IN ( SELECT p.id
   FROM properties p
  WHERE (p.owner_id = auth.uid()))));
create policy "public can submit applications" on public.applications as permissive for insert to anon, authenticated
  with check (true);
create policy "applicant read messages" on public.application_messages as permissive for select to authenticated
  using ((application_id IN ( SELECT a.id
   FROM applications a
  WHERE (a.applicant_user_id = auth.uid()))));
create policy "applicant send messages" on public.application_messages as permissive for insert to authenticated
  with check (((sender_role = 'applicant'::text) AND (application_id IN ( SELECT a.id
   FROM applications a
  WHERE (a.applicant_user_id = auth.uid())))));
create policy "landlord read messages" on public.application_messages as permissive for select to authenticated
  using ((application_id IN ( SELECT a.id
   FROM (applications a
     JOIN properties p ON ((p.id = a.property_id)))
  WHERE (p.owner_id = auth.uid()))));
create policy "landlord send messages" on public.application_messages as permissive for insert to authenticated
  with check (((sender_role = 'landlord'::text) AND (application_id IN ( SELECT a.id
   FROM (applications a
     JOIN properties p ON ((p.id = a.property_id)))
  WHERE (p.owner_id = auth.uid())))));
create policy property_hoa_rg_property_access on public.property_hoa as permissive for all to authenticated
  using (rg_can_access_property(property_id))
  with check (rg_can_access_property(property_id));
create policy hoa_history_rg_property_access on public.hoa_history as permissive for all to authenticated
  using (rg_can_access_property(property_id))
  with check (rg_can_access_property(property_id));
create policy receipts_own_rows on public.receipts as permissive for all to authenticated
  using ((user_id = auth.uid()))
  with check ((user_id = auth.uid()));
create policy property_mortgage_activity_rg_property_access on public.property_mortgage_activity as permissive for all to authenticated
  using (rg_can_access_property(property_id))
  with check (rg_can_access_property(property_id));
create policy property_finance_history_rg_property_access on public.property_finance_history as permissive for all to authenticated
  using (rg_can_access_property(property_id))
  with check (rg_can_access_property(property_id));
create policy incoming_rent_payments_rg_access on public.incoming_rent_payments as permissive for all to authenticated
  using (((user_id = auth.uid()) OR rg_company_access(company_id)))
  with check (((user_id = auth.uid()) OR rg_company_access(company_id)));
create policy "company members manage their payment settings" on public.payment_settings as permissive for all to public
  using ((EXISTS ( SELECT 1
   FROM company_members cm
  WHERE ((cm.company_id = payment_settings.company_id) AND (cm.user_id = auth.uid())))))
  with check ((EXISTS ( SELECT 1
   FROM company_members cm
  WHERE ((cm.company_id = payment_settings.company_id) AND (cm.user_id = auth.uid())))));
create policy payment_settings_read_team_or_tenant on public.payment_settings as permissive for select to authenticated
  using ((rg_company_access(company_id) OR rg_is_tenant_of_company(company_id)));
create policy tenant_payer_aliases_rg_access on public.tenant_payer_aliases as permissive for all to authenticated
  using (rg_company_access(company_id))
  with check (rg_company_access(company_id));