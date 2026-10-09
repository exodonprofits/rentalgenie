# Platform inventory

Pre-launch inspection, 2026-10-09 (main at `a84986f`).

## Architecture

| Layer | What it is |
|---|---|
| Front end | 49 self-contained `*.html` pages (no build step, CDN deps: supabase-js@2, Chart.js on 2 pages). `shared/config.json`, `images/` |
| Hosting | Bluehost (Apache), rentalgenieai.com. Deployed by `.github/workflows/deploy-bluehost.yml` on every merge to main, with a served-commit self-check |
| Database / auth | Supabase project `xqmnaeujwumlcoyhgzuk` (Postgres 17): 30 tables/views, RLS on every table, rent math in `rg_rent_schedule` / `rg_rent_status`. Migrations in `supabase/rentalgenie-project/migrations/` (rg_00–rg_08) |
| Edge Functions | `rental-genie-ai-proxy` (AI listing description), `rg-snap` (receipt/lease reading), `maintenance-acknowledgment` (DB-trigger webhook → tenant message + Resend email) |
| Automation | n8n Cloud: payment inbox workflow (`json/rental-genie-payment-inbox.n8n.json`, not yet live: Postmark inbound in setup), older workflow JSONs in `json/` |
| Integrations | Anthropic API (via Edge Functions and n8n), Resend (email), Postmark (inbound email, in setup), Google Fonts |
| Users | Landlords (company owners/members), tenants (magic-link login), applicants (magic-link login), public visitors (listings) |

## How to read the status column

**Verification levels:**
- **Rendered:** the page loaded in headless Chromium at 5 widths with a stubbed database. Done for every page.
- **Code-reviewed:** read line by line against the live schema and CLAUDE.md. Done for every page.
- **DB-verified:** the claim was checked against the live database in a rolled-back transaction.
- **Not live-tested:** nothing below was exercised with real accounts against the real database. That needs a test landlord, tenant and applicant (see LAUNCH-READINESS).

**Status values:**
- **Working:** no material defect found.
- **Partial:** works, with defects.
- **Broken:** the core action fails.

Finding IDs (F-xx) refer to FUNCTIONAL-AUDIT.md.

## Landlord app

