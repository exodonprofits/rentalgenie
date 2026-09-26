# Rental Genie — working notes for Claude Code

Property management app for independent landlords. Static HTML/CSS/JS pages on Supabase, automated
with n8n, hosted on Cloudflare. No build step: every page is a self-contained file that runs as-is.

Read this before changing anything. The rules below come from bugs that already cost real debugging
time.

---

## Hard rules

**Load the Supabase client in `<body>`, never in `<head>.`** In `<head>` it triggers browser
tracking prevention, which blocks local storage and produces empty auth sessions. This was the root
cause of a batch of "logged in but no data" bugs across many pages.

**Use `document.createElement`, not template strings, when building HTML.** Template strings cause
quote-collision bugs in this codebase. Existing pages break this rule in places; don't add more.

**Never use `target="_blank"` on an internal link.** It breaks the iOS home-screen app by forcing an
in-app browser sheet with the address bar back. External links are fine.

**Escape anything interpolated into an HTML string.** On pages that build `innerHTML`, `safe()` /
`safeText()` only format for `textContent` (em-dash for empty, no escaping); HTML strings go through
`escHtml()` / `safeHtml()`. URLs placed in an `href` go through a `safeUrl()` that allows only
`http:`/`https:` — `new URL()` alone accepts `javascript:`. Better still, use `createElement` and
`textContent`.

**Never put the Supabase service-role key in a page.** It belongs in n8n and Edge Functions only.
The anon key in pages is expected; row-level security is what protects the data.

**Strip Cloudflare `cdn-cgi` links after each deploy.** They come back every time and break on
localhost.

**One self-contained file per page, CDN dependencies only.** No bundler, no framework, no
node_modules.

---

## Reference pages

- `lease-rent-center.html` — the reference for the auth bootstrap and UI patterns.
- `dashboard.html` — the reference for mobile and PWA behaviour.

Match these when changing other pages rather than inventing a new approach.

**Auth bootstrap order:** `safeStorage` IIFE with an in-memory fallback → `window._rgClient` reuse
guard → `waitForClientReady()` polling → async `DOMContentLoaded` boot calling `getUser()` then
falling back to `getSession()` → CSS class-driven auth state (`body.auth-ready` / `body.auth-guest`)
plus imperative `style.display` as a backstop → redirect to `login.html?returnTo=` when signed out.

**UI standards:** grids of records collapse to single-column cards on mobile; `body { overflow-x:
hidden }` everywhere; a 3px fixed top shimmer bar for loading, never a full-screen overlay; six
canonical nav labels with `withProp()` carrying `?property=`; a two-column `drawer-grid` mobile nav;
two deliberately separate button systems (pill-shaped navy toolbar buttons at 999px radius, and
rounded gradient modal/detail buttons at 12px).

---

## Database

**Rent is calculated in the database, not in pages.** Two functions are the single source of truth:

- `rg_rent_schedule(company_id, as_of)` — one row per due date with rent, paid, and balance.
- `rg_rent_status(company_id, as_of)` — per-property totals built on the schedule.

Pages call these. Do not recompute balances, due dates, or late status in JavaScript. Three separate
in-page implementations used to disagree with each other and with the ledger; that is what these
functions replaced.

**Lease states:** `active`; `holdover` (past the end date, still charging, because rent is still
owed when a tenant stays); `month_to_month`; `ended` (terminated, no rent accrues after the
termination date).

**Access control:** `rg_company_access(company_id)` and `rg_can_access_property(property_id)` back
the row-level security policies. Tenant-side inserts into `maintenance_requests` and
`tenant_messages` go through `rg_tenant_can_file(company_id, property_id, tenant_id)`, which requires
a non-archived lease with that company (and property) — pages must send the lease's `company_id`.
Tenants may only change `phone` on their own `tenants` row (`trg_tenants_limit_self_update`). Storage buckets are private; pages open files through signed links
via the `rgFiles` helper, which accepts either a stored path or a legacy public URL.

