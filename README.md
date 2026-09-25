# Rental Genie

Property finances and day-to-day management for independent landlords. Rental Genie tracks rent,
mortgage and escrow, property tax, insurance, HOA and repairs per property, gives tenants a
password-free portal, and lets landlords ask questions about their own numbers in plain English.

Status: **early access**. Online rent payments are not built yet; rent is recorded, not collected.

---

## Stack

| Layer | What it is |
|---|---|
| Frontend | Static HTML/CSS/JS, one self-contained file per page, CDN dependencies only |
| Database / auth / storage | Supabase (PostgreSQL, row-level security, Storage) |
| Automation | n8n Cloud (payment inbox, reminders) |
| AI | Anthropic API — Ask Genie, and payment-email extraction |
| Hosting | Cloudflare |

No build step. Every page runs as-is.

---

## Layout

```
/                       landlord + tenant pages (one HTML file per screen)
  index.html            marketing homepage
  dashboard.html        landlord home: assignments, finances, payment inbox
  lease-rent-center.html  leases + rent ledger (auth/UI reference page)
  tenant-portal.html    tenant home
/shared
  config.json           Supabase URL + anon key
  /js                   auth header, boot, shared client
  /css, /partials       shared shell
  /vendor               pinned Supabase JS client
  manifest.json         PWA manifest
/json                   n8n workflow exports
/images                 icons and artwork
/docs                   setup guides
```

`dashboard.html` is the reference for mobile and PWA behaviour; `lease-rent-center.html` is the
reference for the auth bootstrap and UI patterns. Match them when changing other pages.

---

## Running locally

Serve the folder over HTTP — opening files directly breaks auth and fetch:

```bash
python3 -m http.server 8083
# then open http://localhost:8083/dashboard.html
```

Notes:
- The Supabase client must load in `<body>`, never in `<head>`. Loading it in `<head>` triggers
  browser tracking prevention and produces empty sessions.
- Strip Cloudflare `cdn-cgi` links after each deployment; they break on localhost.
- Internal links must not use `target="_blank"`, which breaks the iOS home-screen app.

---

## Configuration

| Setting | Where | Notes |
|---|---|---|
| Supabase URL + anon key | `shared/config.json` and inline in each page | Public by design; row-level security is what protects the data |
| `RG_PAYMENT_INBOX_BASE` | `dashboard.html` | Postmark inbound address for the payment inbox |

The service-role key belongs only in n8n and Supabase Edge Functions. It must never appear in a page.

---

## Database

Rules live in the database so every page agrees.

**Rent**
- `rg_rent_schedule(company_id, as_of)` — one row per due date: rent, paid, balance.
- `rg_rent_status(company_id, as_of)` — per-property totals built on the schedule: balance, months
  unpaid, oldest unpaid date, days overdue, lease state.
- Lease states: `active`, `holdover` (past end date, still charging), `month_to_month`, `ended`
  (terminated; no rent accrues after the termination date).

**Payment inbox**
- `rg_ingest_payment_email(...)` — service role only. Scores a forwarded payment alert against every
  lease and queues it for confirmation. Non-rent payments are stored as `ignored` without the payer
  name or email body.
- `rg_confirm_incoming_payment(id, property_id, due_date, remember)` — writes to `rent_log`,
  splitting across unpaid months oldest-first, and remembers the payer name.
- `rg_dismiss_incoming_payment(id)` — "not rent".

**Access**
- `rg_company_access(company_id)` and `rg_can_access_property(property_id)` back the row-level
  security policies. Landlords see their own company's data; tenants see only their own lease,
  payments, documents and requests.
- Storage buckets (`tenant-documents`, `receipts`, `maintenance-photos`) are private. Pages open
  files through signed links; see the `rgFiles` helper.

---

## Deployment

Cloudflare serves the folder as static files. Deploy the repository root; there is nothing to build.
After deploying, purge the Cloudflare cache, or new versions of a page can keep serving from the edge.

---

## Known gaps

- Online rent payments are not built. Stripe Connect is scoped but not started.
- No plan limits are enforced; pricing copy is marketing only.

---

## Do not commit

Mortgage statements, rent exports, tenant lists, `.env` files, or the Supabase service-role key.
`.gitignore` covers the known cases, including `import export/` and every `.csv`.

This repository should stay **private**: it holds the full product and the details of one live
portfolio.
