# Detailed review: tenant portal pages

Part of the 2026-10-09 pre-launch audit (see ../LAUNCH-READINESS.md). Produced by a read-only code review of each page against CLAUDE.md and the live schema. CONFIRMED = traced in code; SUSPECTED = needs a runtime check. Findings marked CONFIRMED were spot-checked by the lead reviewer where noted in ../FUNCTIONAL-AUDIT.md.

# Review E: Tenant portal (7 pages)

Scope: tenant-portal.html, tenant-lease.html, tenant-payments.html, tenant-repair-requests.html, tenant-documents.html, tenant-contact.html, tenant-account.html. This was a read-only review. I checked the code against the live schema (`schema.txt`), the RLS policies and functions in `supabase/rentalgenie-project/migrations/`, and a few aggregate read-only SELECTs on the live project `xqmnaeujwumlcoyhgzuk` (counts only, no row data). I also looked at the existing harness screenshots (`shots/*-390.png`). `node --check` passes on every inline script in all 7 pages.

## Inventory

| Page | Purpose | Users | Reached from | Status (code-reviewed) | Value | Recommendation | Priority |
|---|---|---|---|---|---|---|---|
| tenant-portal.html | Tenant home: rent, paid this month, lease status, quick actions, open repairs | Tenants | tenant-login.html (redirect, adds `?property=` of newest lease), invite-tenant links, brand logo on every tenant page, landlord footers/menus (index, lease-form, hoa-info, reports, add-maintenance-request) | **Partial**. The repairs snapshot query uses 3 columns that don't exist. Rent and paid figures are computed in JS and miss payments with no tenant link. | H | IMPROVE | P1 |
| tenant-lease.html | Current lease hero, timeline, terms, late-fee policy, lease history, "Request renewal" (prefills contact) | Tenants | Tenant nav, portal "View Full Lease" | **Working**, but breaks a CLAUDE.md rule (Supabase in `<head>`, no `_rgClient` guard) | M | IMPROVE (move client to body). Some overlap with the portal's Lease Details card. | P2 |
| tenant-payments.html | Payment history, paid this month and last 12 months, status banner, how to pay (lease or company instructions), preferred method picker | Tenants | Tenant nav, portal quick action | **Partial**. History filters by `tenant_id` only. 26 of 118 live rent_log rows have no tenant_id and no tenant_email, so tenants can't see them. Status/past-due is computed in JS. | H | IMPROVE | P0 |
| tenant-repair-requests.html | Submit a maintenance request (urgency, up to 6 photos), list requests, request reimbursement with receipt | Tenants | Tenant nav, portal quick action, contact "Report an Issue" | **Working**. Insert sends lease company_id and property_id; photo and receipt paths match the storage policies. Mobile has problems (tables, nav). | H | KEEP + mobile fixes | P2 |
| tenant-documents.html | List shared documents; open through signed URLs (rgFiles) | Tenants | Tenant nav, portal quick action | **Working**. Filtering by `tenant_id` only hides docs saved without tenant_id (lease-form snap). | M | KEEP + fix filter | P2 |
| tenant-contact.html | Send a message to the landlord (templates), see message history including landlord replies | Tenants | Tenant nav, portal quick action, lease "Request Renewal" | **Working**. Insert sends lease company_id (property_id is filled by trigger). History truncates at 200 characters with no way to expand. | H | KEEP. This is the tenant's only messaging page; tenant-messages.html is the landlord inbox, so the two don't overlap. | P2 |
| tenant-account.html | Update phone; change login email; read-only name and property | Tenants | User menu "My Account", drawer "My Account" | **Partial**. A tenant row not yet linked to its login (live: 2 of 8 tenants) gets "Phone number saved" when nothing was saved. The email change can cut a tenant off from their own data. | M | IMPROVE / INVESTIGATE email change | P1 |

## Findings

### [P0][CONFIRMED] Tenants can't see rent payments that landlords record; Payments and Portal show $0 paid and "may be past due"
Files: tenant-payments.html:1081-1085, tenant-portal.html:929-932. The cause is the writers: add-payment.html:1012-1021, lease-rent-center.html:4642-4651, and `rg_confirm_incoming_payment` (rg_02_functions.sql:291-341).