**Property identity is `property_id`.** Every table that references a property has a `property_id`
with a foreign key; `property_name` is a display copy. Renaming a property updates every copy
(`trg_rg_cascade_property_rename`), and fill triggers set `property_id` from `(company_id,
property_name)` when a page sends only the name. New queries and joins should use `property_id`;
many existing pages still filter by name, which is safe only because the names are kept in sync.

**Snap it:** the `rg-snap` Edge Function (source in `supabase/functions/rg-snap/`) reads an uploaded
receipt (`kind: "receipt"`, bucket `receipts`, path `expenses/<company_id>/…`) or lease (`kind:
"lease"`, bucket `tenant-documents`, path `<company_id>/…`) with the caller's JWT and returns a
draft for the page to prefill. It never writes; the landlord saves. Used by `add-expense.html` and
`lease-form.html`. Needs the `ANTHROPIC_API_KEY` secret. Expense categories in the function must
match the page's `<option>` values.

**Payment inbox:** `rg_ingest_payment_email` (service role only) queues forwarded payment alerts;
`rg_confirm_incoming_payment` writes them to `rent_log`, splitting across unpaid months oldest-first;
`rg_dismiss_incoming_payment` handles "not rent". Version 1 never logs a payment automatically.

**Gotchas learned the hard way:**
- `rent_log` has no `is_late_fee` column. Queries that ask for it fail silently and show empty data.
- `maintenance_requests` uses `urgency_level`, not `priority`.
- `companies` uses `owner_user_id`, not `owner_id`.
- Verify column names against the live schema before writing a query. A wrong column makes the
  request fail quietly, and the page just looks empty.
- Row-level security recursion doesn't error at policy creation; it surfaces as infinite recursion
  at query time. Fix with a `SECURITY DEFINER` function using `SET row_security = off`.
- Migrations are transactional. Split risky statements so one failure doesn't roll back everything.
- Use `net.http_post()` (pg_net) to call Edge Functions from triggers. `verify_jwt` must be false
  for webhook receivers and true for user-facing functions.
- Webhook secrets live in Vault, never in a function body. The maintenance trigger and the
  `maintenance-acknowledgment` Edge Function both read `rg_maintenance_webhook_secret` (service role
  only); rotate it with `vault.update_secret`.

---

## Before you call something done

- **Check every query's columns against the live schema.** This class of bug has bitten repeatedly.
- **Test database changes in a transaction that rolls back,** simulating the roles involved
  (`SET LOCAL ROLE authenticated` with `request.jwt.claims`), including a user who should see
  nothing.
- **Syntax-check inline scripts** (`node --check`) after editing a page. These files are large and a
  stray bracket is easy to miss.
- **Check both widths.** Desktop and a ~390px phone, with no sideways scrolling.

---

## Known gaps — don't extend these, fix or retire them

- Online rent payments aren't built. Stripe Connect is scoped, not started.
- Escrow reconciliation doesn't exist. The old page read tables that were never created and was
  removed along with the legacy duplicate pages (rent-log, rent-payments, manage-properties,
  lease-center, rental-tracker, tenant-history, submit-request, landing, rent-analyzer).
- No plan limits are enforced anywhere; the pricing on the homepage is marketing copy only.
- The Supabase project is shared with the other GenieSphere products. Row-level security is on
  for every exposed table and views run as the caller (Sept 2026 audit). Remaining watch items:
  `business_profiles` is readable by anon (Salon Genie pages use it), and `follow_up_requests` has
  no salon column to scope by. When adding a policy, never add a `using (true)` catch-all: RLS
  grants access if any policy matches, so one catch-all cancels every scoped policy beside it.

---

## Conventions

- Keep changes to one page per commit where practical; these files are large and mixed diffs are
  unreadable.
- Prefix database work with `db:` in commit messages.
- Never commit mortgage statements, rent exports, tenant lists, or `.env` files. `.gitignore`
  covers the known cases, including `import export/` and all CSVs.
- Ask before deleting a page. Several "unused" files turned out to be linked from live pages.
