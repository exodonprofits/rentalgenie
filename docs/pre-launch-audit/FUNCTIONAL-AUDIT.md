# Functional audit

Pre-launch inspection, 2026-10-09. Consolidated defects, most severe first. The full per-page findings, about 120 items each with file:line, are in `detail/`. This file lists the ones that matter for launch, with how each was verified.

## Verification labels

| Label | Meaning |
|---|---|
| **DB-verified** | Reproduced against the live database in a transaction that rolled back (no data changed) |
| **Runtime-verified** | Reproduced in headless Chromium against the real page code, with a stubbed database |
| **Data-verified** | Confirmed with read-only counts on live data |
| **Code-verified** | Traced in the source by a reviewer and re-read by the lead reviewer |
| **Code-reviewed** | Traced by a reviewer only; not re-read |

Severity: P0 launch blocker · P1 must fix before launch · P2 should fix · P3 later.

---

### F-01 · Adding a property always fails · **P0** · DB-verified
- **Page:** `add-property.html` (create mode). Entry points: Property Management "Add Property" and the dashboard checklist.
- **Steps:** Sign in as a landlord → Properties → Add Property → fill in the name and address → Save.
- **Expected:** The property is created.
- **Actual:** The insert is rejected.
  - Live test as the landlord with a workspace: `23502 null value in column "owner_id" … violates not-null constraint`.
  - Without a workspace in the URL: `42501 row-level security`.
- **Root cause:** The payload built at `add-property.html:1509-1574` never sets `owner_id`, and `company_id` is set only when the URL carries it (`:1567`). Both columns are NOT NULL with no default and no insert trigger. Existing properties were created under the old project's rules, which is why this went unnoticed.
- **Fix:** Set `owner_id` to the signed-in user's id and always resolve `company_id` (as `resolveActiveCompanyId` does elsewhere). Alternatively, add a `before insert` trigger that fills `owner_id = auth.uid()`; that also protects other insert paths.
- **Impact:** Step one of onboarding. **No new landlord can start.**

### F-02 · Script injection and open redirect through sign-in links · **P0** (tenant) / **P1** (landlord) · Runtime-verified
- **Pages:** `tenant-login.html:599, 624, 651` (`?redirect=`); `login.html:554-558`, used at `:579` and `:632` (`?returnTo=`).
- **Steps (runtime):**
  - `tenant-login.html?redirect=javascript:void(window.__pwned=1)` with a signed-in session sets `window.__pwned = 1`. The script runs on rentalgenieai.com, where the session token is stored.
  - `tenant-login.html?redirect=https://evil.example/x` sends the user to the external site.
  - `login.html?returnTo=//evil.example/x` sends a signed-in landlord to the external site with no click.
  - `login.html?returnTo=javascript:…` did **not** execute in Chromium (`location.replace` blocks it), but the check accepts it.
- **Expected:** Only same-site paths are followed.
- **Fix:** One shared check: `new URL(raw, location.origin)`, then require `url.origin === location.origin`, else use the default page. It must still accept the absolute same-origin URL that `tenant-portal.html:831` passes.

### F-03 · Tenant text runs as script in the landlord's Maintenance History · **P0** · Code-verified
- **Page:** `maintenance-history.html:970`. The `esc()` at `:719` escapes `& < >` but not quotes.
- **Steps:** A tenant files a repair request whose description contains `" onmouseover="…`. The landlord opens Maintenance History and hovers the row.
- **Actual:** The description is placed in `title="…"` and breaks out of the attribute (stored XSS from tenant to landlord).
- **Fix:** Escape `"` and `'` in `esc()`, or build the row with `createElement` and `textContent`.

### F-04 · `return_to` / `return` parameters run `javascript:` on Back · **P1** · Code-verified
- **Pages:** `property-tax.html:751, 1239`; `property-insurance.html:532, 920`; `add-expense.html:692, 1301`.
- **Steps:** Open `property-tax.html?return_to=javascript:alert(1)` and click Back.
- **Actual:** `location.href = returnTo` runs the script (requires one click on a crafted link).
- **Fix:** Same shared same-origin check as F-02.

