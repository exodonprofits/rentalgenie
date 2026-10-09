# Detailed review: money, report and property-finance pages

Part of the 2026-10-09 pre-launch audit (see ../LAUNCH-READINESS.md). Produced by a read-only code review of each page against CLAUDE.md and the live schema. CONFIRMED = traced in code; SUSPECTED = needs a runtime check. Findings marked CONFIRMED were spot-checked by the lead reviewer where noted in ../FUNCTIONAL-AUDIT.md.

# Review C: money, reports and property finance pages

Scope: expense-tracking, add-expense, reports-analytics, portfolio-financial-dashboard, all-properties-summary, maintenance-cost, property-finance, property-mortgage-activity, property-tax, property-insurance, hoa-info, hoa-form, and rg-snap EXPENSE_CATEGORIES.
Method: I read the code and checked every `.from()` column against schema.txt and the migrations in `supabase/rentalgenie-project/migrations/`. I ran `node --check` on every inline script, and all 12 pages parse cleanly. I did not run anything in a browser.

## Inventory

| Page | Purpose | Users | Reached from | Status (code-reviewed) | Value | Recommendation | Priority |
|---|---|---|---|---|---|---|---|
| expense-tracking.html | Expense ledger: filters, category tiles, archive with Undo, add/edit drawer (iframe of add-expense) | Landlord | Main nav, footer and header partials (about 30 pages) | Working | H | KEEP. Fix the UTC date display. | P2 |
| add-expense.html | Add or edit an expense, receipt upload, Snap-it (rg-snap), mortgage split | Landlord | expense-tracking drawer, add-maintenance-request | Partial (XSS in the Recent list, javascript: in return param, split drops receipt) | H | KEEP and fix | P1 |
| reports-analytics.html | Reports hub: per-property quick peek, 12-month trend, rent, expense and maintenance reports, CSV export | Landlord | Main nav (about 30 pages) | Partial (rent report broken by a bad column; trend shifts months; maintenance table and CSV use wrong columns; XSS) | H | KEEP as the single reports page; absorb portfolio-financial-dashboard | P1 |
| portfolio-financial-dashboard.html | Portfolio rent, expenses and mortgage YTD, monthly chart, category pie, per-property table | Landlord | reports-analytics card and footer, all-properties-summary, legal-page footers | Partial (YTD net subtracts 12 months of mortgage; counts archived rent and archived properties) | M | MERGE into reports-analytics portfolio mode, then retire | P1 |
| all-properties-summary.html | Property cards with occupancy, latest lease, rent/expense/net YTD | Landlord | reports-analytics card and footer, contact/privacy/terms footers | Partial (same net-YTD error; wrong lease picked; lease chip ignores the canonical states) | L | MERGE the YTD figures into property-management.html, or REMOVE (ask before deleting) | P2 |
| maintenance-cost.html | Maintenance-category expenses: KPIs, monthly bars, vendor pie, CSV | Landlord | reports-analytics card, maintenance-history, all-properties-summary | Working with defects (no company scope, UTC date shift) | M | IMPROVE, or MERGE as a "Maintenance" view of expense-tracking (category filter plus vendor pie) | P2 |
| property-finance.html | Loan history (origination, refi, etc.) and "Set as current" loan snapshot | Landlord | add-property, property-mortgage-activity | Working (portal URL not protocol-checked) | M | KEEP | P2 |
| property-mortgage-activity.html | Mortgage payment ledger, loan details, insights, CSV | Landlord | add-property, property-overview | Partial (confirmation # and effective date discarded; principal and interest never captured; javascript: portal href) | M | IMPROVE | P1 |
| property-tax.html | Tax history per year and current tax snapshot | Landlord | add-property, property-overview | Working (account # snapshot always blank; return_to is XSS-able) | M | KEEP and fix | P1 |
| property-insurance.html | Insurance policy history and current snapshot | Landlord | add-property only | Working (return_to is XSS-able) | M | KEEP and fix; link it from property-overview | P1 |
| hoa-info.html | HOA details, portal, history for a property | Landlord | property-overview, hoa-form | Partial (property query fails on `unit_type`, so the hero is hidden and the name fallback is dead) | M | KEEP and fix | P1 |
| hoa-form.html | Create or edit the HOA record and write hoa_history | Landlord | hoa-info only | Broken (hoa-info links without the `property` param this page needs, so Save always fails) | M | KEEP and rebuild on property_id | P0 |
| rg-snap EXPENSE_CATEGORIES | AI receipt categories | n/a | add-expense | Match: the 13 values equal add-expense `<option>`s (index.ts:25-39 vs add-expense.html:448-460) | n/a | n/a | n/a |

## Findings

### [P0][CONFIRMED] HOA form can never save when opened from the app — hoa-form.html:265, hoa-info.html:459-465
- **Problem:** hoa-form reads only `?property=` (`var _property=decodeURIComponent(_params.get('property')||'')`). Its only entry point, hoa-info's Edit buttons, builds the link with `property_id` and `company_id` only (`u.searchParams.set('property_id',propertyId)…` at hoa-info.html:463-464, no `property`). On submit the form stops with `if(!_property){setStatus('No property specified in URL.','err');return}` (hoa-form.html:335). After a save (only reachable with a hand-typed URL), it redirects to `hoa-info.html?property=…` (line 363), but hoa-info needs `property_id`, so it shows "No property selected". The Cancel link at line 293 has the same problem.
- **Why it matters:** Landlords cannot enter or update HOA info at all.
- **Smallest fix:** Make hoa-form key on `property_id`: load and save `property_hoa` by `property_id` (unique index `uq_property_hoa_property_id`), send `property_id` in the hoa_history insert, and redirect to `hoa-info.html?property_id=…`.

### [P1][CONFIRMED] hoa-info property query selects a non-existent column — hoa-info.html:480
- **Problem:** `select('id,name,address,property_type,unit_type')`. The schema has no `unit_type` (schema NOTE: "no market_value, no unit_type"). The request errors and `if(res.error||!res.data)return;` returns quietly. So `currentPropertyData` stays null, the hero never shows, the `property_name` fallback lookups (lines 495, 535) never run, and `navUrl()` never adds `property`.
- **Smallest fix:** Drop `unit_type` from the select.

### [P1][CONFIRMED] Rent report's lease query uses non-existent columns, so expected rent and collection rate are blank and every payment shows "Partial" — reports-analytics.html:1810
- **Problem:** `select('property_name, tenant_name, rent_amount, monthly_rent, rent, status')`. `leases` has no `monthly_rent` or `rent`, so the query errors and `leases = []`. That makes `totalExpected` 0, so "Expected" and "Rate" show "—", and the per-row status at line 1855 becomes `'Partial'` for every payment.
- **Second problem (rule violation):** Even with the columns fixed, lines 1820-1830 recompute expected rent and outstanding balance in JS (`leaseMap[p] * rentPeriodMonths`). They include ended and archived leases, and the last lease per property name wins. CLAUDE.md says this must come from `rg_rent_schedule` / `rg_rent_status`.
- **Smallest fix:** Call `rg_rent_schedule(company_id, as_of)` and sum rent, paid and balance for due dates in the period. Drop the leases query and the per-payment Paid/Partial badge.

### [P1][CONFIRMED] Quick peek recomputes this month's balance in JS from an arbitrary lease — reports-analytics.html:1389-1474
- **Problem:** It loads every lease in the company (`safeSelect('leases','*')`) and takes the first one whose name matches (line 1437), with no `archived_at`, status or date filter. It then shows `balance = monthlyRent - totalThisMonth` (line 1467) as "Remaining / Overpaid / Paid in full". This ignores due day, holdover, carried-forward arrears and payments applied to other periods. It can disagree with lease-rent-center, which uses the RPCs.
- **Also:** If the company-scoped query errors, `safeSelect` (lines 1225-1231) retries without the scope, which returns every row RLS allows.
- **Smallest fix:** Use `rg_rent_status(company_id, today)` for the property's row.

### [P1][CONFIRMED] Month bucketing shifts dates by a day: payments on the 1st land in the previous month — reports-analytics.html:1531-1535, portfolio-financial-dashboard.html:1030,1039, maintenance-cost.html:896,920,941
- **Problem:** `new Date('2026-10-01')` is UTC midnight, which is Sept 30 local time in every US time zone. `getMonth()` then puts it in the previous month. Rent is usually paid on the 1st, so the 12-month trend moves most rent one month back. Rows dated the 1st of the oldest month fall outside `keys` and are dropped. In portfolio-financial-dashboard, a Jan 1 payment goes to the December bar (`monthlyRent[11]`). maintenance-cost's "This year" filter (line 896) drops Jan 1 expenses and counts them in "Last year".
- **Related:** Display helpers have the same shift and show the date one day early: expense-tracking.html:2225 `formatDate`, all-properties-summary.html:680 `fmtDate`, maintenance-cost.html:742 `fmtDate` and CSV line 1196.
- **The reverse bug:** `new Date(y,m,1).toISOString().split('T')[0]` (reports-analytics.html:1392, 1547-1548, 1773-1774; portfolio-financial-dashboard.html:948) gives the previous day for users east of UTC. Default dates use the UTC day: add-expense.html:1283,1312; property-finance.html:1038; property-insurance.html:939.
- **Smallest fix:** For date-only strings, parse with `dateStr.slice(0,7)` for month keys and `new Date(s+'T00:00:00')` for display (reports-analytics `fmtDate` at line 1792 already does this). Build query bounds as local `YYYY-MM-DD` strings (expense-tracking's `toISODate` at line 2231).

### [P1][CONFIRMED] "Net YTD" subtracts 12 months of mortgage, and fixed costs double count expenses — portfolio-financial-dashboard.html:1049,1063; all-properties-summary.html:856; reports-analytics.html:1408-1416,1475
- **Problem 1:** `net = rentSum - (expSum + mortgage * 12)` uses a full year of mortgage against year-to-date rent (today is Oct 9, so about 2.7 extra months).
- **Problem 2:** add-expense offers "Mortgage Payment" (split into Mortgage Principal, Mortgage Interest, Property Tax, Insurance, PMI rows at add-expense.html:1197-1202), plus HOA, Insurance and Property Tax categories. Those rows are counted in `expSum`, and the same costs are subtracted again from `properties.monthly_payment` / `mortgage_pi`, `tax_monthly`, `insurance_monthly`, `hoa_monthly` and `pmi_monthly`. A landlord who logs the mortgage as an expense sees it counted twice.
- **Problem 3:** The pages define "mortgage" differently. Portfolio and all-properties use `monthly_payment || mortgage_pi`; reports-analytics uses `mortgage_pi + tax + ins + hoa + pmi`.
- **Problem 4:** reports-analytics "Cap rate" (line 1487) divides cash flow *after* debt service by the price. Cap rate is NOI (before mortgage) divided by price. Its figure is annualised from a partly elapsed month, so it reads very negative early in the month.
- **Smallest fix:** Prorate fixed costs by months elapsed. Exclude expense categories that duplicate fixed snapshot fields (or drop the snapshot when expenses exist for that month). Compute NOI without principal and interest for cap rate. Put the definition in one shared function and reuse it.

### [P1][CONFIRMED] Reports count archived (deleted) rent payments, archived properties and archived maintenance — reports-analytics.html:1402,1551,1806,1988; portfolio-financial-dashboard.html:974,1015; all-properties-summary.html:755,785,791; maintenance-cost.html:1154
- **Problem:** `archive_rent_log` exists (rg_02_functions.sql:93), and `rg_rent_schedule` excludes archived payments (`r.archived_at is null`, line 637). None of the `rent_log` queries on these pages filter `archived_at`, so a payment the landlord deleted still counts as collected. `properties` queries don't filter `archived_at` either, so archived properties appear and add their mortgage to the totals. The same applies to the dropdowns in expense-tracking.html:2350, add-expense.html:719 and maintenance-cost.html:1154. `maintenance_requests` at line 1988 is also unfiltered.
- **Smallest fix:** Add `.is('archived_at', null)` to each query (expenses already have it), or read from the `active_*` views.

### [P1][CONFIRMED] Stored XSS: database text concatenated into innerHTML without escaping — reports-analytics.html:1267,1859-1863,1940,1959-1961,2033-2034; add-expense.html:801-803
- **Evidence:** `'<td>' + (p.property_name || '—') + '</td>'`, `(p.tenant_name || …)`, `'<div class="exp-cat-name">' + c + '</div>'` (expense category), `(e.category …)`, `(r.property_name || '—')`, the company `<option>` name at line 1267, and add-expense's Recent list `<td>${r.category || "—"}</td><td>${r.vendor || "—"}</td>`. Vendor can come straight from the AI read of a receipt (rg-snap prefills vendor and note). Other company members, and tenants via `maintenance_requests.property_name`, can write some of these fields (tenant path SUSPECTED).
- **Smallest fix:** Wrap each value in `escHtml()`, or better, build rows with `createElement` and `textContent` per CLAUDE.md.

### [P1][CONFIRMED] `return_to` / `return` URL parameter is assigned to `location.href` (javascript: XSS and open redirect) — property-tax.html:751,1239; property-insurance.html:532,920; add-expense.html:692,1301
- **Evidence:** `if (returnTo) return location.href = returnTo;`. A crafted link such as `property-tax.html?property_id=…&return_to=javascript:fetch(…)` runs script in the user's session when they click Back.
- **Smallest fix:** Accept only a same-origin relative path, for example `/^[a-z0-9-]+\.html(\?|$)/i`, otherwise use the default.

### [P1][CONFIRMED] Lender portal URL put in href / window.open without an http(s) check — property-mortgage-activity.html:820; property-finance.html:916
- **Evidence:** `` `<a href="${escapeHtml(prop.lender_portal_url)}" target="_blank"…` `` (escaping does not stop `javascript:`), and `window.open(snap.lender_portal_url, '_blank', …)`. `lender_portal_url` is free text entered by users on add-property and property-finance.
- **Smallest fix:** Pass it through `safeUrl()` (as property-tax and property-insurance already do) and hide the link when the result is empty.

### [P2][CONFIRMED] Reports CSV exports and maintenance table read columns that don't exist — reports-analytics.html:1660,1671,1681-1682,2002,2027-2034,1863,1961
- **Rent CSV and table:** use `p.notes` (the column is `note`), so Notes is always empty. Status is computed from a non-existent `p.status` or the broken leaseMap.
- **Expense CSV and table:** use `e.description || e.notes` (the column is `note`), so Description is always empty or "—".
- **Maintenance:** cost is read from `r.cost || r.repair_cost || r.amount` (the column is `estimated_cost`), so Cost is always $0 and "—". Priority is read from `r.priority || r.urgency` (the column is `urgency_level`, per the CLAUDE.md gotcha), so it is always blank. The table's issue column uses `r.title || r.issue || r.description` (the column is `issue_description`), so it is always "—".
- **Smallest fix:** Use `note`, `estimated_cost`, `urgency_level` and `issue_description`.

### [P2][CONFIRMED] Mortgage activity discards confirmation # and effective date; principal and interest never captured — property-mortgage-activity.html:1100-1118
- **Problem:** The standard form reads `confirmNum` but never sends it (`confirmation_number` exists). The `effectiveDate` input (line 530) is never read. Only `payment_amount`, `escrow_amount` and `notes` are inserted. The estimated principal split is shown but not saved, so the "Principal Paid" and "Interest Paid" insights and the table columns are always $0.00 unless rows were inserted elsewhere.
- **Also:** "Parse Snapshot" and "Import CSV" buttons (lines 487-488) only alert "coming soon".
- **Smallest fix:** Save `confirmation_number`, `effective_date`, and principal and interest fields (add inputs or save the estimate). Hide the placeholder buttons.

### [P2][CONFIRMED] Mortgage split drops the receipt — add-expense.html:1187-1203
- **Problem:** The `base` object for the split rows omits `receipt_url`, `receipt_path` and `property_id`. A receipt attached to a mortgage payment is lost. The split also writes category `"PMI"`, which is not one of the canonical 13 categories, so the expense-tracking category filter can't select it.
- **Smallest fix:** Copy `receipt_url`, `receipt_path` and `property_id` into `base`, and add "PMI" to the canonical list (page, expense-tracking CATEGORIES and rg-snap) or map it to "Mortgage Payment".

### [P2][CONFIRMED] all-properties-summary picks the wrong lease and mislabels states — all-properties-summary.html:785-788,697-708
- **Problem:** The leases query is not scoped to the company and does not filter `archived_at` or status. The first row by `lease_start desc` becomes "the" lease, so an archived or future lease can show as the current tenant. `leaseStatusChip` checks `'terminated'`, which is not a lease state. Per CLAUDE.md the states are active, holdover, month_to_month and ended. As a result, holdover and month_to_month leases show "Expired" (end date passed) and `ended` leases with a future end show "Active".
- **Smallest fix:** Filter `.is('archived_at',null).eq('company_id',cid)` and map the four canonical states.

### [P2][CONFIRMED] maintenance-cost ignores the active company — maintenance-cost.html:1154,1173
- **Problem:** Neither the properties nor the expenses query has a `company_id` filter, so a user in two workspaces sees both mixed together. The other report pages scope by `rg_active_company_id`.
- **Smallest fix:** Add `.eq('company_id', activeCompanyId)` to both queries.

### [P2][CONFIRMED] property-tax snapshot "Account #" always blank — property-tax.html:1011
- **Problem:** It reads `propertyRow.tax_account_number ?? propertyRow.tax_account`. Neither column exists; the real ones are `tax_account_number_current` and `property_tax_account_number`. "Set as current" writes `tax_account_number_current`, which this line never reads.
- **Minor:** After a fresh insert, `editingId` is not set (line 1139, unlike property-insurance line 859), so "Set As Current" says "Load or save a record first".
- **Smallest fix:** Read `tax_account_number_current ?? property_tax_account_number`, and set `editingId` after the insert.

### [P2][CONFIRMED] hoa-form loads Supabase in `<head>` (CLAUDE.md hard rule) — hoa-form.html:7
- **Evidence:** `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>` sits inside `<head>`. hoa-form also has no `getSession()` fallback and no redirect when signed out (lines 268-283).
- **Smallest fix:** Move the script into `<body>` and adopt the reference auth bootstrap.

### [P2][CONFIRMED] Link to missing page — hoa-form.html:236
- **Evidence:** `<a href="help-center.html">Help Center</a>`; help-center.html does not exist. Other pages point "Help Center" at contact-us.html (expense-tracking.html:3051).
- **Smallest fix:** Point it at contact-us.html.

### [P2][CONFIRMED] `body { overflow-x: hidden }` missing on 10 of 12 pages
- **Evidence:** Only expense-tracking.html:1587 and reports-analytics.html:641 set it. add-expense, portfolio-financial-dashboard, all-properties-summary, maintenance-cost, property-finance, property-mortgage-activity, property-tax, property-insurance, hoa-info and hoa-form do not.
- **Related:** Tables use `min-width: 620-640px` inside scroll wrappers (maintenance-cost.html:338, portfolio-financial-dashboard.html:320) instead of collapsing to cards on mobile as the UI standard asks.
- **Smallest fix:** Add the body rule, and add card layouts at ≤600px for the record tables.

### [P3][CONFIRMED] Minor defects
- **all-properties-summary.html:930,935:** The grid/list toggle removes class `open` instead of `active`, so both buttons stay highlighted.
- **maintenance-cost.html:1013:** Vendor pie colours come from `COLORS.slice(0, labels.length)`, so vendors beyond the 10th get no colour.
- **maintenance-cost.html:914-917:** "Avg monthly" for "Last 30 days" divides by 2 months.
- **add-expense.html:786-791:** The Recent list filters by `property_name` only, with no company scope.
- **reports-analytics.html:1798-1802:** The portfolio branch of the rent, expense and maintenance reports is unreachable. `applyCurrentProperty` only loads reports when a property is selected (lines 2059-2066).
- **reports-analytics.html:1581-1582:** Today's fixed costs are applied flat to all 12 trend months.
- **portfolio-financial-dashboard.html:974-1023:** Two queries per property (N+1); it also ignores the `?property=` that reports-analytics passes (line 1340).
- **property-mortgage-activity.html:637-640:** The main `<script>` sits after `</body>`.
- **add-expense.html:503, 891:** A typed receipt URL goes into the preview `href` unchecked (self-only). Stored values are safe in expense-tracking because `rgFiles.resolve` passes through only http(s) URLs.
- **expense-tracking.html:2208:** `ensureAuthenticated` redirects to `login.html?redirect=` instead of `?returnTo=`. The function is never called.

## Notes

- **rg-snap categories match.** The 13 `EXPENSE_CATEGORIES` (supabase/functions/rg-snap/index.ts:25-39) equal add-expense `<option>`s 448-460 and expense-tracking `CATEGORIES` 2170-2184. The only stray value is "PMI", written by the mortgage split.
- **Column check:** Apart from the items above, every queried column exists: `hoa-info.unit_type`, `leases.monthly_rent`/`rent`, the CSV and maintenance field names, and the property-tax snapshot reads. Expenses correctly use `date_paid`. Finance history tables get `company_id` from the `trg_rg_sync_company` trigger, so pages that send a null `company_id` are fine. property_hoa and hoa_history get `property_id` from `rg_fill_property_id_from_name`.
- **No page in this group calls `rg_rent_schedule` or `rg_rent_status`.** Every rent figure is either raw `rent_log` sums (acceptable for "collected", once archived rows are excluded) or a JS recomputation of expected rent and balance (reports-analytics, not acceptable).
- **Overlap between the report pages:**
  - reports-analytics has a portfolio mode on its 12-month trend, an expense category donut and a rent report. That covers everything portfolio-financial-dashboard shows except its per-property table. **Recommendation:** add the per-property YTD table to reports-analytics (portfolio mode) and retire portfolio-financial-dashboard.
  - all-properties-summary duplicates property-management.html (property cards, occupancy, tenant) plus the portfolio table's rent/expense/net YTD. **Recommendation:** fold the YTD line into property-management cards and retire it, after asking (it is linked from several footers).
  - maintenance-cost is the expense report filtered to one category plus a vendor breakdown. It could be a preset or tab on expense-tracking or reports-analytics; it is low-risk to keep if fixed.
- **Positive patterns worth copying:** property-tax, property-insurance and hoa-info use `safeUrl()`, `escHtml()` and `textContent` correctly. expense-tracking escapes its table, archives instead of deleting, offers Undo and checks message origin. property-finance escapes its history rows.
- I did no browser or 390px screenshot testing. Mobile findings come from reading the CSS.
