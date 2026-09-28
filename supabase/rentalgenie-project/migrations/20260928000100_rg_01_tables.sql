-- sequences

create sequence if not exists public.expenses_id_seq;
create sequence if not exists public.maintenance_requests_id_seq;
create sequence if not exists public.tenant_documents_id_seq;
create sequence if not exists public.tenant_messages_id_seq;

-- tables

create table public.companies (
  id uuid default gen_random_uuid() not null,
  name text not null,
  created_at timestamp with time zone default now(),
  owner_user_id uuid,
  archived_at timestamp with time zone,
  archived_by uuid,
  payment_inbox_token text default lower(substr(replace((gen_random_uuid())::text, '-'::text, ''::text), 1, 10)),
  payment_inbox_verify_url text,
  payment_inbox_verify_at timestamp with time zone
);

create table public.company_members (
  company_id uuid not null,
  user_id uuid not null,
  role text default 'owner'::text not null,
  created_at timestamp with time zone default now() not null
);

create table public.properties (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  name text not null,
  occupancy_status text default 'vacant'::text,
  address text,
  created_at timestamp with time zone default CURRENT_TIMESTAMP,
  notes text,
  purchase_date date,
  purchase_price numeric,
  is_financed boolean default false,
  monthly_payment numeric,
  lender_name text,
  loan_term text,
  financing_notes text,
  lender_portal_url text,
  loan_balance numeric,
  interest_rate text,
  loan_start_date date,
  loan_end_date date,
  company_id uuid not null,
  owner_id uuid not null,
  current_tenant text,
  current_rent numeric,
  property_type text,
  units integer default 1,
  year_built integer,
  square_feet integer,
  bedrooms numeric(4,1),
  bathrooms numeric(4,1),
  ownership_type text default 'personal'::text,
  down_payment numeric(12,2),
  closing_costs numeric(12,2),
  rehab_cost numeric(12,2),
  mortgage_pi numeric(12,2),
  tax_monthly numeric(12,2),
  insurance_monthly numeric(12,2),
  hoa_monthly numeric(12,2),
  pmi_monthly numeric(12,2),
  util_water text default 'tenant'::text,
  util_gas text default 'tenant'::text,
  util_electric text default 'tenant'::text,
  util_trash text default 'tenant'::text,
  util_lawn text default 'tenant'::text,
  util_internet text default 'tenant'::text,
  archived_at timestamp with time zone,
  archived_by uuid,
  property_tax_annual numeric,
  property_tax_due_month text,
  property_tax_account_number text,
  property_tax_portal_url text,
  property_tax_notes text,
  tax_monthly_current numeric,
  tax_annual_current numeric,
  tax_year_current integer,
  tax_due_date_current date,
  tax_portal_url_current text,
  tax_account_number_current text,
  mortgage_principal_balance numeric,
  mortgage_escrow_balance numeric,
  mortgage_last_applied_date date,
  insurance_provider_current text,
  insurance_policy_number_current text,
  insurance_monthly_current numeric,
  insurance_annual_current numeric,
  insurance_renewal_date_current date,
  insurance_portal_url_current text,
  use_type text default 'rental'::text,
  status text default 'vacant'::text,
  pm_managed boolean default false,
  pm_company_name text,
  pm_manager_name text,
  pm_phone text,
  pm_email text,
  pm_fee_amount numeric,
  pm_fee_type text default 'percent'::text,
  pm_contract_start date,
  pm_contract_end date,
  pm_notes text,
  is_public_listing boolean default false not null,
  listing_rent numeric,
  listing_deposit numeric,
  listing_available_date date,
  listing_description text,
  listing_photos jsonb default '[]'::jsonb not null,
  listing_pet_policy text,
  listing_contact_email text,
  listing_contact_phone text,
  listing_published_at timestamp with time zone
);

create table public.tenants (
  id uuid default gen_random_uuid() not null,
  auth_user_id uuid,
  tenant_name text,
  email text,
  property_name text,
  phone text,
  created_at timestamp with time zone default now()
);