### F-05 · Tenants can't see the payments their landlord recorded · **P0** · Data-verified
- **Pages:**
  - Writers: `add-payment.html:1012`, `lease-rent-center.html:4642`, `rg_confirm_incoming_payment`.
  - Readers: `tenant-payments.html:1083`, `tenant-portal.html`.
- **Data:** 26 of 118 live rent_log rows have neither `tenant_id` nor `tenant_email`, and **all 26 are the payments logged since July 2026** (latest 2026-09-25). The tenant policy `rent_log_select_tenant_self` only shows rows matching one of those two columns.
- **Actual:** A tenant who paid every month sees no recent payments, "$0 paid this month", and possibly "Payment may be past due".
- **Fix:**
  - Have every payment writer set `tenant_id` and `tenant_email` from the lease. A `before insert` trigger from `lease_id` or `(company_id, property_id)` is the robust option.
  - Backfill the 26 rows (a data migration, needs approval).
  - Have tenant pages read by `tenant_id` **or** email.

### F-06 · Unescaped database text in `innerHTML` · **P1** · Code-verified (add-expense), code-reviewed (others)
- `add-expense.html:801-803`: the Recent list inserts `vendor`, `category` and `date_paid` raw. `vendor` can come from the AI reading of an uploaded receipt, so text printed on a receipt image ends up in the HTML.
- `reports-analytics.html:1267, 1859-1863, 1940, 1959-1961, 2033-2034`.
- `dashboard.html:3430, 3640, 4692`, plus an inline `onclick` at `:4694` that a `'` in a property name breaks out of.
- `lease-rent-center.html:4266, 4270, 4399` (tenant name, payment method).
- `tenant-portal-picker.html:332` (lease status).
- **Fix:** `escHtml()` at each site, or `createElement` per CLAUDE.md.

### F-07 · HOA editing is broken · **P1** · Code-verified
- `hoa-info.html:480` selects `unit_type`, which doesn't exist, so the property never loads and the hero stays hidden.
- `hoa-info.html:459-465` links to the form with `property_id` only; `hoa-form.html:265` reads only `property`, so Save always stops with "No property specified in URL."
- `hoa-form.html` also loads Supabase in `<head>` (`:7`) and links to a missing `help-center.html` (`:236`).
- **Fix:** Drop `unit_type`; make hoa-form resolve the property by `property_id`.

### F-08 · "Edit Lease" creates a duplicate lease · **P1** · Code-verified
- `lease-rent-center.html:3582` links to `lease-form.html?…&edit=1` without a `lease_id`. `lease-form.html:870-876` treats edit as `!!leaseId`, so the form opens in create mode and saving inserts a second lease.
- **Fix:** Pass the current lease's id (`&lease_id=…`).

### F-09 · The dashboard checklist's "Add a lease" can't be saved · **P1** · Code-reviewed
- `dashboard.html:4465` opens bare `lease-form.html`, which has no property picker. `property_id` and `company_id` are NOT NULL, so the save fails.
- **Fix:** Route through Lease & Rent Center with a property selected, or add a property picker to the form.

### F-10 · Maintenance urgency values don't match the database · **P1** · Code-verified against the constraint
- **Constraint:** `maintenance_requests_urgency_level_check` allows `Low | Normal | High | Emergency` (`rg_01_tables.sql:575`).
- `add-maintenance-request.html:351-353` offers High / **Medium** / Low, so a landlord logging a "Medium" request is rejected.
- `maintenance-requests.html:1606-1610, 1701-1704, 2679, 2715`: the edit modal knows only High/Medium/Low. Tenant requests ("Normal" / "Emergency") open with no matching option and save `null` into the NOT NULL column, so every save fails. "Emergency" never counts as high priority.
- **Fix:** One vocabulary everywhere: Low / Normal / High / Emergency.