- **Problem:** The three paths that write rent_log never set `tenant_id`, `tenant_email` or `lease_id`.
  - add-payment's `entry` has `company_id, property_name, tenant_name, amount, date_paid, method, note, applied_to_due_date`.
  - lease-rent-center's insert has the same columns.
  - The RPC inserts `(company_id, property_id, property_name, tenant_name, amount, date_paid, method, applied_to_due_date, note, source, incoming_payment_id)`.
  - The only rent_log triggers are `trg_rent_log_company` and `trg_rent_log_owner_property`, which fill company/property/owner and nothing about the tenant. (Checked in pg_trigger on the live DB.)
- **Why the tenant sees nothing:** RLS `rent_log_select_tenant_self` lets a tenant read only `lower(tenant_email) = rg_auth_email() OR tenant_id = rg_tenant_id_for_auth_user()`. On top of that, tenant-payments Strategy 0 filters `.eq('tenant_id', tenant.id)` whenever a tenant row resolves.
- **Live evidence:** 26 of 118 rent_log rows have both `tenant_id` and `tenant_email` null (newest 2026-09-25). No tenant can see these rows.
- **Why it matters:** A paying tenant sees "Paid This Month $0.00", an empty history, and "Payment may be past due … please contact your landlord" (tenant-payments.html:972-975; portal attention at tenant-portal.html:1048-1049). This is the most visible tenant-facing number at launch.
- **Evidence:** `sb.from('rent_log').select(baseSelect).order('date_paid', { ascending: false }).eq('tenant_id', tenant.id)` (tenant-payments.html:1083).
- **Smallest fix:** Add a DB BEFORE INSERT/UPDATE trigger on rent_log. It sets `lease_id`, `tenant_id` and `tenant_email` from the active lease for `(property_id, date_paid)` when they're null. Backfill the 26 rows in a rolled-back test first, then for real. In the pages, filter `tenant_id.eq.X,tenant_email.ilike.Y` with `.or(...)` instead of tenant_id alone.

### [P1][CONFIRMED] The portal's "Open Repair Requests" card never shows: the query uses columns that don't exist — tenant-portal.html:1065-1072
- **Problem:** `maintenance_requests` has no `issue_summary`, `date_submitted` or `inserted_at`. The live schema has `issue_description` and `created_at`.
- **Why it matters:** PostgREST returns 42703. The `.catch` hides the card (line 1101-1103), so tenants never see their open repairs on the home page. Separately, the open filter only treats statuses containing "complete" as closed (line 1078, 1092). The only live status is "Resolved", so once the query is fixed, resolved requests would show as open.
- **Evidence:** `.select('id, property_name, issue_summary, status, date_submitted, inserted_at') … .order('date_submitted', …)`
- **Smallest fix:** Select `id, property_name, issue_description, status, created_at` and order by `created_at`. Render `issue_description`. Treat `resolv|complet|done|closed` as closed, matching tenant-repair-requests.html:1050 `statusChip`.

### [P1][CONFIRMED] Rent due date, "paid this month" and past-due status are recomputed in JS, against CLAUDE.md — tenant-portal.html:819-826, 950-957, 975-980, 1045-1050; tenant-payments.html:697-702, 959-982, 1171-1177
- **Problem:** `computeNextDueDate` clamps the due day to 28. "Paid this month" sums rows by the calendar month of `date_paid`, ignoring `applied_to_due_date`. Prior arrears, partial carry-over and late fees are never shown. The lease status shown is raw `leases.status`.
- **Why it matters:** CLAUDE.md says pages must not recompute balances, due dates or late status. These figures will disagree with what the landlord sees from `rg_rent_schedule`. Example: a payment on the 30th applied to next month makes the tenant look paid up now and past due next month.
- **Note:** Tenants can't simply call the existing functions. `rg_rent_schedule` is SECURITY INVOKER and joins `properties`, and tenants have no SELECT policy on properties (only `properties_owner_*` and `properties_rw_company_member`). It would return no rows for a tenant.
- **Evidence:** `var dd = Math.min(Math.max(parseInt(dueDay || '1', 10) || 1, 1), 28);`
- **Smallest fix:** Add a tenant-scoped SECURITY DEFINER RPC, e.g. `rg_tenant_rent_schedule(as_of)`. It wraps `rg_rent_schedule` and keeps only leases where `tenant_email = rg_auth_email() OR tenant_id = rg_tenant_id_for_auth_user()`. Both pages then show the next due date, balance and status from it.

