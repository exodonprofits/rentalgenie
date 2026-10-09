# Detailed review: landlord core pages (dashboard, Lease & Rent Center, leases, properties)

Part of the 2026-10-09 pre-launch audit (see ../LAUNCH-READINESS.md). Produced by a read-only code review of each page against CLAUDE.md and the live schema. CONFIRMED = traced in code; SUSPECTED = needs a runtime check. Findings marked CONFIRMED were spot-checked by the lead reviewer where noted in ../FUNCTIONAL-AUDIT.md.

# Review B — Landlord core pages (pre-launch QA, read-only)

Scope: dashboard.html, lease-rent-center.html (LRC), add-payment.html, lease-form.html, view-lease.html, invite-tenant.html, property-management.html, add-property.html, property-overview.html.
Method: grep plus a full read of each query, render and save path; columns checked against schema.txt and migrations in `supabase/rentalgenie-project/migrations/`. I ran three read-only `information_schema`/`pg_trigger` queries on the live project (`xqmnaeujwumlcoyhgzuk`) to check NOT NULL columns and triggers. I parsed every inline script with `new Function()` and found 0 syntax errors on all 9 pages.

## Inventory

| Page | Purpose | Users | Reached from | Status (code-reviewed) | Value | Recommendation | Priority |
|---|---|---|---|---|---|---|---|
| dashboard.html | Landlord home: rent attention (rg_rent_status), KPIs, payment inbox, setup checklist, insights | Landlord | Login default, nav "Dashboard" | Partial | H | IMPROVE: delete the JS rent fallback, hide or finish the payment inbox, fix the checklist links | P1 |
| lease-rent-center.html | Per-property lease panel, rent ledger, attention queue, payments | Landlord | Nav "Lease & Rent", dashboard cards, property-management | Partial: ledger, Quick Peek and late fees are computed in JS | H | IMPROVE: move the ledger and Quick Peek onto rg_rent_schedule | P1 |
| add-payment.html | Add/edit a rent_log row | Landlord | LRC "➕ New Payment" drawer (iframe, embed=1), LRC edit buttons; no nav link | Working (with its own fourth due-date implementation) | M | MERGE with the LRC mark-paid modal into one payment form | P2 |
| lease-form.html | Create/edit/renew a lease, Snap It (rg-snap) | Landlord | LRC Create/Renew/Edit, view-lease edit/renew, dashboard checklist | Partial: LRC "Edit Lease" creates a duplicate lease; bare open cannot save | H | IMPROVE | P1 |
| view-lease.html | Read-only lease detail, lease history, tenant documents | Landlord | LRC "🔎 View Details" | Working (minor issues) | M | KEEP / IMPROVE | P2 |
| invite-tenant.html | Sends a Supabase magic link to a tenant email | Landlord | User menu, footer, LRC More menu, property-overview | Partial: sends the link only; name/phone are not saved; no check against the lease email | M | IMPROVE (or merge into LRC) | P2 |
| property-management.html | Property cards, company picker, KPIs, Genie tips | Landlord | Nav "Properties" | Partial: M2M/holdover properties show as "Vacant" | H | IMPROVE | P1 |
| add-property.html | Create/edit property with finance, PM and utility fields | Landlord | property-management add/edit, property-overview edit, dashboard checklist | **Broken for create** (owner_id NOT NULL never sent) | H | IMPROVE (fix now) | **P0** |
| property-overview.html | Single-property hero: lease, mortgage, net, tax, PM | Landlord | property-management "Overview", dashboard recent properties | Working (net cash flow uses any latest lease) | M | KEEP / IMPROVE | P2 |

Notable sub-features:

| Sub-feature | Where | Verdict |
|---|---|---|
| Rent attention via rg_rent_status | dashboard.html:3800, LRC:3217 | KEEP |
| In-page rent fallbacks | dashboard.html:3837-3935, LRC:3257-3383 | REMOVE |
| LRC ledger, Quick Peek and attention-bar late-fee math | LRC:2752-2963, 3912-3980, 4100-4140, 4213-4277 | IMPROVE (move to the DB) |
| Payment inbox card | dashboard.html:4211-4480 | INVESTIGATE: hide until `RG_PAYMENT_INBOX_BASE` is set |
| "Ask Rental Genie" hero box | dashboard.html:2899-2909, 3674-3705 | REMOVE or relabel (keyword router, not AI) |
| Floating Ask Genie widget | dashboard.html:4907-4950 (CSS hides it at 1528) | REMOVE (dead markup, no JS handlers) |
| Send for Signature | LRC:2276, 2461 (`SIGNING_ENABLED=false`), view-lease ignores `send=1` | Hidden correctly. KEEP hidden; remove until built |
| Convert to M2M | LRC:2843-2870 | IMPROVE (it wipes lease_end) |
| Snap It (lease) | lease-form.html:885-1030 | KEEP |
| Tenant documents on view-lease | view-lease.html:1049-1170 | KEEP (escaped, signed links) |
| LRC mark-paid modal vs add-payment drawer vs standalone add-payment vs payment inbox | several | MERGE: four ways to log a payment with different late-fee behaviour |

