# Feature recommendations

Pre-launch inspection, 2026-10-09. These are recommendations only. **Nothing is removed or merged without explicit approval.** CLAUDE.md also says to ask before deleting a page, because "unused" pages have turned out to be linked.

## Guiding view

Rental Genie's core is clear and valuable: **know what every rental earns, and stop chasing rent paperwork.** In practice:
- Properties
- Leases
- The rent ledger (rent computed in the database)
- Expenses (with Snap-it receipts)
- Maintenance
- The tenant portal
- Reports

The product has grown more pages than workflows. There are three report dashboards, three maintenance views, four ways to record a payment, and four sign-in pages. Each duplicate is another place for numbers to disagree; the audit found exactly that between the dashboards and the database. Fewer, more reliable surfaces will feel more professional than more partially working ones.

## Decision table

| Module | Decision | Why it should exist / why not | Already solved elsewhere? | How often used | What would make it better |
|---|---|---|---|---|---|
| Dashboard | **KEEP / IMPROVE** | The daily "what needs me" screen; uses rg_rent_status | — | Daily | Delete the JS rent fallback. Offer "Create workspace" and "Add property" for new users. Hide the payment inbox until it's connected. |
| Lease & Rent Center | **KEEP / IMPROVE** | The core rent workflow | — | Weekly | Ledger and balances from rg_rent_schedule only. Mobile card layout for the ledger. One payment form. |
| Add payment page + LRC mark-paid modal + LRC drawer | **MERGE** | Four ways to record a payment, with different rules (due-date logic, tenant link) | Yes, three times | Monthly | One payment form, used everywhere, that always writes the tenant link (F-05) |
| Lease form / View lease | **KEEP / IMPROVE** | Lease lifecycle; Snap-it lease reading is a differentiator | — | Monthly | Fix edit (F-08); set `terminated_date`; property picker |
| Invite tenant | **IMPROVE** (or merge into LRC) | Gets tenants into the portal | Partly (LRC More menu) | Rare | Check the email against the lease; record that an invite was sent |
| Property management / Add property / Property overview | **KEEP / IMPROVE** | Core records | — | Weekly | Fix create (F-01, P0); correct vacancy labels |
| Property tax / insurance / financing / mortgage activity / HOA | **KEEP / IMPROVE** | Real landlord needs (escrow and tax season), and they feed the cost picture | — | Monthly to yearly | One shared look. Link them all from Property Overview as tabs or cards. Fix HOA (F-07) and the `return_to` XSS. |
| Expense tracking + Add expense | **KEEP** | Core; Snap-it saves real time | — | Weekly | Escape the Recent list; local-date parsing |
| Maintenance requests | **KEEP / IMPROVE** | Core; the tenant-facing promise | — | Weekly | One urgency vocabulary (F-10); fix archive (F-11) |
| Maintenance history | **MERGE into Maintenance requests** (ask first) | A read-only copy of the same list with exports; reachable only from two report pages | Yes | Rare | An "All / Archived" filter and an export button on maintenance-requests |
| Maintenance cost report | **MERGE** into reports (or keep once fixed) | Expenses filtered to one category, plus a vendor chart | Mostly (expense reports) | Rare | A preset in reports-analytics |
| Reports & analytics | **KEEP / IMPROVE (the one report hub)** | Tax-time and performance questions | — | Monthly | Fix the rent report (F-13), net/cap-rate math (F-14) and dates (F-15). Absorb the two pages below. |
| Portfolio financial dashboard | **MERGE into reports-analytics** | Everything except its per-property table already exists in reports' portfolio mode; its Net YTD is wrong | Yes | Rare | Move the per-property YTD table into reports |
| All properties summary | **MERGE into property-management** (ask first; linked from several footers) | Duplicates the property cards plus YTD numbers | Yes | Rare | Add the YTD line to the property-management cards |
| Messages (landlord inbox) | **KEEP / IMPROVE** | Tenant communication | — | Weekly | Unread state (`read_at` exists but isn't used) |
| Property documents | **KEEP** | Lease and notice storage, private | — | Monthly | Sign-in redirect; delete the file as well as the row |
| Publish listing + Listings + applications | **KEEP** | Vacancy-filling funnel; just hardened and extended | — | Per vacancy | Entry point added; consider unread markers for new applications |
| Payment inbox (forward alerts → confirm) | **KEEP / FINISH** | Biggest time saver for Zelle/Venmo landlords; DB side built and tested | — | Monthly | Finish the Postmark + n8n setup; hide the card until connected |
| "Ask Rental Genie" (dashboard) | **INVESTIGATE / RELABEL** | It's a keyword router, not AI. Presenting it as AI over-promises. | — | Unknown | Either make it real (a Claude call over rg_rent_status data, a natural fit for the existing AI proxy pattern) or label it "Quick links" |
| Floating Genie widget (dashboard) | **REMOVE** (ask first) | Dead code per review (`dashboard.html:1528-1531`) | — | Never | — |
| Tenant portal (7 pages) | **KEEP / IMPROVE** | Tenants actually use it (6 of 8 have logins) | — | Weekly | Fix payment visibility (F-05), the open-repairs card and mobile nav. Rent figures from the database. |
| Tenant portal preview (picker) | **INVESTIGATE** | Landlords previewing the tenant view; low value, some defects | — | Rare | Keep only if you use it to support tenants |
| Sign-in pages (login, login-select, tenant-login, applicant-login) | **MERGE** into one sign-in page with three choices | Four front doors confuse users, and two have redirect bugs | Yes | Every visit | One page: Landlord / Tenant / Applicant. One shared, safe redirect check. |
| Account | **IMPROVE** | Needed | — | Rare | Remove or implement "Export data" / "Delete account"; implement or hide notification preferences |
| Magic-link email template (`tenant-magic-link-email.html`) | **MOVE** out of the site | Not a page; publicly shows template code | — | — | `supabase/templates/` |
| Escrow reconciliation, Stripe online payments, plan limits | **Not present: don't advertise** | Known gaps (CLAUDE.md) | — | — | Remove the claims from the terms, the tenant-login copy and the marketing text until built |

## Where AI would genuinely help (later)

| Opportunity | Why it's a good fit | Builds on |
|---|---|---|
| Real "Ask Rental Genie": answers like "Who hasn't paid this month?" or "What did Oak Duplex net this year?" | The data is already structured and the rent engine is in the database. A Claude call with rg_rent_status / expense totals as context is small and safe (read-only). | `rental-genie-ai-proxy` pattern |
| Payment inbox AI fallback for banks other than Chase/Venmo | Already in the n8n workflow | Payment inbox |
| Snap-it for maintenance invoices: invoice → maintenance cost + expense | Reuses rg-snap | rg-snap |
| Lease renewal drafting from the current lease | Reuses lease reading | rg-snap lease mode |