create table public.leases (
  id uuid default gen_random_uuid() not null,
  property_name text not null,
  tenant_name text,
  lease_start date,
  lease_end date,
  rent_amount numeric,
  notes text,
  inserted_at timestamp with time zone default now(),
  tenant_email text,
  terms text,
  status text default 'draft'::text,
  sent_at timestamp without time zone,
  signed_at timestamp without time zone,
  sent_by text,
  signed_by text,
  rent_due_day integer,
  late_fee_amount numeric,
  late_fee_grace_days integer,
  due_day integer,
  late_fee numeric,
  grace_period integer,
  tenant_phone text,
  company_id uuid not null,
  management_type text default 'self'::text,
  management_company_name text,
  management_company_email text,
  management_company_phone text,
  management_fee_type text,
  management_fee_value numeric(12,2),
  management_fee_cap numeric(12,2),
  management_fee_notes text,
  rent_collection_method text,
  rent_collection_notes text,
  management_fee_effective_start date,
  management_fee_effective_end date,
  property_id uuid not null,
  owner_id uuid not null,
  archived_at timestamp with time zone,
  archived_by uuid,
  created_by uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  lease_type text default 'fixed_term'::text,
  terminated_date date,
  termination_note text,
  tenant_id uuid,
  pay_accepts_ach boolean default false,
  pay_accepts_venmo boolean default false,
  pay_accepts_zelle boolean default false,
  pay_accepts_check boolean default false,
  pay_accepts_cash boolean default false,
  pay_accepts_bank_transfer boolean default false,
  pay_venmo_handle text,
  pay_zelle_recipient text,
  pay_ach_bank_name text,
  pay_ach_account_holder text,
  pay_ach_routing_number text,
  pay_ach_account_number text,
  pay_ach_account_type text,
  pay_check_payable_to text,
  pay_check_mailing_address text,
  pay_other_notes text,
  pay_instructions_updated_at timestamp with time zone,
  tenant_preferred_payment_method text,
  tenant_preferred_payment_method_updated_at timestamp with time zone,
  security_deposit numeric,
  pet_deposit numeric
);

create table public.rent_log (
  id uuid default gen_random_uuid() not null,
  property_name text not null,
  tenant_name text,
  date_paid date,
  amount numeric,
  method text,
  note text,
  inserted_at timestamp without time zone default now(),
  company_id uuid not null,
  rent_period date,
  lease_id uuid,
  due_date date,
  applied_to_due_date date,
  tenant_email text,
  property_id uuid not null,
  owner_id uuid not null,
  archived_at timestamp with time zone,
  archived_by uuid,
  tenant_id uuid,
  source text,
  incoming_payment_id uuid
);