## Findings

### [P0][CONFIRMED] Adding a new property always fails: owner_id is NOT NULL and never sent — add-property.html:1509-1574
**Problem:** The insert payload built at add-property.html:1509-1561 has no `owner_id`, and adds `company_id` only when `?company_id=` is in the URL (`if (companyId) payload.company_id = companyId;` at 1562). On the live DB, `properties.owner_id` and `properties.company_id` are both `is_nullable = NO` with no default. The only triggers on `properties` are BEFORE UPDATE / AFTER UPDATE (`trg_auto_unpublish_listing`, `trg_rg_cascade_property_rename`), so nothing fills them on INSERT. `safeUpsertProperty()` (1311) sends the payload as-is and then shows the error.
**Why it matters:** Step 1 of onboarding ("Add your first property", dashboard.html:4463) cannot succeed, and without a property no lease or payment can be created. This blocks launch.
**Evidence:** Live `information_schema.columns`: `owner_id NO null`, `company_id NO null`. The `pg_trigger` query lists no BEFORE INSERT trigger on properties. `grep owner_id add-property.html` returns nothing.
**Smallest fix:** In the submit handler, set `payload.owner_id = user.id` (from `setupAuth()`), and resolve `company_id` when the URL has none (company_members, then companies.owner_user_id, as dashboard.html:3740-3753 does). Better: add a BEFORE INSERT trigger that defaults `owner_id := auth.uid()`. Test with a rolled-back insert as `authenticated`.

### [P1][CONFIRMED] Dashboard checklist "Add a lease and tenant" opens a lease form that cannot save — dashboard.html:4465, lease-form.html:867-870, 1415-1418
**Problem:** The checklist links to bare `lease-form.html`. lease-form takes property and company only from URL params and has no property picker (only a read-only `propPill`, 506-507). The payload then has `company_id: null, property_id: null, property_name: null`. Live: `leases.property_id` and `leases.company_id` are NOT NULL, and `leases_insert_own` requires `rg_company_access(company_id)`.
**Why it matters:** A new landlord following the checklist fills in the whole form and gets "Save failed".
**Evidence:** `href: "lease-form.html"` (dashboard 4465); `company_id: companyId || null, property_id: propertyId || null` (lease-form 1416-1417).
**Smallest fix:** Point the checklist at `lease-rent-center.html`, or add a property `<select>` to lease-form when no property param is present.

### [P1][CONFIRMED] LRC "✏️ Edit Lease" opens lease-form in create mode, so saving inserts a duplicate lease — lease-rent-center.html:3582, lease-form.html:871-876
**Problem:** LRC wires Edit to `lease-form.html?${q}&edit=1` with no `lease_id`. lease-form sets `isEdit = !!leaseId && !isRenew`, so the page is in create mode with an empty form, and Save runs `.insert()` (1493).
**Why it matters:** The landlord thinks they are editing. Instead a second lease row appears. The newest `lease_start` then wins in rg_rent_schedule and in every page's "latest lease", so rent figures change silently.
**Evidence:** `wireBtn(edit, \`lease-form.html?${q}&edit=1\`...)`; `var leaseId = _p.get('lease_id') || _p.get('id') || ''; ... var isEdit = !!leaseId && !isRenew;`
**Smallest fix:** In `setLeaseActionLinks()`, append `&lease_id=` + `getLedgerLease().id` (and the same for renew), or have lease-form treat `edit=1` as edit and call `loadLatestLeaseForProperty()`.

