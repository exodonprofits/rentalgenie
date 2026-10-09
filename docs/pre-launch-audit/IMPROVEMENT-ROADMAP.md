# Improvement roadmap

Pre-launch inspection, 2026-10-09. Ordered by priority. Effort is a rough size for this codebase (static pages plus SQL), not a time promise:
- **S:** one page or function, less than half a day.
- **M:** a few pages, or a migration with tests, one to two days.
- **L:** a cross-cutting change, several days.

Each item lists what it depends on. "Approval" means a product decision or a data/database change that needs your sign-off per the safe-implementation rules.

## Phase 0: launch blockers (P0)

| # | Item | Findings | Effort | Risk | Depends on | Impact |
|---|---|---|---|---|---|---|
| 0.1 | Fix property creation: send `owner_id` and resolve `company_id` in add-property, or add a `before insert` trigger filling `owner_id = auth.uid()` | F-01 | S | Low (rolled-back DB test, then a real add) | Approval if using the trigger (DB change) | Unblocks every new landlord |
| 0.2 | One shared same-origin redirect check, applied to login `returnTo`, tenant-login `redirect`, and the `return_to` / `return` params on property-tax, property-insurance and add-expense | F-02, F-04 | S | Low | — | Closes the script-injection and open-redirect holes |
| 0.3 | Escape quotes in maintenance-history `esc()` (or rebuild the rows with createElement) | F-03 | S | Low | — | Closes tenant→landlord stored XSS |
| 0.4 | Tenant link on payments: writers set `tenant_id` / `tenant_email` from the lease (or a trigger from `lease_id`), tenant pages read by either, backfill the 26 rows | F-05 | M | Medium (data backfill) | Approval for the trigger and backfill | Tenants see their real payment history |

## Phase 1: must fix before public launch (P1)

| # | Item | Findings | Effort | Risk | Depends on | Impact |
|---|---|---|---|---|---|---|
| 1.1 | Legal pages: fill in entity, state, county and address; cover applicants; fix the hosting provider; remove unbuilt features | F-22 | S (writing) | Legal review advised | **You** (business details) | Required to operate publicly |
| 1.2 | Support address: confirm you own `rentalgenie.app`, or switch all 11 to `support@rentalgenieai.com` | F-21 | S | Low | You (which mailbox) | Support mail actually arrives |
| 1.3 | Verify "Confirm email" is on in Supabase Auth; restrict `claim_my_applications` to confirmed emails | F-20 | S | Low | You (dashboard check) | Applicant data privacy |
| 1.4 | Move the Supabase client to `<body>` on 5 pages | F-18 | S | Low | — | Reliable sessions on sign-up / reset / tenant login |
| 1.5 | Tenant mobile nav (chip) fix on 6 pages | F-24 | S | Low | — | Tenants can navigate on phones |
| 1.6 | Maintenance vocabulary (Low/Normal/High/Emergency) everywhere; fix archive | F-10, F-11 | S–M | Low | — | Landlords can log and edit requests |
| 1.7 | HOA pages: drop `unit_type`, resolve by `property_id` | F-07 | S | Low | — | HOA editing works |
| 1.8 | Lease form: pass `lease_id` on edit; property picker or route via LRC; write `terminated_date` | F-08, F-09, F-17 | M | Medium | — | No duplicate leases; terminations stop rent |
| 1.9 | Rent engine edge cases: exclude draft leases; respect terminated status | F-17 | M | Medium (rent math) | Approval (DB function change) + rolled-back tests | Correct balances |
| 1.10 | Remove in-browser rent math in LRC, dashboard fallback, add-payment and the tenant pages; read rg_rent_schedule / rg_rent_status (with a tenant-scoped wrapper) | F-12 | L | Medium | 1.9 | One source of truth for money |
| 1.11 | Reports: fix rent-report columns, Net YTD and cap rate, archived filtering, local-date parsing | F-13, F-14, F-15 | M | Low | 1.10 helps | Trustworthy numbers |
| 1.12 | Escape remaining DB text in innerHTML (add-expense, reports, dashboard, LRC, picker) | F-06 | M | Low | — | Closes remaining XSS |
| 1.13 | Onboarding: create the workspace at sign-up (or offer it on the dashboard); fix the checklist links | F-25, F-09 | M | Low | 0.1 | New landlords reach a working state alone |
| 1.14 | Honest UI: implement or remove Export/Delete account; fix the tenant phone "saved"; remove "Pay rent" and unconfirmed testimonials | F-19, F-23 | S | Low | You (testimonials) | Trust |
| 1.15 | Fix the tenant-home open-repairs query | F-16 | S | Low | — | Tenants see their open requests |
| 1.16 | Live end-to-end test pass with a test landlord, tenant and applicant (see LAUNCH-READINESS checklist) | — | M | — | Phases 0–1 | Turns "code-reviewed" into "verified" |

## Phase 2: should fix soon after (P2)

| # | Item | Effort | Impact |
|---|---|---|---|
| 2.1 | Mobile: card layouts for tables (view-lease, add-expense, tenant-repair-requests, maintenance history/cost, finance pages); `overflow-x:hidden` safety net on 38 pages; labels on the bottom tab bar | M | App-like phones, no sideways scroll |
| 2.2 | Design consistency: property-record pages onto the shared DM Sans / card styles; canonical nav labels; 3px shimmer bar instead of full-screen overlays | M | Feels like one product |
| 2.3 | Merges (after approval): payment forms → one; maintenance-history → maintenance-requests; portfolio dashboard → reports; all-properties-summary → property-management; four sign-in pages → one | L | Fewer places for numbers to disagree |
| 2.4 | Finish the payment inbox (Postmark + n8n live; set the dashboard address; hide the card until connected) | S (code) + your setup | Saves monthly data entry |
| 2.5 | Messages unread state; documents delete removes the file; reimbursement approval made atomic | M | Polish |
| 2.6 | Database tidy-ups from the advisors: wrap `auth.uid()` in `(select …)` in 28 policies; drop 4 duplicate indexes; add the missing FK indexes; revoke EXECUTE on trigger functions from API roles; enable leaked-password protection | M | Performance at scale, hygiene |
| 2.7 | Maintenance-acknowledgment: send only to the tenant on the lease (suspected abuse path) | S | Prevents email abuse |
| 2.8 | Move `tenant-magic-link-email.html` out of the deployed folder; pin `chart.js` to a version on the page that loads it unpinned | S | Hygiene |

## Phase 3: later (P3)

- Real "Ask Rental Genie" over the rent and expense data.
- Snap-it for maintenance invoices.
- Lease renewal drafting.
- Plan limits and Stripe Connect, once there are paying landlords besides you.
- Automated tests: a smoke-test harness in CI (load every page at 390 and 1280 with a stub; fail on JS errors or sideways scroll) and SQL tests for rent math and RLS. The harness built for this audit is a starting point.