create table public.expense_recurring_rules (
  id uuid default gen_random_uuid() not null,
  property_name text not null,
  preset_name text not null,
  category text not null,
  amount numeric(12,2) not null,
  vendor text,
  note text,
  frequency text default 'monthly'::text not null,
  day_of_month integer,
  next_due_date date not null,
  auto_post boolean default true not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.expenses (
  id integer default nextval('expenses_id_seq'::regclass) not null,
  property_name text not null,
  date_paid date not null,
  category text not null,
  amount numeric(10,2) not null,
  note text,
  vendor text,
  company_id uuid not null,
  receipt_url text,
  is_planned boolean default false,
  source text default 'manual'::text,
  recurring_rule_id uuid,
  details text,
  property_id uuid not null,
  owner_id uuid not null,
  archived_at timestamp with time zone,
  archived_by uuid,
  receipt_path text
);

create table public.maintenance_requests (
  id integer default nextval('maintenance_requests_id_seq'::regclass) not null,
  property_name text not null,
  tenant_email text,
  issue_description text not null,
  urgency_level text not null,
  status text default 'Open'::text not null,
  notes text,
  created_at timestamp with time zone default now(),
  company_id uuid not null,
  assigned_vendor text,
  estimated_cost numeric,
  scheduled_at timestamp with time zone,
  completed_at timestamp with time zone,
  user_id uuid,
  property_id uuid,
  owner_id uuid,
  archived_at timestamp with time zone,
  archived_by uuid,
  tenant_id uuid,
  photo_urls jsonb default '[]'::jsonb,
  photo_paths jsonb
);

create table public.tenant_documents (
  id bigint default nextval('tenant_documents_id_seq'::regclass) not null,
  company_id uuid,
  property_name text not null,
  tenant_email text not null,
  title text not null,
  file_url text not null,
  note text,
  uploaded_at timestamp with time zone default now() not null,
  tenant_id uuid,
  doc_type text,
  uploaded_by uuid,
  file_path text,
  property_id uuid
);

create table public.property_tax_history (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  property_id uuid not null,
  tax_year integer not null,
  effective_date date not null,
  tax_annual numeric not null,
  tax_monthly numeric,
  due_date date,
  account_number text,
  portal_url text,
  notes text,
  created_at timestamp with time zone default now() not null,
  created_by uuid
);

create table public.property_insurance_history (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  property_id uuid not null,
  policy_year integer not null,
  effective_date date not null,
  provider text not null,
  policy_number text not null,
  start_date date,
  end_date date,
  renewal_date date,
  premium_annual numeric not null,
  premium_monthly numeric,
  deductible numeric,
  coverage text,
  portal_url text,
  notes text,
  created_at timestamp with time zone default now() not null,
  created_by uuid
);

create table public.tenant_messages (
  id bigint default nextval('tenant_messages_id_seq'::regclass) not null,
  company_id uuid,
  property_name text not null,
  tenant_email text not null,
  subject text not null,
  message text not null,
  created_at timestamp with time zone default now() not null,
  status text default 'open'::text not null,
  tenant_id uuid,
  sender text default 'tenant'::text not null,
  read_at timestamp with time zone,
  property_id uuid
);

create table public.reimbursement_requests (
  id bigint generated by default as identity not null,
  company_id uuid not null,
  property_id uuid,
  property_name text not null,
  tenant_id uuid,
  tenant_email text not null,
  maintenance_request_id integer,
  amount numeric not null,
  description text,
  receipt_url text not null,
  status text default 'Pending'::text not null,
  landlord_note text,
  requested_at timestamp with time zone default now() not null,
  reviewed_at timestamp with time zone,
  reviewed_by uuid,
  expense_id integer,
  receipt_path text
);

create table public.applications (
  id uuid default gen_random_uuid() not null,
  property_id uuid not null,
  applicant_name text not null,
  applicant_email text not null,
  applicant_phone text,
  desired_move_in date,
  household_size integer,
  message text,
  status text default 'submitted'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  current_address text,
  employer_name text,
  employment_status text,
  monthly_income numeric,
  occupants_count integer,
  has_pets boolean default false,
  pet_details text,
  emergency_contact_name text,
  emergency_contact_phone text,
  screening_consent boolean default false,
  screening_status text default 'not_requested'::text not null,
  screening_report_url text,
  screening_requested_at timestamp with time zone,
  applicant_user_id uuid,
  property_name text,
  property_address text,
  tenant_id uuid
);

create table public.application_messages (
  id uuid default gen_random_uuid() not null,
  application_id uuid not null,
  sender_role text not null,
  message text not null,
  created_at timestamp with time zone default now() not null,
  read_at timestamp with time zone
);

create table public.property_hoa (
  id uuid default uuid_generate_v4() not null,
  property_name text not null,
  hoa_name text,
  contact_name text,
  contact_phone text,
  contact_email text,
  website text,
  fee_amount numeric,
  due_day integer,
  notes text,
  created_at timestamp without time zone default now(),
  property_id uuid
);

create table public.hoa_history (
  id uuid default uuid_generate_v4() not null,
  property_name text not null,
  action text,
  hoa_name text,
  fee_amount numeric,
  updated_by text,
  notes text,
  created_at timestamp without time zone default now(),
  property_id uuid
);

create table public.receipts (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  store text,
  purchase_date date,
  amount numeric,
  notes text,
  created_at timestamp with time zone default now()
);

create table public.property_mortgage_activity (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  property_id uuid not null,
  applied_date date not null,
  effective_date date,
  payment_amount numeric not null,
  principal_amount numeric,
  interest_amount numeric,
  escrow_amount numeric,
  optional_amount numeric,
  late_fee_amount numeric,
  principal_balance numeric,
  escrow_balance numeric,
  unapplied_balance numeric,
  confirmation_number text,
  notes text,
  created_at timestamp with time zone default now() not null,
  created_by uuid
);

create table public.property_finance_history (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  property_id uuid not null,
  event_type text not null,
  effective_date date not null,
  lender_name text not null,
  lender_portal_url text,
  loan_number text,
  loan_term_years integer,
  interest_rate text,
  start_date date,
  starting_balance numeric,
  monthly_payment numeric,
  notes text,
  created_at timestamp with time zone default now() not null,
  created_by uuid
);

create table public.incoming_rent_payments (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  company_id uuid,
  property_name text,
  tenant_name text,
  tenant_email text,
  tenant_phone text,
  method text,
  amount numeric,
  date_paid date,
  memo text,
  source text,
  source_message_id text,
  raw_subject text,
  raw_body text,
  status text default 'pending'::text,
  created_at timestamp with time zone default now(),
  property_id uuid,
  lease_id uuid,
  suggested_due_date date,
  match_confidence numeric,
  match_reason text,
  transaction_ref text,
  sender_verified boolean default false,
  rent_log_ids uuid[],
  reviewed_at timestamp with time zone,
  reviewed_by uuid
);

create table public.payment_settings (
  id uuid default gen_random_uuid() not null,
  owner_id uuid,
  company_id uuid,
  venmo_handle text,
  venmo_note text,
  zelle_email text,
  zelle_phone text,
  updated_at timestamp with time zone default now() not null
);

create table public.tenant_payer_aliases (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  property_id uuid not null,
  tenant_name text,
  payer_name_norm text not null,
  created_at timestamp with time zone default now() not null,
  created_by uuid default auth.uid()
);

alter sequence public.expenses_id_seq owned by public.expenses.id;
alter sequence public.maintenance_requests_id_seq owned by public.maintenance_requests.id;
alter sequence public.tenant_documents_id_seq owned by public.tenant_documents.id;
alter sequence public.tenant_messages_id_seq owned by public.tenant_messages.id;

-- constraints

alter table public.companies add constraint companies_pkey PRIMARY KEY (id);
alter table public.company_members add constraint company_members_company_user_unique UNIQUE (company_id, user_id);
alter table public.company_members add constraint company_members_pkey PRIMARY KEY (company_id, user_id);
alter table public.properties add constraint properties_pkey PRIMARY KEY (id);
alter table public.properties add constraint properties_occupancy_status_check CHECK ((occupancy_status = ANY (ARRAY['vacant'::text, 'tenant_occupied'::text, 'owner_occupied'::text, 'renovation'::text, 'off_market'::text])));
alter table public.properties add constraint properties_ownership_type_check CHECK ((ownership_type = ANY (ARRAY['personal'::text, 'llc'::text, 'trust'::text])));
alter table public.properties add constraint properties_property_type_check CHECK (((property_type IS NULL) OR (property_type = ANY (ARRAY['single_family'::text, 'condo'::text, 'townhome'::text, 'duplex'::text, 'multi_family'::text, 'commercial'::text]))));
alter table public.properties add constraint properties_status_chk CHECK ((status = ANY (ARRAY['vacant'::text, 'occupied'::text]))) NOT VALID;
alter table public.properties add constraint properties_units_min_check CHECK (((units IS NULL) OR (units >= 1)));
alter table public.properties add constraint properties_use_type_check CHECK ((use_type = ANY (ARRAY['rental'::text, 'primary'::text, 'vacation'::text, 'mixed'::text])));
alter table public.properties add constraint properties_util_electric_check CHECK ((util_electric = ANY (ARRAY['tenant'::text, 'landlord'::text])));
alter table public.properties add constraint properties_util_gas_check CHECK ((util_gas = ANY (ARRAY['tenant'::text, 'landlord'::text])));
alter table public.properties add constraint properties_util_internet_check CHECK ((util_internet = ANY (ARRAY['tenant'::text, 'landlord'::text])));
alter table public.properties add constraint properties_util_lawn_check CHECK ((util_lawn = ANY (ARRAY['tenant'::text, 'landlord'::text])));
alter table public.properties add constraint properties_util_trash_check CHECK ((util_trash = ANY (ARRAY['tenant'::text, 'landlord'::text])));
alter table public.properties add constraint properties_util_water_check CHECK ((util_water = ANY (ARRAY['tenant'::text, 'landlord'::text])));
alter table public.tenants add constraint tenants_pkey PRIMARY KEY (id);
alter table public.leases add constraint leases_pkey PRIMARY KEY (id);
alter table public.leases add constraint leases_management_fee_type_check CHECK ((management_fee_type = ANY (ARRAY['percent'::text, 'flat'::text])));
alter table public.leases add constraint leases_management_type_check CHECK ((management_type = ANY (ARRAY['self'::text, 'pm'::text])));
alter table public.leases add constraint leases_rent_collection_method_check CHECK ((rent_collection_method = ANY (ARRAY['landlord'::text, 'property_manager'::text, 'other'::text])));
alter table public.rent_log add constraint rent_log_pkey PRIMARY KEY (id);
alter table public.expense_recurring_rules add constraint expense_recurring_rules_pkey PRIMARY KEY (id);
alter table public.expense_recurring_rules add constraint expense_recurring_rules_frequency_check CHECK ((frequency = ANY (ARRAY['monthly'::text, 'quarterly'::text, 'yearly'::text])));
alter table public.expenses add constraint expenses_pkey PRIMARY KEY (id);
alter table public.maintenance_requests add constraint maintenance_requests_pkey PRIMARY KEY (id);
alter table public.maintenance_requests add constraint maintenance_requests_status_check CHECK ((status = ANY (ARRAY['Open'::text, 'In Progress'::text, 'Resolved'::text])));
alter table public.maintenance_requests add constraint maintenance_requests_urgency_level_check CHECK ((urgency_level = ANY (ARRAY['Low'::text, 'Normal'::text, 'High'::text, 'Emergency'::text])));
alter table public.tenant_documents add constraint tenant_documents_pkey PRIMARY KEY (id);
alter table public.property_tax_history add constraint property_tax_history_pkey PRIMARY KEY (id);
alter table public.property_insurance_history add constraint property_insurance_history_pkey PRIMARY KEY (id);
alter table public.tenant_messages add constraint tenant_messages_pkey PRIMARY KEY (id);
alter table public.tenant_messages add constraint tenant_messages_sender_check CHECK ((sender = ANY (ARRAY['tenant'::text, 'landlord'::text])));
alter table public.reimbursement_requests add constraint reimbursement_requests_pkey PRIMARY KEY (id);
alter table public.reimbursement_requests add constraint reimbursement_requests_amount_check CHECK ((amount > (0)::numeric));
alter table public.reimbursement_requests add constraint reimbursement_requests_status_check CHECK ((status = ANY (ARRAY['Pending'::text, 'Approved'::text, 'Denied'::text])));
alter table public.applications add constraint applications_pkey PRIMARY KEY (id);
alter table public.applications add constraint applications_screening_status_check CHECK ((screening_status = ANY (ARRAY['not_requested'::text, 'requested'::text, 'completed'::text, 'failed'::text])));
alter table public.applications add constraint applications_status_check CHECK ((status = ANY (ARRAY['submitted'::text, 'reviewed'::text, 'approved'::text, 'denied'::text])));
alter table public.application_messages add constraint application_messages_pkey PRIMARY KEY (id);
alter table public.application_messages add constraint application_messages_sender_role_check CHECK ((sender_role = ANY (ARRAY['landlord'::text, 'applicant'::text])));
alter table public.property_hoa add constraint property_hoa_pkey PRIMARY KEY (id);
alter table public.hoa_history add constraint hoa_history_pkey PRIMARY KEY (id);
alter table public.receipts add constraint receipts_pkey PRIMARY KEY (id);
alter table public.property_mortgage_activity add constraint property_mortgage_activity_pkey PRIMARY KEY (id);
alter table public.property_finance_history add constraint property_finance_history_pkey PRIMARY KEY (id);
alter table public.property_finance_history add constraint property_finance_history_event_type_check CHECK ((event_type = ANY (ARRAY['origination'::text, 'refinance'::text, 'servicer_transfer'::text, 'rate_modification'::text])));
alter table public.incoming_rent_payments add constraint incoming_rent_payments_pkey PRIMARY KEY (id);
alter table public.incoming_rent_payments add constraint incoming_rent_payments_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'matched'::text, 'confirmed'::text, 'ignored'::text, 'dismissed'::text, 'error'::text])));
alter table public.payment_settings add constraint payment_settings_company_id_key UNIQUE (company_id);
alter table public.payment_settings add constraint payment_settings_pkey PRIMARY KEY (id);
alter table public.tenant_payer_aliases add constraint tenant_payer_aliases_company_id_payer_name_norm_key UNIQUE (company_id, payer_name_norm);
alter table public.tenant_payer_aliases add constraint tenant_payer_aliases_pkey PRIMARY KEY (id);