### [P1][CONFIRMED] Rent is still computed in JavaScript in four places in LRC, and the results disagree with rg_rent_status — lease-rent-center.html:2752-2963, 3912-3980, 4100-4140, 4213-4277
**Problem:** Only the attention queue uses `rg_rent_status`. The per-property ledger, Quick Peek balance and the attention-bar chips all rebuild due dates (`buildMonthlyDueDates`), late status (`computeStatusForDue`) and balances (`computeLateFeeForRow`) in the page. CLAUDE.md forbids this. Concrete differences from `rg_rent_schedule` (migrations rg_02_functions.sql):
1. **Late fees are added to balances in the page only.** Ledger: `const totalDue = rent + lateFeeDue; const balance = Math.max(0, totalDue - paidTotal);` (4233-4234). The DB balance is `greatest(rent_amount - paid, 0)` with no fees. A tenant who paid rent in full but late shows a balance on the ledger and $0 on the dashboard.
2. **Quick Peek "Balance" includes future months.** `if (bal > 0) totalBalance += bal;` (3936) runs over every due date to `lease_end` with no `<= today` check. An active 12-month lease shows months of future rent as owed.
3. **Holdover payments are hidden.** `paymentBelongsToLease()` (2879-2891) drops any payment whose `applied_to_due_date > lease_end`. `buildMonthlyDueDates()` still generates holdover months up to today (2782-2789). Every paid holdover month therefore shows Unpaid/Late plus a late fee. The DB counts those payments.
4. Late-fee waivers depend on the note text "late fee waived" (4221, 4111). Editing the note brings the fee back.

**Why it matters:** The dashboard and the LRC attention list (DB) disagree with the LRC ledger and Quick Peek (JS) for the same property. This is exactly the class of bug the DB functions were built to remove.
**Evidence:** quoted above. The dashboard uses DB rows (dashboard.html:3954-4000).
**Smallest fix:** Render ledger rows from `rg_rent_schedule(company_id, as_of)` filtered by `property_id`. Take Quick Peek's balance and next due date from `rg_rent_status`. If late fees are a product feature, add them to the DB function. Delete `computeLateFeeForRow`, `computeStatusForDue` and the JS due-date builder.