### [P1][CONFIRMED] On 6 of 7 pages the user chip appears on phones and pushes the hamburger (the only mobile nav) off screen — tenant-portal.html:173/899, tenant-lease.html:166/919, tenant-repair-requests.html:182/1264, tenant-documents.html:172/825, tenant-contact.html:172/841, tenant-account.html:168/509
- **Problem:** The CSS hides `.umd-wrap` under 880px, but boot sets `chip.style.display = 'flex'` inline, and the inline style wins. tenant-payments.html:166 already has the fix (`.umd-wrap { display: none !important; } /* boot sets display:flex inline */`). The other six pages don't.
- **Why it matters:** The tenant portal is mostly used on phones. In `shots/tenant-repair-requests-390.png` the header runs past 390px and the hamburger sits off screen; the bell is also forced visible. In `shots/tenant-portal-390.png` the hamburger is clipped at the right edge.
- **Smallest fix:** Copy the `!important` rule from tenant-payments.html:166 into the 880px media query on the other six pages. Also add `.nav-bell { display:none !important }` on the repairs page.

### [P1][CONFIRMED] Unlinked tenants get "Phone number saved" when nothing was saved; the self-healing link never runs — tenant-account.html:550-558, and every page's `resolveTenant`
- **Problem:** `tenants_update_self` is `USING (auth_user_id = auth.uid())`. For a tenant row with `auth_user_id IS NULL` (live: 2 of 8 tenants), these updates match 0 rows and return no error:
  - `update({ phone })` on tenant-account
  - `update({ auth_user_id: user.id })` in every page's resolveTenant (e.g. tenant-portal.html:877-879)

  The page reports success. The comment "self-heal the link so future lookups use the fast path" (tenant-portal.html:864-868) never comes true.
- **Second problem:** `update({ email: user.email })` (e.g. tenant-portal.html:873) always fails. `trg_block_tenant_email_change` raises "Tenant email cannot be changed", and `rg_tenants_limit_self_update` allows only phone. The error is swallowed. It retries on every page load whenever the stored email's case differs from the auth email.
- **Why it matters:** The tenant thinks the landlord has their new phone number. Unlinked tenants stay unlinked forever and depend on the email-match fallback.
- **Smallest fix:** Add a SECURITY DEFINER RPC `rg_claim_tenant_row()` that sets `auth_user_id = auth.uid()` where `auth_user_id IS NULL AND lower(email) = rg_auth_email()`. Call it once at login. In tenant-account, use `.update(...).select('id')` and treat an empty result as failure. Remove the client-side `email` and `auth_user_id` updates.

### [P1][SUSPECTED] "Change login email" on My Account can cut a tenant off from their own data — tenant-account.html:563-591
- **Problem:** `sb.auth.updateUser({ email })` changes the auth email. But `tenants.email` can't change (the trigger above), and `leases.tenant_email`, `rent_log.tenant_email`, `maintenance_requests.tenant_email` and `tenant_documents.tenant_email` keep the old address.
  - Tenant select policies match `tenant_email = rg_auth_email() OR tenant_id = rg_tenant_id_for_auth_user()`.
  - An unlinked tenant (auth_user_id null) loses all access after the change, since `tenants_select_self` also needs the email to match.
  - A linked tenant keeps only the rows that carry a tenant_id. That excludes the 26 unlinked rent rows from the first finding.
  - The page promises "this page will show your new email automatically the next time you log in."
- **Why it matters:** Tenants lock themselves out of their history with no error. Landlord-side `tenants_rw_company_member_via_leases` also matches by email, so landlords may lose track of the tenant row.
- **Smallest fix:** Hide the email-change card until identity is fully id-based, or replace it with "Ask your landlord to update your email." Verify with a rolled-back test using `SET LOCAL ROLE authenticated` and changed jwt claims.