### F-11 · Archiving a maintenance request reports failure and it stays listed · **P1** · Code-reviewed
- `maintenance-requests.html:2770` calls an undefined `closeModal()` after a successful archive, so the landlord sees "Failed to archive".
- Neither maintenance page filters `archived_at`.

### F-12 · Rent is still calculated in the browser, against CLAUDE.md, and disagrees with the database · **P1** · Code-reviewed
- **Lease & Rent Center:**
  - The ledger adds late fees to the balance; `rg_rent_status` doesn't.
  - Quick Peek sums future months (`:3936`).
  - Holdover payments are dropped by `paymentBelongsToLease`, so paid months show late. Sites: `:2752-2963, 3912-3980, 4100-4140, 4213-4277`.
- **Fallbacks still shipped:** `dashboard.html:3837-3935`, `lease-rent-center.html:3257-3383`.
- **A fourth due-date implementation:** `add-payment.html:742-771`.
- **Tenant pages:**
  - `tenant-portal.html:819-826, 950-957, 975-980, 1045-1050`.
  - `tenant-payments.html:697-702, 959-982`.
  - The due day is capped at 28, and "paid this month" goes by payment date.
- **reports-analytics** quick peek: `:1389-1474`.
- **Fix:** Read from `rg_rent_schedule` / `rg_rent_status`. Tenants need a tenant-scoped wrapper, because they can't read `properties`.

### F-13 · Rent report queries columns that don't exist · **P1** · Code-verified
- `reports-analytics.html:1810` selects `monthly_rent` and `rent` from leases. The query fails, so Expected and Rate show "—" and every payment reads "Partial".
- CSV and maintenance columns are also wrong: `notes`, `cost`, `priority`, `title`, `issue` (`:1660-1682, 2002, 2027-2034`).

### F-14 · Profit and cash-flow figures are wrong · **P1** · Code-reviewed
- **Net YTD** subtracts 12 months of mortgage from year-to-date rent: `portfolio-financial-dashboard.html:1049, 1063`; `all-properties-summary.html:856`.
- **Double counting:** mortgage, tax, insurance and HOA are counted twice when also logged as expenses, which add-expense's mortgage split does by design.
- **Cap rate** is computed after debt service (`reports-analytics.html:1487`).
- **Archived payments, properties and requests are still counted:**
  - `reports-analytics.html:1402, 1551, 1806, 1988`.
  - `portfolio-financial-dashboard.html:974, 1015`.
  - `all-properties-summary.html`.

### F-15 · Dates shift a day, so rent paid on the 1st lands in the previous month · **P1** · Code-reviewed
- `new Date('YYYY-MM-DD')` parses as UTC; in US time zones it becomes the previous evening.
- Sites: `reports-analytics.html:1531-1535`, `portfolio-financial-dashboard.html:1030, 1039`, `maintenance-cost.html:896, 920, 941`, expense-tracking display.
- **Fix:** Parse date-only strings as local dates (the pattern `toISODateOnly` / `parseISODateOnly` in lease-rent-center already does this).

### F-16 · Tenant home: the "open repairs" card never appears · **P1** · Code-reviewed
- `tenant-portal.html:1065-1072` selects `issue_summary`, `date_submitted` and `inserted_at`, which don't exist. The error is swallowed.

### F-17 · Lease states mishandled · **P1** · Code-reviewed
- `rg_rent_schedule` charges rent on **draft** leases.
- No page writes `terminated_date`, so a lease marked "Terminated" keeps accruing until its original end date (`lease-form.html:551-557`).
- `property-management.html:2329-2336` shows month-to-month and holdover properties as "Vacant / Add Lease".
- "Convert to M2M" erases the original `lease_end` (`lease-rent-center.html:2856-2860`).

