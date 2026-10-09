# Launch readiness

Pre-launch inspection, 2026-10-09 (main at `a84986f`).

## Recommendation: **NO-GO** for a public launch, today

The foundations are good:
- Row-level security holds: anonymous visitors can read nothing.
- The rent engine lives in the database.
- Deploys are automated and self-checking.
- The design is mostly coherent.

But four P0 defects block a public launch:
- A new landlord can't add a property (F-01).
- A crafted link can run script on rentalgenieai.com through the tenant sign-in page (F-02).
- Tenant text can run script in the landlord's maintenance history (F-03).
- Tenants don't see the payments recorded since July (F-05).

On top of that, the legal pages still have placeholders, and the main flows have never been exercised end to end on the new database.

**The path to GO is short.** The four P0 fixes are each small (IMPROVEMENT-ROADMAP Phase 0). With those, the Phase 1 items, and one live test pass, this becomes a **CONDITIONAL GO**. Continuing to use it yourself in the meantime is fine: the P0s mostly hurt new users and tenants, not your existing data.

## Platform health: **49 / 100**

| Area | Weight | Score | Basis |
|---|---|---|---|
| Security | 25 | 13 | **Strong:** RLS (anon reads 0 rows, verified), no secrets in pages, private storage via signed links, hardened listings and publish flow. **Weak:** one runtime-verified script-injection path (F-02), open redirects, about 15 unescaped `innerHTML` sites including two tenant→landlord paths (F-03, F-06), `return_to` script URLs (F-04). |
| Core workflows | 25 | 11 | **Working:** rent ledger, expenses, Snap-it, listings, messaging, the AI description. **Broken:** add property (F-01), edit lease (F-08), HOA (F-07), maintenance edits and archive (F-10, F-11), tenant payment history (F-05), new-landlord onboarding (F-25). |
| Data accuracy | 15 | 6 | rg_rent_status / rg_rent_schedule are sound, but four in-browser rent calculations disagree with them (F-12). Reports have wrong columns, double counting and one-day date shifts (F-13–F-15). |
| Desktop UX consistency | 10 | 7 | Most pages share one look. The property-record pages, nav labels and sign-in pages diverge. |
| Mobile UX | 10 | 5 | Good shell (bottom tabs, cards on key pages), but 17 pages scroll sideways at 320 px, 11 at 390 px, tenant nav is broken on 6 pages, and tables aren't cards. |
| Reliability & operations | 10 | 6 | Deploy pipeline with served-commit check; migrations tested in rolled-back transactions. No automated tests; errors are often swallowed into empty states. |
| Content & legal | 5 | 1 | Legal placeholders, a support address on another domain, fake account actions, promises of unbuilt features. |
| **Total** | **100** | **49** | |

The scores are judgement applied to the evidence in FUNCTIONAL-AUDIT.md and UI-UX-AUDIT.md, not a measured metric.

## Issue classification

**P0: launch blockers**
- F-01: add property fails (DB-verified).
- F-02: tenant-login `javascript:` redirect executes (runtime-verified); open redirects on both sign-in pages.
- F-03: stored XSS from tenant text into maintenance history.
- F-05: tenants can't see payments logged since July (data-verified, 26 rows).

**P1: must fix before launch**
- F-04 `return_to` XSS
- F-06 unescaped innerHTML
- F-07 HOA broken
- F-08 duplicate lease on edit
- F-09 checklist lease form
- F-10 urgency vocabulary
- F-11 archive
- F-12 in-browser rent math
- F-13 rent report columns
- F-14 profit math
- F-15 date shift
- F-16 tenant open repairs
- F-17 lease states
- F-18 Supabase in `<head>`
- F-19 fake account actions
- F-20 claim-by-email (verify the setting)
- F-21 support domain
- F-22 legal pages
- F-24 tenant mobile nav
- F-25 onboarding

**P2: should fix**
- F-23 misleading copy
- Mobile card layouts and overflow (UI-UX §1)
- Design consistency (UI-UX §2–3)
- Feature merges (FEATURE-RECOMMENDATIONS)
- Payment inbox completion
- Database advisor tidy-ups
- Acknowledgment email scoping

**P3: later**
- Real AI assistant
- Snap-it for invoices
- Plan limits and Stripe
- Automated test suite

## Launch gate checklist

