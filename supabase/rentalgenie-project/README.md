# Rental Genie's own Supabase project

Project `xqmnaeujwumlcoyhgzuk` ("RentalGenie", us-east-1, Postgres 17). Rental Genie moved here from
the shared GenieSphere project (`pbojacnagutipfhcxltj`, "Exodon Profits"); the live site has used it
since the cutover on 2026-10-01. `supabase/migrations/` is the shared project's history and stays
there; new Rental Genie database changes go in `migrations/` here.

`migrations/` is this project's baseline, generated from the live shared project on 2026-09-28 and
applied in order:

- `rg_01_tables` — 24 tables, sequences, constraints, indexes. Checksum-identical to the source.
- `rg_02_functions` — 41 functions. Identical to the source except two deliberate changes:
  `rg_cascade_property_rename` no longer touches the dead `escrow_transactions` table, and
  `trigger_maintenance_acknowledgment` calls this project's Edge Function URL.
- `rg_03_constraints_views_policies` — foreign keys, views, triggers, RLS and policies. Identical to
  the source (Postgres 17 prints view definitions without table prefixes; the views are the same).
- `rg_04_grants_storage` — the same grants as the source, the three private buckets and their
  storage policies.
- `rg_05_hardening` — pg_net moved to `extensions`, search_path pinned on ten functions.
- `rg_06_maintenance_webhook_secret` — the Vault secret the maintenance trigger and Edge Function share.

Changes since the baseline, each applied to the project and tested in a rolled-back transaction:

- `rg_07_tenant_preferred_payment` — `tenant_set_preferred_payment_method` accepts tenants linked by
  `tenant_id`, skips archived leases, stores only known methods.
- `rg_08_listing_application_mode` — per-listing application mode (`rental_genie` / `external` /
  `contact`); applications only for public listings in `rental_genie` mode and only as plain
  submissions; anon INSERT on the applicant columns (the public form had no insert grant at all).

Moved: companies (the Rental Genie company only), company_members, properties, tenants, leases,
rent_log, expenses, expense_recurring_rules, maintenance_requests, tenant_documents, tenant_messages,
reimbursement_requests, applications, application_messages, property_hoa, hoa_history, receipts,
property_tax_history, property_insurance_history, property_mortgage_activity,
property_finance_history, incoming_rent_payments, payment_settings, tenant_payer_aliases.

Left in the shared project (unused by any page or function): escrow_transactions,
property_escrow_ledger, owners, pmc_staff, rental_tasks, lease_status_log, tenant_invites,
tenant_portal_users, property_financing_history, lease_rent_adjustments, property_inbox_map,
property_insurance.

Data copied 2026-09-28 (not kept in this repo): the 7 accounts that Rental Genie rows reference, with
their original IDs, password hashes and identities (pending confirmation/recovery tokens blanked);
the one Rental Genie company and its member; every Rental Genie row. Triggers were off during the
load, so nothing fired and stored statuses are unchanged; sequences match the source. Every table's
checksum and `rg_rent_status` match the source exactly.

Edge Functions deployed 2026-09-29 from `supabase/functions/` (unchanged source):
`maintenance-acknowledgment` (verify_jwt off, checks the Vault secret `rg_maintenance_webhook_secret`,
created by `rg_06`), `rental-genie-ai-proxy` and `rg-snap` (verify_jwt on). Tested: wrong webhook secret
401, right secret 200, both AI functions 401 without a login.

Edge Function secrets (dashboard → Edge Functions → Secrets):

- `ANTHROPIC_API_KEY` — both AI functions. Must be created inside a Claude Console workspace; an
  organization-level key is refused with a 400 asking for `anthropic-workspace-id` (the functions
  return 502). Set 2026-10-04; AI listing descriptions confirmed working that day.
- `RESEND_API_KEY`, `FROM_EMAIL` — maintenance acknowledgment emails. Without them tenants still get
  the in-app message, but no email.

Cutover status (2026-10-04): done. Every page that uses Supabase and `shared/config.json` point here (landlord
sign-in confirmed 2026-10-01), as does the workflow file `json/rental-genie-payment-inbox.n8n.json`.
The old Rental Genie tables in the shared project are read-only
(`supabase/migrations/20261002000000_lock_old_rental_genie_tables.sql`) and can be dropped from
mid-October 2026.

Not verified from the repo: that the copy of the payment-inbox workflow running in n8n Cloud uses this
project's URL and service key, and that the auth settings (site URL, redirect URLs, Google provider,
SMTP) match the old project's. Check those in n8n and in the dashboard before relying on them.
