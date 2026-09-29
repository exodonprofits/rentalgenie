# Rental Genie's own Supabase project

Project `xqmnaeujwumlcoyhgzuk` ("RentalGenie", us-east-1, Postgres 17). Rental Genie is moving here
from the shared GenieSphere project (`pbojacnagutipfhcxltj`, "Exodon Profits"). Until cutover the
pages still point at the shared project and `supabase/migrations/` stays its history.

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

Remaining steps: Vault secret, Edge Functions and secrets, auth settings (site URL, redirects, Google
provider) and SMTP, page URL/key swap, n8n credentials, cutover. Anything entered in the old project
after 2026-09-28 must be re-copied before cutover.
