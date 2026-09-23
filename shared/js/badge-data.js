/* =====================================================
   Rental Genie – Live Badge Data Calculator
   File: /shared/js/badge-data.js
===================================================== */
(function () {
  const MEM_KEY = "rg_genie_memory_v1";

  function readMem() {
    try {
      return JSON.parse(localStorage.getItem(MEM_KEY) || "{}");
    } catch {
      return {};
    }
  }

  function writeMem(patch) {
    const next = {
      ...readMem(),
      ...patch,
      updated_at: new Date().toISOString()
    };
    localStorage.setItem(MEM_KEY, JSON.stringify(next));
    return next;
  }

  function startOfToday() {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  }

  function toISODate(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }

  function addDays(date, days) {
    const d = new Date(date);
    d.setDate(d.getDate() + days);
    return d;
  }

  async function getClient() {
    if (window.sb?.auth) return window.sb;
    if (window.GS?.sb?.auth) return window.GS.sb;
    if (window.__sb?.auth) return window.__sb;
    throw new Error("Supabase client not ready.");
  }

  async function getActiveCompanyId(client) {
    const stored = localStorage.getItem("rg_active_company_id");
    if (stored) return stored;

    const { data: userRes } = await client.auth.getUser();
    const user = userRes?.user;
    if (!user) return null;

    const { data } = await client
      .from("company_members")
      .select("company_id")
      .eq("user_id", user.id)
      .order("created_at", { ascending: true })
      .limit(1);

    return data?.[0]?.company_id || null;
  }

  async function calculateBadgeData() {
    const client = await getClient();
    const companyId = await getActiveCompanyId(client);

    if (!companyId) {
      return writeMem({
        property_attention_count: 0,
        lease_rent_attention_count: 0,
        expense_attention_count: 0,
        maintenance_open_count: 0
      });
    }

    const today = startOfToday();
    const todayISO = toISODate(today);
    const soonISO = toISODate(addDays(today, 30));

    const [
      propertiesRes,
      leasesRes,
      rentLogRes,
      expensesRes,
      maintenanceRes
    ] = await Promise.all([
      client
        .from("properties")
        .select("id,name,occupancy_status")
        .eq("company_id", companyId),

      client
        .from("leases")
        .select("id,property_id,property_name,status,lease_start,lease_end,tenant_name")
        .eq("company_id", companyId)
        .order("lease_start", { ascending: false }),

      client
        .from("rent_log")
        .select("id,property_id,property_name,date_paid,amount,applied_to_due_date,note,is_late_fee")
        .eq("company_id", companyId),

      client
        .from("expenses")
        .select("id,category,receipt_url,status,description")
        .eq("company_id", companyId),

      client
        .from("maintenance_requests")
        .select("id,status,priority")
        .eq("company_id", companyId)
    ]);

    const properties = propertiesRes.data || [];
    const leases = leasesRes.data || [];
    const rentLogs = rentLogRes.data || [];
    const expenses = expensesRes.data || [];
    const maintenance = maintenanceRes.data || [];

    const activeLeaseByPropertyKey = new Map();

    for (const lease of leases) {
      const status = String(lease.status || "").toLowerCase();
      const start = lease.lease_start || "";
      const end = lease.lease_end || "";

      const isActiveStatus =
        status.includes("sign") ||
        status.includes("active") ||
        status.includes("current") ||
        status.includes("renew");

      const isInDateRange = (!start || start <= todayISO) && (!end || end >= todayISO);

      if (!isActiveStatus || !isInDateRange) continue;

      const key = lease.property_id || lease.property_name;
      if (key && !activeLeaseByPropertyKey.has(key)) {
        activeLeaseByPropertyKey.set(key, lease);
      }
    }

    const latestRentByPropertyKey = new Map();
    for (const row of rentLogs) {
      const key = row.property_id || row.property_name;
      if (!key || !row.date_paid) continue;
      const prev = latestRentByPropertyKey.get(key);
      if (!prev || row.date_paid > prev.date_paid) {
        latestRentByPropertyKey.set(key, row);
      }
    }

    let propertyAttentionCount = 0;
    for (const p of properties) {
      const occ = String(p.occupancy_status || "").toLowerCase();
      const key = p.id || p.name;

      const isVacant = occ === "vacant";
      const occupied = occ === "tenant_occupied" || occ === "occupied";
      const missingLease = occupied && !activeLeaseByPropertyKey.has(key) && !activeLeaseByPropertyKey.has(p.name);
      const missingRent = occupied && !latestRentByPropertyKey.has(key) && !latestRentByPropertyKey.has(p.name);

      if (isVacant || missingLease || missingRent) {
        propertyAttentionCount += 1;
      }
    }

    let leaseRentAttentionCount = 0;

    for (const p of properties) {
      const occ = String(p.occupancy_status || "").toLowerCase();
      const occupied = occ === "tenant_occupied" || occ === "occupied";
      const lease =
        activeLeaseByPropertyKey.get(p.id) ||
        activeLeaseByPropertyKey.get(p.name);

      if (occupied && !lease) {
        leaseRentAttentionCount += 1;
        continue;
      }

      if (!lease) continue;

      if (lease.lease_end && lease.lease_end >= todayISO && lease.lease_end <= soonISO) {
        leaseRentAttentionCount += 1;
        continue;
      }

      const latestRent =
        latestRentByPropertyKey.get(p.id) ||
        latestRentByPropertyKey.get(p.name);

      if (!latestRent) {
        leaseRentAttentionCount += 1;
      }
    }

    let expenseAttentionCount = 0;
    for (const exp of expenses) {
      const status = String(exp.status || "").toLowerCase();
      const missingReceipt = !exp.receipt_url;
      const uncategorized = !exp.category || String(exp.category).toLowerCase() === "uncategorized";
      const needsReview = status === "pending" || status === "flagged";

      if (missingReceipt || uncategorized || needsReview) {
        expenseAttentionCount += 1;
      }
    }

    let maintenanceOpenCount = 0;
    for (const req of maintenance) {
      const status = String(req.status || "").toLowerCase();
      if (
        status === "open" ||
        status === "new" ||
        status === "in progress" ||
        status === "in_progress" ||
        status === "waiting_vendor" ||
        status === "urgent"
      ) {
        maintenanceOpenCount += 1;
      }
    }

    return writeMem({
      property_attention_count: propertyAttentionCount,
      lease_rent_attention_count: leaseRentAttentionCount,
      expense_attention_count: expenseAttentionCount,
      maintenance_open_count: maintenanceOpenCount,

      /* backward compatibility */
      vacancy_count: propertyAttentionCount,
      rent_attention_count: leaseRentAttentionCount
    });
  }

  window.RGBadges = window.RGBadges || {};
  window.RGBadges.calculateBadgeData = calculateBadgeData;
})();