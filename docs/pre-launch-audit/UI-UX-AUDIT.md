# UI / UX audit

Pre-launch inspection, 2026-10-09. Desktop and mobile consistency, layout defects and usability.

## How this was checked

| Method | What it covers | Limits |
|---|---|---|
| Headless Chromium harness (Playwright 1.56) | All 49 pages loaded at 320, 390, 768, 1280 and 1920 px with a stubbed Supabase client and sample data (2 properties, 2 leases, 9 payments, 1 repair, 1 message). It recorded JS errors, redirects, horizontal overflow and the elements causing it. Screenshots were taken at 390 and 1280 px and reviewed as contact sheets. | **Chromium only.** WebKit (Safari) and Firefox are not installed in this environment, and Google Fonts and the CDN were blocked, so fonts render as fallbacks. **Not tested against the real database or real accounts.** |
| Overflow re-run without mobile emulation | Real sideways scrolling at 320, 390 and 768 px. Mobile emulation hides overflow by widening the viewport, so this second pass is the one that counts. | Same as above |
| Code reading by five reviewers | The CSS of every page (breakpoints, fixed widths, tables) and the navigation markup | Read-only |

Raw outputs are not committed: harness JSON, overflow JSON and screenshots stayed in the session scratchpad.

## Overall impression

The landlord app already has an identity. Every page shares the navy header bar, white cards on a light grey background, DM Sans and the six-icon bottom tab bar on mobile. Lease & Rent Center, Dashboard, Property Management, Expense Tracking and the tenant portal look like one product.

What breaks the "one app" feeling:
- A group of older property-record pages styled differently: Financing, Insurance, Property Tax and Mortgage Activity.
- Sideways scrolling on 17 pages at small phone widths.
- Inconsistent navigation labels.
- Full-screen loading overlays where the standard is a 3px shimmer bar.

None of these needs a redesign. They are consistency fixes against standards already written down in CLAUDE.md.

## 1. Sideways scrolling on phones (measured)

`SCROLLn` means the page itself scrolls sideways by n px. `clip` means content runs past the screen edge but is cut off instead of scrolling. Clipping is acceptable inside a table scroll box, but it hides content when it isn't.

| Page | 320 px | 390 px | 768 px | Cause (element sticking out at 390) |
|---|---|---|---|---|
| view-lease.html | SCROLL 210 | **SCROLL 140** | — | Lease history document rows (`.doc-row-meta`, `.doc-row-actions`) don't wrap |
| add-expense.html | SCROLL 167 | **SCROLL 97** | — | "Recent expenses" table has no scroll wrapper |
| tenant-repair-requests.html | SCROLL 135 | **SCROLL 65** | — | Requests and reimbursement tables don't collapse to cards; empty state is too wide |
| account.html | SCROLL 94 | **SCROLL 24** | — | Tab buttons row (`.tab-btn`) doesn't wrap or scroll |
| tenant-portal / tenant-lease / tenant-documents / tenant-contact / tenant-account / tenant-login | SCROLL 85 | **SCROLL 15** | — | Boot script sets the user chip to `display:flex` inline, which overrides the mobile rule hiding it and pushes the hamburger (the only mobile nav) off-screen. Already fixed the same way on tenant-payments.html (`display:none !important`). |
| portfolio-financial-dashboard.html | SCROLL 67 | clip | — | Cash-flow bars (`.cf-bar-wrap`) |
| maintenance-history.html | SCROLL 67 | clip | clip | Table without card layout |
| maintenance-cost.html | SCROLL 67 | clip | — | Expense table |
| property-finance.html | SCROLL 68 | clip | clip | History table |
| property-mortgage-activity.html | SCROLL 63 | clip | — | Activity table and footer |
| hoa-info.html, lease-form.html | SCROLL 67 | — | — | Fixed-width rows at 320 px |
| property-tax.html | SCROLL 38 | clip | — | Table and buttons |
| forgot-password.html | SCROLL 24 | — | — | Card width at 320 px |
| property-insurance.html | SCROLL 9 | clip | — | History table |
| tenant-messages.html | SCROLL 5 | — | — | Minor |
| expense-tracking, property-documents, reports-analytics, lease-rent-center, dashboard, login, maintenance-requests | clip only | clip only | some | Mostly tables inside scroll boxes, which is fine. Lease & Rent Center's clipping is the closed payment drawer parked off-screen, which is also fine. Reports-analytics' maintenance table clips its right column at 390 px, so check that one. |

**The other 32 pages had no sideways scroll at any width.**

**Root causes, in order of payoff:**
1. **Tenant portal chip:** one CSS line on six pages.
2. **Tables without a phone layout.** CLAUDE.md's standard is that "grids of records collapse to single-column cards on mobile". Lease & Rent Center, tenant-payments and maintenance-requests already do this. The pages listed above don't.
3. **Missing `body { overflow-x: hidden }`.** This is the CLAUDE.md safety net, and it's missing on 38 of 49 pages (static scan). It hides overflow rather than fixing it, so apply it after fixing causes 1 and 2, not instead of them.