| Gate | Status |
|---|---|
| All P0 findings fixed and re-tested | ☐ Open (4) |
| All P1 findings fixed or explicitly accepted by the owner | ☐ Open |
| Legal pages complete (entity, state, address, applicant data) | ☐ Open, needs owner input |
| Support mailbox receives mail | ☐ Unverified (`rentalgenie.app`) |
| Supabase Auth: "Confirm email" on; site URL and redirect URLs set for rentalgenieai.com; leaked-password protection on | ☐ Unverified, owner dashboard check |
| Edge Function secrets: `ANTHROPIC_API_KEY` ✅ (verified 2026-10-04); `RESEND_API_KEY`, `FROM_EMAIL` | ☐ Partly verified |
| Live end-to-end pass with test accounts (see below) | ☐ Not done |
| Real iPhone / Safari check of landlord and tenant flows (incl. home-screen mode) | ☐ Not done |
| No sideways scroll at 390 px on any page | ☐ 11 pages fail |
| Deploy pipeline green with served-commit check | ✅ |
| RLS: anonymous users read nothing; no table without RLS | ✅ DB-verified |
| No service-role keys or secrets in pages | ✅ Scan clean |
| Inline scripts parse (`node --check`, all 49 pages) | ✅ |

### Minimum live test pass before GO

1. **Sign-up:** a fresh landlord account → confirm the email → workspace → add property → add lease → record payment → see it in the ledger and on the dashboard.
2. **Tenant:**
   - Invite → magic link → portal shows the payment from step 1.
   - File a repair with a photo → the landlord sees it, edits it and archives it.
   - The acknowledgment email arrives.
3. **Applicant:** a public listing → apply while signed out → the landlord sees the application → applicant login → my-applications.
4. **Password reset:** the email arrives and the new password works.
5. **Snap-it:** read one receipt and one lease.
6. **Reports:** the monthly totals match the ledger for a known month.

## Automated validation results (Phase 9)

| Check | Result |
|---|---|
| Type checking / linting / unit / integration / e2e tests | **None exist in the repository.** No package.json, test runner or CI tests; the only workflow is the deploy. |
| Inline script syntax (`node --check` on every `<script>` block of all 49 pages) | **Pass**, 49/49 |
| Production build | No build step by design. The deploy pipeline has passed 8 consecutive runs, including the served-commit self-check. |
| Rendering smoke test (custom Playwright harness, all pages × 5 widths, stubbed DB) | 49/49 pages loaded. 1 JS error (`property-insurance.html`: "Cannot set properties of null (setting 'textContent')"; may be a missing element under stub data, not yet root-caused). 0 failed asset requests. Sideways scroll: see UI-UX-AUDIT §1. |
| Accessibility | Not tool-checked (no axe/Lighthouse available offline). Small tap targets measured (UI-UX §3). |
| Dependency / security | No package dependencies. CDN: `supabase-js@2` (major pinned); Chart.js pinned on one page, **unpinned on the other** (`https://cdn.jsdelivr.net/npm/chart.js`). Supabase security advisor: 1 ERROR (`public_listings` is a security-definer view, intentional and column-limited), WARNs on SECURITY DEFINER functions callable by API roles (reviewed: the risky one is F-20), leaked-password protection off. |
| Secrets scan | Clean: no service-role key, no `sk-ant-`, no old project references, no `cdn-cgi`, no localhost URLs |

**Minimum test coverage recommended for launch:**
- The Playwright smoke harness in CI, failing on JS errors and sideways scroll at 390 px.
- SQL tests for `rg_rent_schedule` / `rg_rent_status` edge cases (draft, holdover, terminated, partial payment).
- An RLS test as anon, a tenant and a second landlord.

## Verification summary

| Verified | How |
|---|---|
| Every page renders without fatal errors at 5 widths | Playwright harness (Chromium, stub DB) |
| Sideways scroll per page | Measured without mobile emulation |
| Add property fails | Rolled-back insert as the real landlord account |
| Script injection via tenant-login, open redirects | Browser runtime test |
| Tenant payment visibility gap | Read-only counts on live rent_log |
| RLS blocks anonymous reads on all 30 tables/views | Rolled-back query as anon |
| Edit Lease missing lease_id, HOA param mismatch, urgency constraint mismatch, maintenance-history quote escaping, return_to, add-expense escaping | Lead re-read of the code (and constraint DDL) |
| AI listing description works in production | Edge Function logs, HTTP 200 on 2026-10-04 |

| Not verified | Why |
|---|---|
| Any flow with real accounts end to end | No test accounts; production data must not be modified |
| Safari / iOS / Firefox, keyboard, PWA mode | Only Chromium available |
| Email delivery (sign-up, reset, magic links, acknowledgments) | Needs live sends |
| Supabase Auth settings (confirm email, redirect URLs, SMTP) | Not readable through the available tools |
| Most P1/P2 findings marked "Code-reviewed" | Traced by reviewers; not each re-read by the lead |