### [P1][CONFIRMED] In-page rent fallbacks are still shipped on dashboard and LRC — dashboard.html:3837-3935, lease-rent-center.html:3257-3383
**Problem:** Both pages keep the legacy calculation and use it whenever the RPC errors. The fallbacks cover only the current month and pick the "latest" lease with no status, termination or archive filter. The LRC fallback also checks `r.is_late_fee`, a column that does not exist (it isn't selected, so this is dead logic).
**Why it matters:** A transient RPC failure silently shows different overdue numbers instead of an error. This is the "three implementations" problem kept alive.
**Evidence:** `if (rentStatusErr) console.warn("Rent status: falling back to in-page calculation", ...)` (dashboard 3818); `if(r.is_late_fee === true) return;` (LRC 3312).
**Smallest fix:** Delete both fallbacks and show "Couldn't load rent status. Retry."

### [P1][CONFIRMED] Fourth due-date implementation in add-payment, which ignores terminated leases — add-payment.html:742-771, 841-846
**Problem:** add-payment has its own `buildMonthlyDueDates()`. It has no `terminated_date`/`terminated` handling, so it offers due dates after a lease ended. It parses `new Date(lease.lease_start)` as UTC, unlike LRC's `parseISODateOnly`. The lease query filters by `property_name` only, with no `company_id`. `guessAppliedDueDate()` picks the due date for the payment.
**Why it matters:** A payment can be applied to a month the DB never charges (after termination), so it silently does not count.
**Smallest fix:** Populate the due-date dropdown from `rg_rent_schedule` rows for the property.

### [P1][CONFIRMED] Draft leases are charged rent; "Terminated" without a date keeps charging to lease_end; no UI sets terminated_date — rg_rent_schedule (rg_02_functions.sql) via dashboard/LRC; lease-form.html:551-557
**Problem:** `rg_rent_schedule.lease_pick` has no status filter, so a `draft` lease with a past `lease_start` becomes the property's lease and accrues rent. That differs from `rg_sync_property_status`, which excludes `draft`. No page writes `terminated_date` (grep across all `*.html` finds none). lease-form only offers status "Terminated", and the DB then charges until `least(lease_end, as_of)`, not the real move-out date.
**Why it matters:** Ending a lease early, which is what the `ended` state exists for, keeps billing to the original end date. Draft leases created ahead of time inflate overdue totals.
**Smallest fix:** Add a "Termination date" field to lease-form, shown when status = terminated, and save `terminated_date`. Exclude `status = 'draft'` in `rg_rent_schedule` (db: migration).

### [P1][CONFIRMED] property-management shows month-to-month and holdover properties as "Vacant / ➕ Add Lease" — property-management.html:2329-2336
**Problem:** "Active lease" requires status in `["signed","active","current","renewed"]` and `lease_end >= today`. `month_to_month`/`holdover` statuses and M2M leases with `lease_end = null` never match. The card then shows tenant "Vacant", the "➕ Add Lease" CTA, and the Genie warning "tenant-occupied property(s) don't show an active signed lease" (2098).
**Why it matters:** The core property list is wrong for any tenant past the initial term. That is exactly what LRC's "Convert to M2M" produces.
**Smallest fix:** Use `rg_rent_status` (`lease_state <> 'ended'`), or match the DB's lease_state rules.

### [P1][CONFIRMED] Payment inbox is shown to every landlord but cannot work (no inbound address) — dashboard.html:4207, 4268-4275, 4398-4404
**Problem:** `var RG_PAYMENT_INBOX_BASE = "";`, so `_forwardingAddress()` returns "" and setup shows "Not connected yet". The card is still always shown (`card.classList.add("show")`) and says "Forward your Zelle and Venmo payment alerts here and rent logs itself." The setup panel auto-opens for new users (4434).
**Why it matters:** A headline feature on the home screen that cannot be used, shown at launch.
**Smallest fix:** Don't add `.show` while `RG_PAYMENT_INBOX_BASE` is empty, or set the real Postmark address.

### [P2][CONFIRMED] Payment inbox verification URL is placed in href without safeUrl — dashboard.html:4409-4414
**Problem:** `a.href = _payInbox.verifyUrl;` (with `target="_blank"`). The value is `companies.payment_inbox_verify_url`, written by `rg_store_inbox_verification(p_inbox_token, p_url)` from an inbound email with no scheme check. Anyone who knows the forwarding address can send that email.
**Why it matters:** A `javascript:` URL would run in the landlord's session. CLAUDE.md requires `safeUrl()` (http/https only). It is only exploitable once the inbox is live and if n8n passes the URL through unvalidated (SUSPECTED for the n8n side).
**Smallest fix:** Allow only `https:` and Google hosts before assigning `href`, and validate in the DB function as well.

### [P2][CONFIRMED] Unescaped DB strings in dashboard innerHTML — dashboard.html:3430, 3640, 4692, 4694
**Problem:**
- 3430: `const metaHtml = it.meta ? \`<div class="meta">${it.meta}</div>\`` puts vacant property names (`_vMeta`, 4076) into the HTML raw.
- 3640: `` `<li>...<span>${f}</span></li>` `` puts raw `facts`, which contain lease `tenant_name` and property names (3529-3533, 3581).
- 4692: `<div class="prop-name">${prop.name || "N/A"}</div>` is raw.
- 4694: `onclick="window.location.href='${_href}'"`, where `_href` uses `encodeURIComponent(prop.name)`. encodeURIComponent does not encode `'`, so a property name containing `'` breaks out into JavaScript.

**Why it matters:** Stored XSS from any company member's property or tenant name. tenant_name can also come from Snap It's LLM extraction of an uploaded PDF. It breaks the CLAUDE.md escaping rule.
**Smallest fix:** Pass `meta` and `facts` through `escapeGenieText`, escape `prop.name`, and replace the inline `onclick` with an `<a href>` built via createElement.

### [P2][CONFIRMED] Unescaped tenant name and payment method in LRC ledger and payments modal — lease-rent-center.html:4266, 4270, 4399
**Problem:** `<td>${tenant}</td>` (lease tenant_name) and `<td>${methodLabel}</td>` in the ledger; `<td>${r.method || "—"}</td>` in the payments list. `rent_log.method` is copied from `incoming_rent_payments.method` (from the email parser) by `rg_confirm_incoming_payment`. The note is escaped (4400); these cells are not.
**Smallest fix:** `escapeHtml()` both, which already exists at 2626.

### [P2][CONFIRMED] LRC hard-deletes rent_log and view-lease hard-deletes leases — lease-rent-center.html:4333, 4362, 4433; view-lease.html:1386
**Problem:** `client.from("rent_log").delete()` and `client.from('leases').delete()` run, even though `archive_rent_log` / `archive_lease` RPCs exist (rg_02_functions.sql). The lease delete leaves its `rent_log` rows orphaned (lease_id dangling). Deleting an email-confirmed payment leaves `incoming_rent_payments.rent_log_ids` pointing at nothing. Nothing can be undone.
**Smallest fix:** Call the archive RPCs and filter `archived_at is null` in reads (see next finding).

### [P2][CONFIRMED] Pages don't filter archived rows that rg_rent_schedule excludes — dashboard.html:3756-3778, LRC:3476-3500, 3813-3818, add-payment 841, property-management 2301-2358
**Problem:** The DB function ignores `archived_at is not null` for properties, leases and rent_log. These pages query the same tables with no `archived_at` filter (only dashboard expenses has one). Archiving is not yet called from these pages, so the issue is latent. Once archive is used (see above), counts, the lease picker and the property list will diverge from the DB.
**Smallest fix:** Add `.is("archived_at", null)` to these queries, or query the `active_*` views.

### [P2][CONFIRMED] "Convert to M2M" erases the original lease_end — lease-rent-center.html:2856-2860
**Problem:** `update({ lease_type:'month_to_month', status:'month_to_month', lease_end:null })` overwrites the end date. The history loses when the fixed term ended. `paymentBelongsToLease` then returns true for all payments, so the ledger changes shape.
**Smallest fix:** Keep `lease_end` (the DB already treats `lease_type like '%month%'` as M2M).

### [P2][CONFIRMED] Vacancy uses the manual occupancy_status; the lease trigger maintains a different column — dashboard.html:4020-4026, property-management.html:1970-2052; rg_02_functions.sql `rg_sync_property_status`
**Problem:** Lease insert/update/delete triggers update `properties.status` (occupied/vacant). Every page reads and writes `occupancy_status`, which only the add-property form sets. Signing or ending a lease never changes dashboard vacancy counts or `auto_unpublish_listing`, which also keys on `occupancy_status`.
**Smallest fix:** Settle on one column. Either have the trigger set `occupancy_status`, or read `status`.

### [P2][CONFIRMED] Two different localStorage keys for the active company; stale IDs are trusted — property-management.html:2280-2283 vs dashboard.html:3740, LRC:2483-2492
**Problem:** property-management stores `rentalgenie_company_id`; the other pages use `rg_active_company_id`. Switching company on Properties doesn't carry over. Dashboard trusts a cached `rg_active_company_id` without checking membership. LRC writes any UUID from `?company_id=` into storage (2483-2485). Sign-out doesn't clear it (dashboard 3237, 5013). Another account on the same browser, or a crafted link, then gets an all-zero dashboard.
**Smallest fix:** Use one key, verify it against company_members on boot, and clear it on sign-out.

### [P2][CONFIRMED] Dashboard setup checklist and insight links pass params the target ignores — dashboard.html:4467, 4078, 3588
**Problem:** `lease-rent-center.html?action=log`: LRC never reads `action`. `property-management.html?filter=vacant`: property-management never reads URL params, so the list is unfiltered.
**Smallest fix:** Implement both params, or drop them.

### [P2][CONFIRMED] Four separate ways to record a payment, with different rules — LRC ledger "➕ Add Payment" modal (4608-4660), LRC "➕ New Payment" drawer (4674-4686) loading add-payment.html, standalone add-payment.html, dashboard payment inbox
**Problem:** The modal applies late-fee logic and adds a "Late fee waived" note marker. add-payment has neither and uses a different due-date list. The inbox uses `rg_confirm_incoming_payment` (oldest-first). The same action gives different ledger results depending on which button was used.
**Smallest fix:** Keep one form (the modal, using DB due dates) plus the inbox, and make add-payment the edit view of the same form.

### [P2][CONFIRMED] view-lease shows legacy late-fee and grace columns before the ones lease-form saves — view-lease.html:1225-1229
**Problem:** `L.late_fee_amount ?? L.late_fee` and `L.late_fee_grace_days ?? L.grace_period`. lease-form writes `late_fee`/`grace_period` (1411-1412), and LRC prefers those (2815-2820, 2927-2930). View-lease can show stale values. Status labels for `month_to_month`/`holdover` render as "Month_to_month" with the draft style (962-966). property-overview has the same issue (1221-1236).
**Smallest fix:** Prefer `late_fee`/`grace_period`, and map the M2M and holdover labels.

### [P2][CONFIRMED] invite-tenant saves nothing and doesn't check the email against the lease — invite-tenant.html:628-651
**Problem:** Only `signInWithOtp({email})` is called. The edited name and phone are discarded. If the landlord types an email different from `leases.tenant_email`, the tenant signs in and sees an empty portal, because access is by lease email. No `tenants` row and no `lease.tenant_id` link is created.
**Smallest fix:** Warn when the email doesn't match the selected lease, or update `leases.tenant_email` after confirming.

### [P2][CONFIRMED] property-overview net cash flow uses any latest lease, including draft or terminated — property-overview.html:1206-1216, 1275-1290
**Problem:** `fetchLatestLease` takes the newest `lease_start` regardless of status. "Net" is computed as `rent - mortgage`, even for ended leases. "Invite Tenant" alerts "Add a lease first" when there's no email, although invite-tenant supports link-only (1112).
**Smallest fix:** Use `rg_rent_status` for the property (`lease_state <> 'ended'`).

### [P2][CONFIRMED] Dashboard "Ask Rental Genie" is a keyword router presented as AI; floating widget is dead — dashboard.html:2899-2909, 3674-3705, 4907-4950, 1528-1531
**Problem:** The placeholder suggests "Who is late this month?", but `routeAsk()` only redirects on keywords (e.g. "rent" goes to lease-rent-center). The floating `#askGenieFloat`/`#geniePanel` has no JS handlers for `genieSend` and is `display:none !important`.
**Smallest fix:** Relabel it "Jump to…" or wire it to `rental-genie-ai-proxy`. Delete the dead widget.

### [P2][CONFIRMED] CLAUDE.md UI rule violations
- **`body { overflow-x: hidden }` missing:** add-payment, lease-form, view-lease, invite-tenant, add-property, property-overview (grep for `overflow-x` finds 0 matches on each).
- **Full-screen auth overlay instead of the 3px shimmer:** view-lease.html:59-65 (`inset:0; background: var(--bg)`), property-overview.html:64-70, invite-tenant.html:28. The other pages use the 3px bar.
- **Nav not canonical (six labels):** add-payment, lease-form, invite-tenant and add-property add a seventh "💬 Messages" link. No page in scope uses `withProp()`. lease-form and view-lease drawers lack the two-column `drawer-grid`.
- **Internal page opened in a new tab:** LRC:4756 `window.open(fullUrl, "_blank")` opens add-payment.html ("open in new" from the drawer), which breaks the iOS home-screen app.
- **Raw localStorage outside safeStorage/try:** dashboard.html:3740/3753/4222, LRC:2485/2490, property-management 2280-2283. If storage is blocked these throw, and the dashboard then shows "Error loading data."

### [P2][CONFIRMED] LRC rent ledger is an 11-column table with no mobile card layout — lease-rent-center.html:435, 2415-2416
**Problem:** The table only has `.rent-table-container { overflow-x:auto }`. No `@media` rule turns it into cards, as CLAUDE.md's UI standards require. On a ~390px phone this means sideways scrolling through 11 columns with action buttons in the last one.
**Smallest fix:** Use stacked cards below 640px (`td::before { content: attr(data-label) }`).

### [P3][CONFIRMED] Smaller issues
- LRC:2701 and add-payment:888 call `decodeURIComponent(params.get(...))` on a value that is already decoded. It throws a URIError for property names containing `%`.
- view-lease:1408 sends `returnTo=` with an absolute URL. login.html rejects anything containing `://`, so after login the user lands on the dashboard instead of the lease.
- add-property:1593 and property-overview redirect to `login.html` with no `returnTo`.
- LRC postMessage listener (4761) has no origin check. Impact is limited to a refresh or closing the drawer.
- view-lease:1103 deletes the tenant_documents row but not the storage object.
- view-lease:1152 stores `getPublicUrl()` for a private bucket in `file_url`. Harmless, because `file_path` is used first.
- dashboard.html ends with a duplicate `</body></html>` (5084-5087).
- lease-form:1224 picks the "latest" lease by `lease_end desc`; every other page uses `lease_start desc`.
- No page in scope can archive or remove a property (`properties_no_delete` policy, no archive UI).

## Notes
- Column check: every `.from()` select/insert/update/filter/order column on the 9 pages exists in schema.txt. The only references to non-existent columns are fallbacks read off `select('*')` results: `is_late_fee` (LRC:3312, not selected), `unit_type` (property-overview:1255), `monthly_rent` (LRC:4200). None of them makes a query fail.
- Supabase client is loaded in `<body>` on all 9 pages. No service-role key and no `cdn-cgi` links were found.
- Outside my scope but found while checking redirects (CONFIRMED): login.html:556 accepts `returnTo=//evil.com` (`raw.startsWith('/')`), which is an open redirect.
- `leases_select_tenant_self` lets tenants read their whole lease row, including `pay_ach_account_number`. This is probably intended (payment instructions), but worth confirming.
- I made no changes to the repo. The live DB was used only for three read-only catalog queries.