### [P2][CONFIRMED] tenant-lease.html loads Supabase in `<head>` and creates its own client without the `_rgClient` guard — tenant-lease.html:12, 690-693
- **Problem:** `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>` sits inside `<head>`. Later the page runs `var sb = window.supabase.createClient(` without the `window._rgClient ||` reuse guard that every other tenant page has.
- **Why it matters:** This is the CLAUDE.md hard rule. Loading in `<head>` triggers tracking prevention, which gives empty sessions, so the tenant is redirected to login (line 928) even when signed in.
- **Smallest fix:** Move the script tag to the start of `<body>`, as tenant-payments.html:464 does, and use `window._rgClient || …`.

### [P2][CONFIRMED] Documents, repairs and messages filter by `tenant_id` only when a tenant row resolves, hiding rows the landlord saved by email — tenant-documents.html:795-797, tenant-repair-requests.html:1111-1113 and 1119-1121, tenant-contact.html:727-729
- **Problem:** Only one branch ever runs: `tenant ? .eq('tenant_id', tenant.id) : .eq('tenant_email', user.email)`. Several landlord writers don't set tenant_id:
  - lease-form.html:1015-1024 (snapped lease PDF into tenant_documents)
  - add-maintenance-request.html:617 (payload has no tenant_id; live: 1 of 6 maintenance rows has no tenant_id)

  RLS would allow these rows by email, but the page filter excludes them.
- **Why it matters:** The "Signed lease" PDF the landlord files from lease-form never shows on the tenant's Documents page.
- **Smallest fix:** Use `.or('tenant_id.eq.'+id+',tenant_email.ilike.'+email)`, or set tenant_id in a DB trigger from tenant_email.

### [P2][CONFIRMED] On three pages the `?property=` context and active state are wired to element IDs that don't exist — tenant-repair-requests.html:977-981, tenant-documents.html:716-720, tenant-contact.html:671-675
- **Problem:** These pages update `navBell`, `mHome`, `mLease`, `mPayments`, `mRepairs`, `mDocs` and `mContact`. The drawer actually uses `drawerHome…drawerContact`, and on repairs the contact link is `navContact` (repairs maps `navBell` instead). On a phone, the drawer links drop `?property=`, so a multi-property tenant jumps back to the newest lease's property.
- **Wrong active states:**
  - Repairs drawer marks Home active (line 667: `drawerHome … class="nav-active"`) and not Repairs.
  - Documents (604, 608) and Contact (555, 560) drawers mark two items active.
- **Account page:** It has no withProp at all, and portal/lease/payments never add withProp to `drawerAccount`. Visiting My Account always loses the property context.
- **Smallest fix:** Use the `applyNavContext` ID list from tenant-portal.html:758-778 on all pages, fix the `nav-active` classes, and include `drawerAccount`.

### [P2][CONFIRMED] Repair and document tables don't collapse to cards on phones; the reimbursement button is off screen — tenant-repair-requests.html:771-797 and 800-818, tenant-documents.html:661-668, tenant-lease.html:361 (`min-width:480px`)
- **Problem:** 6-column and 5-column tables inside `overflow-x:auto` wrappers. In `shots/tenant-repair-requests-390.png` the Urgency/Status/Reimbursement columns are cut off ("UR…"). The "💰 Request" button is also under the 28px tap-target size (harness smallTaps).
- **Also:** The repairs hero-stats grid has an inline `style="grid-template-columns:repeat(3,1fr)"` (line 700). It overrides the 720px/480px media queries, so the stats never stack.
- **Why it matters:** CLAUDE.md says grids of records collapse to cards on mobile. Only tenant-payments has mobile cards (376-379, 639).
- **Smallest fix:** Add the `.mobile-cards` pattern from tenant-payments to repairs, reimbursements and documents, and remove the inline grid override.