-- indexes

CREATE UNIQUE INDEX companies_payment_inbox_token_key ON public.companies USING btree (payment_inbox_token);
CREATE INDEX idx_properties_company_active ON public.properties USING btree (company_id) WHERE (archived_at IS NULL);
CREATE INDEX idx_properties_owner_id ON public.properties USING btree (owner_id);
CREATE INDEX idx_properties_public_listing ON public.properties USING btree (is_public_listing, occupancy_status);
CREATE INDEX properties_company_idx ON public.properties USING btree (company_id);
CREATE UNIQUE INDEX properties_owner_name_ux ON public.properties USING btree (owner_id, name);
CREATE UNIQUE INDEX ux_properties_owner_name ON public.properties USING btree (owner_id, name);
CREATE UNIQUE INDEX idx_tenants_auth_user_id ON public.tenants USING btree (auth_user_id) WHERE (auth_user_id IS NOT NULL);
CREATE INDEX idx_leases_company_active ON public.leases USING btree (company_id) WHERE (archived_at IS NULL);
CREATE INDEX idx_leases_owner_id ON public.leases USING btree (owner_id);
CREATE INDEX idx_leases_property_id ON public.leases USING btree (property_id);
CREATE INDEX idx_leases_tenant_id ON public.leases USING btree (tenant_id);
CREATE INDEX idx_rent_log_company_active ON public.rent_log USING btree (company_id) WHERE (archived_at IS NULL);
CREATE INDEX idx_rent_log_lease_id ON public.rent_log USING btree (lease_id);
CREATE INDEX idx_rent_log_owner_id ON public.rent_log USING btree (owner_id);
CREATE INDEX idx_rent_log_property_id ON public.rent_log USING btree (property_id);
CREATE INDEX idx_rent_log_tenant_id ON public.rent_log USING btree (tenant_id);
CREATE INDEX rent_log_company_date_idx ON public.rent_log USING btree (company_id, date_paid);
CREATE INDEX rent_log_lease_period_idx ON public.rent_log USING btree (lease_id, rent_period);
CREATE INDEX rent_log_property_date_idx ON public.rent_log USING btree (property_name, date_paid);
CREATE INDEX rent_log_property_due_idx ON public.rent_log USING btree (property_name, applied_to_due_date);
CREATE INDEX rent_log_property_paid_idx ON public.rent_log USING btree (property_id, date_paid);
CREATE INDEX rent_log_property_period_idx ON public.rent_log USING btree (property_name, rent_period);
CREATE INDEX rent_log_tenant_email_idx ON public.rent_log USING btree (lower(tenant_email));
CREATE INDEX expenses_company_date_idx ON public.expenses USING btree (company_id, date_paid);
CREATE INDEX expenses_property_paid_idx ON public.expenses USING btree (property_id, date_paid);
CREATE INDEX expenses_vendor_idx ON public.expenses USING btree (vendor);
CREATE INDEX idx_expenses_company_active ON public.expenses USING btree (company_id) WHERE (archived_at IS NULL);
CREATE INDEX idx_expenses_owner_id ON public.expenses USING btree (owner_id);
CREATE INDEX idx_expenses_property_id ON public.expenses USING btree (property_id);
CREATE INDEX idx_expenses_recurring_rule_date ON public.expenses USING btree (recurring_rule_id, date_paid);
CREATE INDEX idx_maintenance_requests_property_id ON public.maintenance_requests USING btree (property_id);
CREATE INDEX idx_maintenance_requests_tenant_id ON public.maintenance_requests USING btree (tenant_id);
CREATE INDEX idx_mr_company_active ON public.maintenance_requests USING btree (company_id) WHERE (archived_at IS NULL);
CREATE INDEX idx_mr_company_id ON public.maintenance_requests USING btree (company_id);
CREATE INDEX idx_mr_created_at ON public.maintenance_requests USING btree (created_at);
CREATE INDEX idx_mr_property_id ON public.maintenance_requests USING btree (property_id);
CREATE INDEX idx_mr_tenant_email ON public.maintenance_requests USING btree (tenant_email);
CREATE INDEX maintenance_requests_property_created_idx ON public.maintenance_requests USING btree (property_name, created_at DESC);
CREATE INDEX maintenance_requests_status_created_idx ON public.maintenance_requests USING btree (status, created_at DESC);
CREATE INDEX maintenance_requests_user_id_idx ON public.maintenance_requests USING btree (user_id);
CREATE INDEX tenant_docs_tenant_email_idx ON public.tenant_documents USING btree (lower(tenant_email));
CREATE INDEX idx_property_tax_history_property_id ON public.property_tax_history USING btree (property_id);
CREATE INDEX idx_property_tax_history_year ON public.property_tax_history USING btree (property_id, tax_year DESC);
CREATE INDEX idx_property_insurance_history_policy_year ON public.property_insurance_history USING btree (property_id, policy_year DESC);
CREATE INDEX idx_property_insurance_history_property_id ON public.property_insurance_history USING btree (property_id);
CREATE INDEX tenant_messages_tenant_email_idx ON public.tenant_messages USING btree (lower(tenant_email));
CREATE INDEX idx_reimbursement_requests_company ON public.reimbursement_requests USING btree (company_id);
CREATE INDEX idx_reimbursement_requests_maintenance ON public.reimbursement_requests USING btree (maintenance_request_id);
CREATE INDEX idx_reimbursement_requests_status ON public.reimbursement_requests USING btree (status);
CREATE INDEX idx_applications_applicant_email ON public.applications USING btree (lower(applicant_email));
CREATE INDEX idx_applications_applicant_user ON public.applications USING btree (applicant_user_id);
CREATE INDEX idx_applications_property ON public.applications USING btree (property_id);
CREATE INDEX idx_applications_property_id ON public.applications USING btree (property_id);
CREATE INDEX idx_applications_tenant_id ON public.applications USING btree (tenant_id);
CREATE INDEX idx_app_messages_application ON public.application_messages USING btree (application_id);
CREATE INDEX idx_property_hoa_property_id ON public.property_hoa USING btree (property_id);
CREATE UNIQUE INDEX uq_property_hoa_property_id ON public.property_hoa USING btree (property_id) WHERE (property_id IS NOT NULL);
CREATE INDEX idx_hoa_history_property_id_created_at ON public.hoa_history USING btree (property_id, created_at DESC);
CREATE INDEX idx_property_mortgage_activity_applied_date ON public.property_mortgage_activity USING btree (property_id, applied_date DESC);
CREATE INDEX idx_property_mortgage_activity_property_id ON public.property_mortgage_activity USING btree (property_id);
CREATE INDEX idx_property_finance_history_effective_date ON public.property_finance_history USING btree (property_id, effective_date DESC);
CREATE INDEX idx_property_finance_history_property_id ON public.property_finance_history USING btree (property_id);
CREATE UNIQUE INDEX incoming_rent_payments_company_msg_key ON public.incoming_rent_payments USING btree (company_id, source_message_id);
CREATE INDEX incoming_rent_payments_pending_idx ON public.incoming_rent_payments USING btree (company_id, status, created_at DESC);
CREATE INDEX idx_payment_settings_owner_id ON public.payment_settings USING btree (owner_id);