### F-18 · Supabase client loaded in `<head>` (CLAUDE.md hard rule #1) · **P1** · Code-verified
- `signup.html:7`, `forgot-password.html:7`, `tenant-login.html:29`, `tenant-lease.html:12`, `hoa-form.html:7`.
- CLAUDE.md records this as the cause of "logged in but no data" sessions. Three of these pages are the ones that **create** sessions.

### F-19 · Fake account actions · **P1** · Code-verified
- `account.html:1107-1117`: "Export my data" and "Delete account" show success messages but do nothing.
- `tenant-account.html:550-558`: "Phone number saved" when 0 rows were updated, for tenants not yet linked to their login (2 of 8 tenants live).

### F-20 · Applications can be claimed by email without proof of ownership (suspected) · **P1 to verify** · Code-reviewed
- `claim_my_applications` (SECURITY DEFINER) attaches every application whose `applicant_email` matches the caller's auth email.
- Safe only if Supabase requires email confirmation before an account can sign in. All 7 live users are confirmed, but **no one has signed up since the cutover**, so the setting is unproven.
- **Check:** Supabase → Auth → Providers → Email → "Confirm email" must be on.

### F-21 · Support address is on a different domain · **P1** · Code-verified
- 11 places use `support@rentalgenie.app` (contact-us.html:205, 218, 220, 275; hoa-form.html:242; others). The site is rentalgenieai.com.
- If `rentalgenie.app` isn't owned and set up for mail, every support email is lost.

### F-22 · Legal pages unfinished · **P1** · Code-verified
- `privacy.html:221, 335` and `terms.html:221, 317, 330` contain `[LEGAL ENTITY NAME]`, `[STATE]`, `[COUNTY]` and `[MAILING ADDRESS]`.
- Neither page covers rental applicants, whose income and employer data `listings.html` collects.
- The privacy page names the wrong hosting provider (`privacy.html:288`).
- The terms describe escrow reconciliation, which doesn't exist.

### F-23 · Copy promises features that don't exist · **P2** · Code-verified
- `tenant-login.html:422, 430` "Pay rent" (online payments aren't built).
- Possibly invented testimonials: `login.html:421-428`, `tenant-login.html:439-446` ("needs confirming" — only you know).
- Dashboard "Ask Rental Genie" is a keyword router presented as AI; the floating widget is dead (`dashboard.html:2899-2909, 4907-4950`).
- The payment inbox card shows for every landlord while it isn't connected.

### F-24 · Tenant pages: navigation on phones · **P1** · Runtime-verified
- On 6 of 7 tenant pages the user chip displaces the hamburger, the only mobile navigation, off-screen (15 px at 390, 85 px at 320).
- One CSS line each; already fixed on tenant-payments.html.

### F-25 · New landlords get no workspace automatically · **P1** · Code-verified
- Sign-up creates no company. The only creators are "Create my workspace" buttons on `expense-tracking.html:2095` and `lease-rent-center.html:4866`.
- The dashboard, where new users land, doesn't offer it. Combined with F-01, a brand-new landlord can't get to a working state without help.

---

## Reviewer claims that did not hold up

| Claim | Outcome |
|---|---|
| Tenant can inject HTML via `maintenance_requests.status` | **Not exploitable.** A CHECK constraint limits status to Open / In Progress / Resolved. Escape anyway (P3). |
| "No page creates a company for new landlords" | **Partly wrong.** Two pages do, behind a button. Reclassified as an onboarding gap (F-25). |
| reports-analytics shows "No workspace found" | **Harness artifact.** It uses a joined query the stub didn't support. Not a defect. |

## Not tested (needs a live environment)

- Every flow end to end with real accounts: sign-up, email confirmation, password reset email, tenant magic link, applicant magic link.
- File uploads to the private buckets, and signed-link downloads.
- Snap-it receipt and lease reading since the cutover.
- Maintenance acknowledgment emails (Resend secrets unverified).
- Payment inbox end to end (Postmark and n8n not live yet).
- Safari / iOS, Firefox, on-screen keyboard, PWA home-screen mode.