### [P2][CONFIRMED] Contact history cuts messages, including landlord replies, at 200 characters with no way to read the rest — tenant-contact.html:725
- **Evidence:** `${safe(m.message||m.body||'').slice(0,200)}${(...).length>200?'…':''}`. The `.slice` runs after escaping, so it can also cut an entity in half (`&am…`). The "Messages Sent" count (line 731) includes landlord messages.
- **Why it matters:** A tenant can't read a long reply from the landlord anywhere in the portal.
- **Smallest fix:** Render the full text with `textContent` and `white-space:pre-wrap`, or add a click-to-expand. Count only `sender !== 'landlord'`.

### [P2][CONFIRMED] Reimbursement insert policy doesn't check that the tenant leases from the target company — rg_03_constraints_views_policies.sql:404-405 (used by tenant-repair-requests.html:1216-1228)
- **Problem:** `reimbursement_requests_insert_tenant_self … with check ((lower(tenant_email) = rg_auth_email()))`. Unlike maintenance_requests and tenant_messages, it doesn't use `rg_tenant_can_file`. The page itself sends the request's company_id and property_id correctly, but a tenant calling the API directly could file a reimbursement claim (amount and receipt) against any company_id or maintenance_request_id.
- **Smallest fix:** `with check (lower(tenant_email)=rg_auth_email() and rg_tenant_can_file(company_id, property_id, tenant_id))`.

### [P2][SUSPECTED] The portal's rent_log query has no tenant filter, so for dual-role users it sums the whole company — tenant-portal.html:929-932
- **Problem:** `sb.from('rent_log').select(...).order('date_paid', …)`, with only an optional property filter. It relies entirely on RLS. For a user who is both a landlord (company member) and a tenant, RLS returns every company rent row, and "Paid This Month" sums them all. Without `?property=`, a multi-property tenant's payments for every property are compared against one lease's rent.
- **Smallest fix:** Add the same tenant filter used on tenant-payments, or use the tenant RPC from the third finding.

### [P2][CONFIRMED] Lease pages treat holdover or past-end leases as ended and never exclude archived leases — tenant-lease.html:829-837, 934-942; tenant-portal.html:1040-1043, 918-926; tenant-payments.html:1138-1146
- **Problem:** "Your lease has ended. Please contact your landlord about renewal or move-out" shows whenever `lease_end` has passed, even though CLAUDE.md says holdover still charges rent. No lease query filters `archived_at`. The newest-`lease_start` row is taken as current, even if archived or terminated. On payments, that lease then feeds the preferred-method RPC, which raises "Lease not found" for archived leases (rg_07 adds `archived_at is null`).
- **Live:** Lease statuses are `signed` and `terminated`.
- **Smallest fix:** Add `.is('archived_at', null)` and prefer non-terminated leases. Derive state from the `lease_state` the RPC returns.

### [P3][CONFIRMED] Extra `decodeURIComponent` on values URLSearchParams already decoded can crash page init — tenant-repair-requests.html:1254, tenant-documents.html:722 and 798, tenant-contact.html:833-835
- **Problem:** `params.get()` already decodes. A property name, subject or message containing `%` (e.g. "50% duplex") makes `decodeURIComponent` throw a URIError. On contact and repairs this happens before the overlay is removed, so the page hangs on "Loading your portal…".
- **Smallest fix:** Drop the extra `decodeURIComponent` calls.

### [P3][CONFIRMED] Full-screen loading overlay on every tenant page instead of the 3px shimmer bar — e.g. tenant-portal.html:470-474, tenant-repair-requests.html:615
- CLAUDE.md UI standard: "a 3px fixed top shimmer bar for loading, never a full-screen overlay." There's a 4s safety timeout, but on slow mobile networks tenants stare at a blank screen.

### [P3][CONFIRMED] Inconsistent sign-in redirects — tenant-lease.html:907/1018, tenant-payments.html:1239/1243
- These pages send `location.href = 'tenant-login.html'` without `?redirect=`, so the deep link (and `?property=`) is lost. Portal, repairs, documents and contact pass `redirect=`.
- Related: only tenant-payments.html:51 sets `body { overflow-x:hidden }`, which CLAUDE.md requires everywhere. The other six pages don't, though the harness measured no page-level overflow (sx=0) at 320 or 390px.