| Module | Purpose | Location | Status | Value | Recommendation | Priority |
|---|---|---|---|---|---|---|
| Dashboard | Daily overview: rent attention (rg_rent_status), KPIs, setup checklist, payment inbox, "Ask Rental Genie" | `dashboard.html` | Partial: JS rent fallback still shipped (F-12); checklist opens a lease form that can't save (F-09); payment inbox shown though not connected; unescaped names (F-17) | H | IMPROVE | P1 |
| Lease & Rent Center | Per-property lease panel, rent ledger, attention queue, payment entry | `lease-rent-center.html` | Partial: ledger/Quick Peek/late fees computed in JS and disagree with rg_rent_status (F-12); Edit Lease creates a duplicate (F-08); hard-deletes payments | H | IMPROVE (core) | P1 |
| Add / edit payment | rent_log entry form (also loaded in the LRC drawer) | `add-payment.html` | Partial: writes no tenant link (F-05); fourth due-date implementation | M | MERGE with LRC mark-paid modal | P1 |
| Lease form | Create / edit / renew a lease; Snap-it lease reading | `lease-form.html` | Partial: edit-from-LRC duplicates (F-08); bare open can't save (F-09); payment-method section added Oct 2026 | H | IMPROVE | P1 |
| View lease | Read-only lease detail, history, documents | `view-lease.html` | Working, minor issues; 140 px sideways scroll at 390 px | M | KEEP | P2 |
| Invite tenant | Sends a tenant magic link | `invite-tenant.html` | Partial: saves nothing, no check against lease email | M | IMPROVE / merge into LRC | P2 |
| Property management | Property cards, KPIs, company picker | `property-management.html` | Partial: month-to-month / holdover properties shown as "Vacant" | H | IMPROVE | P1 |
| Add / edit property | Property record with finance, PM and utility fields | `add-property.html` | **Broken for create**: insert omits NOT NULL `owner_id` (F-01, DB-verified) | H | FIX NOW | **P0** |
| Property overview | Single-property hero: lease, mortgage, net, links to sub-records | `property-overview.html` | Working; Publish Listing link added Oct 2026 | M | KEEP | P2 |
| Publish listing | Public listing fields, application mode, applications, screening tracker | `publish-listing.html` | Working (hardened Oct 2026); bootstrap not canonical | H | KEEP | P2 |
| Expense tracking | Expense ledger with filters, archive + undo | `expense-tracking.html` | Working; UTC date shift (F-15) | H | KEEP | P2 |
| Add expense | Expense form, receipt upload, Snap-it, mortgage split | `add-expense.html` | Partial: unescaped "Recent" list incl. AI-read vendor (F-06); `return` param XSS (F-04); split drops receipt; 97 px sideways scroll | H | IMPROVE | P1 |
| Maintenance requests | Landlord work queue: status, edit, archive, photos, reimbursements | `maintenance-requests.html` | Partial: urgency vocabulary wrong, so edits of tenant requests fail (F-10); archive reports failure and archived rows stay (F-11) | H | IMPROVE | P1 |
| Add maintenance request | Landlord logs a request by hand | `add-maintenance-request.html` | Partial: "Medium" urgency rejected by DB constraint (F-10) | M | IMPROVE | P1 |
| Maintenance history | Read-only request log, export | `maintenance-history.html` | Partial: stored XSS via tenant text in a title attribute (F-03); wrong "Assigned To" columns; no company scope | L | MERGE into maintenance-requests (ask first) | P0 (XSS) |
| Maintenance cost report | Maintenance-category spend, vendor breakdown | `maintenance-cost.html` | Working with defects (no company scope, date shift) | L | MERGE into expense reports or keep once fixed | P2 |
| Messages (landlord inbox) | Threads with tenants, reply, resolve | `tenant-messages.html` | Working; no read/unread | H | KEEP + IMPROVE | P2 |
| Property documents | Upload/delete tenant documents (private bucket, signed links) | `property-documents.html` | Working; no sign-in redirect; delete leaves file in storage | M | KEEP | P2 |
| Reports & analytics | Quick peek, 12-month trend, rent/expense/maintenance reports, CSV | `reports-analytics.html` | Partial: rent report queries non-existent columns (F-13); balances recomputed in JS; unescaped DB text (F-06); archived rows counted | H | IMPROVE (make it the one report hub) | P1 |
| Portfolio financial dashboard | Portfolio YTD rent/expense/mortgage, charts, per-property table | `portfolio-financial-dashboard.html` | Partial: Net YTD subtracts 12 months of mortgage (F-14) | M | MERGE into reports-analytics | P2 |
| All properties summary | Property cards with YTD numbers | `all-properties-summary.html` | Partial: same Net YTD error; picks wrong lease | L | MERGE into property-management (ask first) | P2 |
| Property tax | Tax history + current snapshot | `property-tax.html` | Working; `return_to` XSS (F-04); account # blank | M | KEEP, fix | P1 |
| Property insurance | Insurance history + snapshot | `property-insurance.html` | Working; `return_to` XSS (F-04); only reachable from add-property | M | KEEP, fix, link from overview | P1 |
| Financing | Loan history, set current loan | `property-finance.html` | Working; lender URL not scheme-checked | M | KEEP | P2 |
| Mortgage activity | Mortgage payment ledger, CSV | `property-mortgage-activity.html` | Partial: discards confirmation # and effective date | M | KEEP, fix | P2 |
| HOA info | HOA details and history | `hoa-info.html` | Partial: selects non-existent `unit_type`, hero never loads (F-07) | M | FIX | P1 |
| HOA form | Edit HOA record | `hoa-form.html` | **Broken**: opened without the `property` param it requires, Save always fails (F-07); Supabase in `<head>`; links to missing help-center.html | M | FIX (rebuild on property_id) | P1 |
| Account | Profile, password, notifications, workspace, danger zone | `account.html` | Partial: "Export my data" / "Delete account" are fake (F-19); 24 px sideways scroll | M | IMPROVE | P1 |
| Tenant portal preview (picker) | Landlord previews a property's tenant portal | `tenant-portal-picker.html` | Partial: lists from leases only, unescaped status | L | IMPROVE or remove | P3 |

## Tenant portal

| Module | Purpose | Location | Status | Value | Recommendation | Priority |
|---|---|---|---|---|---|---|
| Tenant home | Rent, paid this month, lease status, quick actions, open repairs | `tenant-portal.html` | Partial: recent payments invisible (F-05, DB-verified); open-repairs card queries non-existent columns (F-16); rent computed in JS; hamburger off-screen on phones | H | IMPROVE | P0 (via F-05) |
| My lease | Lease detail, timeline, renewal request | `tenant-lease.html` | Working; Supabase in `<head>` (F-18); hamburger bug | H | KEEP, fix | P2 |
| Payments | History, how to pay, preferred method | `tenant-payments.html` | Partial: history misses every payment logged since July (F-05) | H | IMPROVE | P0 (via F-05) |
| Repair requests | File requests with photos; reimbursements | `tenant-repair-requests.html` | Working; tables overflow on phones (65 px) | H | KEEP, fix mobile | P2 |
| Documents | Shared documents via signed links | `tenant-documents.html` | Working; hides docs saved without tenant_id | M | KEEP | P2 |
| Contact | Message the landlord, history | `tenant-contact.html` | Working; history cut at 200 chars | M | KEEP | P2 |
| My account | Phone, login email | `tenant-account.html` | Partial: false "saved" for unlinked tenants; email change can cut a tenant off | M | IMPROVE | P1 |

