# Fix #1: Tenant Maintenance Requests — Missing company_id

## The Problem

**Status:** 🔴 CRITICAL — Tenant repair submissions currently fail silently

When a tenant submitted a repair request via `tenant-repair-requests.html`, the form omitted the `company_id` field. The `maintenance_requests` table has a NOT NULL constraint on `company_id`, so:

- **Insert failed** with a database constraint violation
- **Tenant saw:** "Error: [db error]" (unhelpful)
- **Landlord saw:** nothing (no record created)
- **Result:** Entire maintenance workflow was broken

### Why it broke

- Line 789 (original): `insert([{property_name, tenant_email, urgency_level, issue_summary, photo_urls, status}])`
- Missing: `company_id` (required), `property_id` (optional but useful)
- Landlord's query (line 2249 in `maintenance-requests.html`) filters by `company_id`, so even if the constraint allowed NULL, the request would be invisible

## The Fix

### What changed

**File:** `tenant-repair-requests.html`  
**Function:** `submitRequest()` (lines 782–805)

**Before:**
```javascript
async function submitRequest(){
  // ... validation ...
  const {error} = await sb.from('maintenance_requests').insert([{
    property_name, tenant_email:user.email, urgency_level:selectedUrgency, 
    issue_summary, photo_urls:photo_urls||null, status:'Submitted'
  }]);
  // ...
}
```

**After:**
```javascript
async function submitRequest(){
  // ... validation ...
  
  // NEW: Resolve company_id and property_id from the tenant's lease
  const {data:leaseData,error:leaseErr} = await sb
    .from('leases')
    .select('company_id,property_id')
    .eq('tenant_email',user.email)
    .eq('property_name',property_name)
    .order('lease_start',{ascending:false})
    .limit(1);
  
  if(leaseErr || !leaseData || leaseData.length === 0){
    setMsg('❌ Could not resolve your property. Please refresh and try again.','err');
    btn.disabled=false; btn.textContent='📨 Submit Request';
    return;
  }
  
  const company_id = leaseData[0].company_id;
  const property_id = leaseData[0].property_id;
  
  // NOW includes company_id and property_id
  const {error} = await sb.from('maintenance_requests').insert([{
    property_name, property_id, tenant_email:user.email, company_id,
    urgency_level:selectedUrgency, issue_summary, photo_urls:photo_urls||null, 
    status:'Submitted'
  }]);
  // ...
}
```

### How it works

1. **Before insert**, tenant's lease is queried with `tenant_email` + `property_name`
2. **Extract** `company_id` and `property_id` from the matched lease
3. **Include both** in the maintenance_requests insert
4. **Fallback:** If no lease is found, show user-friendly error instead of cryptic DB error

## Why this fixes it

- ✅ `company_id` is now populated → insert succeeds (no NOT NULL violation)
- ✅ Landlord's filter `WHERE company_id = activeCompanyId` now matches the record
- ✅ Request appears in landlord's maintenance queue
- ✅ `property_id` also resolved for better data structure
- ✅ If lookup fails (shouldn't happen if tenant exists), user sees clear message

## Database verification

Confirmed that `maintenance_requests.company_id` is:
- **Type:** uuid
- **Nullable:** NO (constraint enforced)

Query used:
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'maintenance_requests'
ORDER BY ordinal_position;
```

**Result:** No rows with `company_id IS NULL` currently exist (confirmed via Supabase SQL editor).

## Testing checklist

Before deploying:

- [ ] Log in as tenant
- [ ] Submit a repair request (select property, describe issue, submit)
- [ ] Verify request appears in landlord's `maintenance-requests.html` queue
- [ ] Confirm request has correct `company_id` in the database
- [ ] Try submitting for a property the tenant has no lease for — should show "Could not resolve" error

## Next steps

This was **Issue #1** of the critical findings. Remaining:

- **Issue #2:** Anonymous read of `leases` table in `tenant-invitation.html` (PII exposure or dead invite flow)
- **Issue #3:** Boot crash in `property-mortgage-activity.html` (undefined functions)
- **Security:** RLS policy verification in Supabase dashboard (most critical overall)