### [P3][CONFIRMED] HTML built with template strings on repairs, documents and contact
- tenant-repair-requests.html:1076-1083 and 1098-1104, tenant-documents.html:783-789, tenant-contact.html:725. Every interpolated value goes through `safe()`, which escapes `& < > " '`, so I found no injection. Document hrefs go through `safeDocUrl` (http/https only) and then rgFiles signed URLs.
- This still goes against the CLAUDE.md rule to use createElement. New code should use createElement. The `.slice` after escaping (contact) is the one place the escaping has a real bug.

## Notes

- **Security, unescaped output:** I checked every `innerHTML` in the 7 pages and found no unescaped landlord- or tenant-entered text. Portal and lease use `escapeHtml`; payments uses `escapeHtml` for the table and createElement/textContent for How to Pay; repairs, documents and contact use `safe()`. Portal and lease also build innerHTML from strings, all escaped.
- **No internal `target="_blank"`:** The only `target="_blank"` links (documents:788, repairs:1103) point at storage signed URLs, which are external.
- **No service-role key:** None in any page; only the anon key.
- **Inserts:**
  - maintenance_requests (repairs:1161) sends `company_id` and `property_id` from a non-archived lease, plus `tenant_email: user.email` and `tenant_id`. It satisfies `rg_tenant_can_file`.
  - tenant_messages (contact:809) sends lease `company_id` and `property_name`; `trg_rg_fill_property_id` fills property_id.
  - reimbursement_requests sends company_id and property_id from the maintenance row.
  - All columns exist in the live schema.
- **Uploads:**
  - Photos go to `maintenance-photos/<uid>/…`, which matches `tenant_upload_own_maintenance_photos`. The page stores both `photo_paths` and the legacy public URL. Tenants see only a photo count, not thumbnails.
  - Receipts go to `receipts/<uid>/reimbursements/…`, which matches "Users upload own receipts" and is read back through rgFiles plus `rg_receipts_reimb_select`.
- **Column check (all other queries valid):** leases (incl. `tenant_id`, `pay_*`, `tenant_preferred_payment_method`, `grace_period`, `late_fee*`), rent_log (`applied_to_due_date`, `inserted_at`, `tenant_id`, `lease_id`), tenant_documents (`uploaded_at` fallback; `created_at`/`date_uploaded` are harmless JS fallbacks on `*`), tenant_messages, reimbursement_requests, payment_settings, tenants (`property_name` exists). The only invalid columns are the portal's repairs query (second finding).
- **Identity resolution** is the same on all 7 pages (copy-pasted `resolveTenant`). `auth_user_id` first, then case-insensitive email match with `maybeSingle()`. Live has no duplicate auth_user_id or email values in tenants, so `maybeSingle` won't error today. If a tenant ever gets two rows (one per property), it will error, return null, and quietly fall back to email queries.
- **Multi-property tenants:** tenant-login picks the newest lease's property and adds `?property=`. No tenant page has a property switcher (payments has a client-side filter only). Repairs and contact use a read-only Property field, so a tenant with two leases can only file for the other property through a hand-edited URL.
- **Nav consistency:**
  - All 7 pages use the same 6 desktop labels in the same order: Home, Lease, Payments, Repairs, Docs, Contact.
  - Drawer labels differ from desktop (Portal Home, My Lease, Documents) and add My Account.
  - No page uses the two-column `drawer-grid` from CLAUDE.md.
  - Desktop active state is correct on all pages; the account page has no desktop active item by design.
  - Drawer active state is wrong on repairs, documents and contact (P2 finding above).
- **Out of scope but seen:** tenant-login.html:651 runs `location.href = redirectParam` with no validation. That is an open redirect, and a `javascript:` URL would execute. Worth a look by whoever reviews tenant-login.
- **Live DB evidence (aggregates only, 2026-10-09):**
  - rent_log: 118 rows; 26 have no tenant_id and no tenant_email.
  - tenants: 8 total, 2 with no auth_user_id.
  - leases: 11; maintenance_requests: 6 (status values: "Resolved"); tenant_documents: 0; tenant_messages: 1; reimbursement_requests: 0.
  - Lease statuses: signed, terminated.
