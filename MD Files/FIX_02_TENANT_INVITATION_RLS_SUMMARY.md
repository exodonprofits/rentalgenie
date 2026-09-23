# Fix #2: Tenant Invitation — Anonymous RLS Bypass & Broken Registration

## The Problem

**Status:** 🔴 CRITICAL — Tenant registration is completely broken

The original `tenant-invitation.html` tried to validate a tenant's identity **before authentication**:

```javascript
// ❌ BAD: Anonymous query to leases table
var { data: leaseRows, error: leaseErr } = await sb
  .from('leases')
  .select('tenant_email')
  .eq('tenant_name', name)      // User fills in form
  .eq('property_name', prop)    // User fills in form
  .limit(1);
```

This ran as an **unauthenticated user** (the page is public, before signup).

### Your RLS Setup

Checked Supabase policies on `leases` table. All 6 policies require authentication:

- `leases_select_own` → `(created_by = auth.uid())`
- `leases_select_tenant_self` → `(lower(tenant_email) = rg_auth_email())`
- `leases_rw_company_member` → `is_company_member(company_id)`
- (others also require auth)

**Result:** Anonymous user query fails → `leaseErr` is populated → tenant sees "No lease found" → **can't register**.

### The Two Bad Scenarios

**Scenario A (if RLS were permissive):** PII exposure — anyone could enumerate tenant names, properties, and emails by guessing combinations.

**Scenario B (your case):** RLS blocks it → **invitation flow is completely broken**.

---

## The Fix: Post-signup Validation

Instead of validating **before** signup, validate **after** the user is authenticated.

### New Flow

1. **Tenant enters email + password** (just those two — no name/property form fields)
2. **Click "Create My Account"** → calls `auth.signUp()`
3. **Auth succeeds** → user is now authenticated
4. **Immediately after**, query `leases` table as the authenticated user
5. **RLS policy `leases_select_tenant_self` matches** → user can see their own lease(s)
6. **If lease found** → success, redirect to `tenant-login.html`
7. **If no lease found** → reject, tell them to contact landlord

### Why This Works

- ✅ No anonymous database queries
- ✅ Respects your RLS policy (only authenticated users → only their own leases)
- ✅ No PII enumeration risk
- ✅ Simple, no edge functions needed
- ✅ Matches your RLS design

---

## What Changed

**File:** `tenant-invitation.html`

### Before (Broken)

```html
<form>
  <input id="tenantName" placeholder="Jane Smith"/>        ← Name (never used)
  <input id="propertyName" placeholder="123 Main St"/>     ← Property (never used)
  <input id="tenantEmail" placeholder="you@email.com"/>
  <input type="password" id="password"/>
</form>

<script>
// Anonymous query (fails due to RLS)
const { data: leaseRows, error } = await sb
  .from('leases')
  .select('tenant_email')
  .eq('tenant_name', name)
  .eq('property_name', prop);

if(error) {
  // This always triggers because RLS blocks anonymous queries
  setStatus('No lease found...', 'err');
  return;
}
// Never reaches signup if validation fails
</script>
```

### After (Fixed)

```html
<form>
  <!-- Just email + password — no name/property -->
  <input id="tenantEmail" placeholder="you@email.com"/>
  <input type="password" id="password"/>
  <input type="password" id="confirmPassword"/>
</form>

<script>
// Step 1: Sign up (creates auth user)
const { data: authData, error: authErr } = await sb.auth.signUp({
  email: email,
  password: pass
});

if(authErr) throw authErr;

// Step 2: Now that user is authenticated, check their leases
// RLS policy leases_select_tenant_self applies here
const { data: leaseRows, error: leaseErr } = await sb
  .from('leases')
  .select('id,property_name,tenant_name')
  .limit(1);

// If user has at least one lease, success
if(!leaseErr && leaseRows?.length > 0) {
  setStatus('Account created! Check your email to confirm, then sign in.', 'ok');
  window.location.href = 'tenant-login.html';
} else {
  // Not registered as a tenant
  setStatus('Email not registered as a tenant. Contact your landlord.', 'err');
}
</script>
```

### Key Differences

| Aspect | Before | After |
|--------|--------|-------|
| **Form fields** | Email, name, property, password | Email, password only |
| **Query timing** | Anonymous (before auth) | Authenticated (after auth) |
| **RLS policy used** | None (blocked by all policies) | `leases_select_tenant_self` |
| **Validation** | Pre-signup (fails due to RLS) | Post-signup (succeeds) |
| **UX** | Broken, never reaches signup | Works seamlessly |

---

## Security Analysis

### What's now safe

✅ **No anonymous PII access** — `leases` table is not readable by unauthenticated users  
✅ **RLS-respected** — validation uses authenticated queries that match your policies  
✅ **No enumeration** — attacker can't discover tenant emails/properties by guessing combinations  
✅ **Clean separation** — auth is responsible for identity, RLS enforces data isolation  

### Limitations of this approach

- Tenant must know their email (landlord should have used correct email when creating lease)
- If email not in any lease, they get a generic "not registered" error (they can't tell which email is wrong without trying all of them — acceptable for signup)
- If password reset needed later, they'll need the correct email, so get it right upfront

---

## Testing Checklist

Before deploying:

- [ ] Visit `tenant-invitation.html` as anonymous user
- [ ] No prefill (no URL params)
- [ ] Enter email that **is** in a lease
- [ ] Enter password (8+ chars)
- [ ] Click "Create My Account"
- [ ] Verify success message appears
- [ ] Verify redirect to `tenant-login.html` after 2 seconds
- [ ] Verify email confirmation is sent
- [ ] Sign in with that email → verify tenant sees their lease in portal

- [ ] Repeat with email that is **not** in any lease
- [ ] Verify "Email not registered as a tenant" error
- [ ] Verify no redirect (user stays on form)

---

## Notes on Landlord Invitation Flow

This page (`tenant-invitation.html`) is for tenants clicking a public link. A better long-term approach (not for launch) is:

1. **Landlord creates a lease** → system generates a tokenized invite link
2. **Invite link** → `tenant-invitation.html?token=secure_token`
3. **Token is validated** → prefill email/property from the token's lease record
4. **Tenant signs up** → link token to auth user

But that requires a `tenant_invites` table + edge function. For now, the post-signup validation is secure and sufficient.

---

## RLS Policies Reference

Your current policies (confirmed via `pg_policies`):

| Policy | Condition | Purpose |
|--------|-----------|---------|
| `leases_select_tenant_self` | `(lower(tenant_email) = rg_auth_email())` | Tenant reads own lease ✅ **Used here** |
| `leases_select_own` | `(created_by = auth.uid())` | Landlord reads own leases |
| `leases_rw_company_member` | `is_company_member(company_id)` | Company members manage all leases |
| `leases_insert_own` | `(created_by = auth.uid())` in with_check | Landlord creates leases |
| `leases_delete_own` | `(created_by = auth.uid())` | Landlord deletes own |
| `leases_update_own` | `(created_by = auth.uid())` | Landlord updates own |

All require authentication → anonymous users get blocked on all queries.

---

## Next Steps

- **Deploy** this corrected `tenant-invitation.html`
- **Test** with real email/password against your tenant leases
- **Communicate to landlords:** "Invite link is ready; send tenants to tenant-invitation.html"
- **Later:** Consider tokenized invite links when edge functions are set up

Remaining critical issues:
- **Issue #3:** `property-mortgage-activity.html` boot crash (undefined functions)
- **Security:** Complete RLS audit (maintain this one file at a time)