## 2. Visual consistency (desktop)

| Issue | Pages | Evidence | Recommendation |
|---|---|---|---|
| **Different typography on the property-record pages** | property-insurance, property-finance, property-tax, property-mortgage-activity | `property-insurance.html:11`: `font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto` with no generic fallback and no DM Sans. Where those fonts are missing, headings render in Times New Roman (visible in the screenshots). Also different heading sizes, plain inputs and boxy cards. | Use the shared DM Sans body stack with a `sans-serif` fallback, and the standard card and section-header styles from lease-rent-center. Smallest fix: add `, sans-serif` to the stack. |
| **Navigation labels differ** | Most app pages use short labels (Dashboard, Properties, Lease & Rent, Expenses, Maintenance, Messages, Reports). hoa-form and signup use long ones (Property Management, Lease & Rent Center, Expense Tracking, Maintenance Requests, Reports & Analytics). publish-listing shows only "← Back to Properties". tenant-portal-picker has its own header. | Contact sheet, desktop | CLAUDE.md asks for six canonical labels with `withProp()`. Adopt them everywhere, including signup (which shouldn't show app nav to a signed-out visitor at all). |
| **Two separate login experiences** | login.html (landlord, with a role switcher), login-select.html (role chooser), tenant-login.html, applicant-login.html | Four sign-in entry pages with different layouts | One sign-in page with three clear choices. See FEATURE-RECOMMENDATIONS. |
| **Raw email template published as a page** | tenant-magic-link-email.html | Renders `{{ .Data.property_name }}` template syntax at rentalgenieai.com/tenant-magic-link-email.html | Move it out of the deployed folder (e.g. `supabase/templates/`). |
| **Placeholder text visible on public pages** | privacy.html, terms.html | Highlighted `[LEGAL ENTITY NAME]`, `[STATE]`, `[COUNTY]` and `[MAILING ADDRESS]` | Fill in before launch (see LAUNCH-READINESS). |

## 3. Mobile app feel

**What already works:**
- A fixed bottom tab bar on 20 landlord pages.
- A hamburger drawer.
- Card-based dashboards.
- Sticky header.
- The tenant portal reads like an app on a phone, apart from the hamburger bug above.

**Issues:**

| Issue | Where | Recommendation |
|---|---|---|
| **Bottom tab bar is icons only** | All landlord pages with the tab bar | Add short labels under the icons (Home, Properties, Rent, Expenses, Repairs, Reports). Icon-only tabs are hard to learn; the emoji icons aren't self-explanatory. |
| **Tab bar styled differently** | property-tax.html (coloured emoji tiles) | Use the shared tab-bar markup |
| **Small tap targets** (under 28 px tall at 390 px) | account (15), privacy (13), add-expense (13), view-lease (12), add-maintenance-request (12), dashboard (11), index (11), login (11), terms (11), contact-us (10) | Aim for at least 44 px for primary actions. Most are footer links and inline text buttons, so this is P2/P3. |
| **Full-screen loading overlay** | 28 pages have an `authOverlay` (all tenant pages, account, others) | CLAUDE.md standard: a 3px fixed top shimmer bar, never a full-screen overlay. The overlay makes every page load feel like a blocking splash screen. |
| **Tables instead of cards** | See section 1 | Card layout below 600 px |
| **Long forms in one column without sections** | property-insurance, property-finance, add-property | Group fields into collapsible sections on phones |

**Not verified (no device or browser available here):**
- iOS safe areas and notch padding.
- On-screen keyboard behaviour on long forms.
- Landscape layouts.
- Safari-specific rendering.

Check these on a real iPhone before launch, especially the home-screen (PWA) mode CLAUDE.md mentions.

## 4. Usability and clarity

- **Hidden pages:**
  - maintenance-history is reachable only from maintenance-cost and all-properties-summary.
  - property-insurance only from add-property.
  - publish-listing had no entry point until 2026-10-04 (now linked from Property Overview).
- **Placeholder copy promising missing features:**
  - tenant-login says tenants can "Pay rent" (`tenant-login.html:430`); online payments aren't built.
  - terms.html describes escrow reconciliation.
  - index meta description mentions "Ask Genie".
- **Silent failures:** several pages swallow query errors and show an empty state, which reads as "no data" rather than "something went wrong". Examples:
  - tenant-portal's open-repairs card (bad columns, hidden).
  - reports-analytics' rent report (bad columns, shows "—").
  - hoa-info hero (bad column, hidden).

  A shared pattern ("Couldn't load X. Retry") would make defects visible instead of looking like empty accounts.
- **Fake confirmations:**
  - account.html's "Export my data" and "Delete account" show success but do nothing (`account.html:1107-1117`).
  - tenant-account's phone save says "saved" when 0 rows changed for unlinked tenants.

  A false "done" is worse for trust than a missing button.