## Sign-in, public and applicant

| Module | Purpose | Location | Status | Value | Recommendation | Priority |
|---|---|---|---|---|---|---|
| Home page | Marketing | `index.html` | Working (copy mentions unbuilt features) | H | KEEP | P2 |
| Landlord sign-in | Email/password login | `login.html` | Partial: open redirect via `returnTo` (F-02, runtime-verified) | H | FIX | P1 |
| Sign-in chooser | Landlord vs tenant | `login-select.html` | Working | L | MERGE into one sign-in page | P2 |
| Sign up | Create landlord account | `signup.html` | Partial: Supabase in `<head>`; no workspace created; no terms consent; untested on the new project (no sign-ups since cutover) | H | IMPROVE | P1 |
| Forgot password | Reset link + set new password | `forgot-password.html` | Partial: Supabase in `<head>`, possible race | H | IMPROVE | P1 |
| Tenant sign-in | Tenant magic link | `tenant-login.html` | **Defective**: `?redirect=javascript:` executes (F-02, runtime-verified); promises "Pay rent" | H | FIX NOW | **P0** |
| Applicant sign-in | Applicant magic link | `applicant-login.html` | Working | M | KEEP | P3 |
| My applications | Applicant's applications and messages | `my-applications.html` | Working; shows a landlord's incoming applications as "mine"; claim-by-email risk (F-20) | M | IMPROVE | P2 |
| Listings | Public vacancy board + application form | `listings.html` | Working (hardened Oct 2026; application modes) | H | KEEP | — |
| Contact us | Support email | `contact-us.html` | Working, but uses `support@rentalgenie.app` (F-21) | M | KEEP, fix address | P1 |
| Privacy policy | Legal | `privacy.html` | Partial: unfilled placeholders, applicants not covered, wrong host named (F-22) | H | FIX before launch | P1 |
| Terms of service | Legal | `terms.html` | Partial: unfilled placeholders, describes unbuilt features (F-22) | H | FIX before launch | P1 |
| Magic-link email template | Supabase Auth email (Go template) | `tenant-magic-link-email.html` | Not a page; publicly deployed with raw template syntax | L | MOVE out of deployed folder | P3 |

## Backend services

| Module | Purpose | Location | Status | Value | Recommendation | Priority |
|---|---|---|---|---|---|---|
| AI listing description | Drafts listing copy | `supabase/functions/rental-genie-ai-proxy` | **Verified working in production** 2026-10-04 (HTTP 200 after workspace key) | M | KEEP | — |
| Snap it | Receipt / lease reading | `supabase/functions/rg-snap` | Deployed, same key; categories match add-expense; not exercised since cutover | H | KEEP; test once | P2 |
| Maintenance acknowledgment | Tenant in-app message + email on new request | `supabase/functions/maintenance-acknowledgment` + trigger | Deployed; webhook secret tested; email not exercised (no requests since August); RESEND/FROM_EMAIL secrets unverified; could be abused to email arbitrary addresses (suspected) | M | KEEP; test with a real request | P2 |
| Payment inbox | Forwarded Zelle/Venmo alerts → pending payments | DB functions + n8n workflow + Postmark | DB side tested (rolled-back rehearsal); not live (Postmark/n8n setup in progress; dashboard address empty) | H | FINISH | P1 |
| Rent engine | Schedule and status | `rg_rent_schedule`, `rg_rent_status` | Working; charges rent on draft leases and on "Terminated" leases without a date (reviewer finding, not DB-tested) | H | FIX edge cases | P1 |
| Row-level security | Data isolation | 30 tables | **Anonymous visitors can read 0 rows in every table/view** (DB-verified); no table without RLS; one `with check (true)` (companies insert by signed-in users, i.e. workspace creation) | H | KEEP; tidy per advisors | P2 |
| Deploy pipeline | Merge → Bluehost with self-check | `.github/workflows/deploy-bluehost.yml` | Working (8 green runs) | H | KEEP | — |
