/* =====================================================
   Rental Genie – Global Navigation Badge Renderer
   File: /shared/js/nav-badges.js
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

  function showBadge(el, value) {
    if (!el) return;

    const n = Number(value || 0);
    if (n > 0) {
      el.style.display = "inline-flex";
      el.textContent = n > 99 ? "99+" : String(n);
    } else {
      el.style.display = "none";
      el.textContent = "";
    }
  }

  function renderNavBadges() {
    const mem = readMem();

    showBadge(
      document.getElementById("navBadgeProperty"),
      mem.property_attention_count ?? mem.vacancy_count ?? 0
    );

    showBadge(
      document.getElementById("navBadgeRent"),
      mem.lease_rent_attention_count ?? mem.rent_attention_count ?? 0
    );

    showBadge(
      document.getElementById("navBadgeExpense"),
      mem.expense_attention_count ?? 0
    );

    showBadge(
      document.getElementById("navBadgeMaintenance"),
      mem.maintenance_open_count ?? 0
    );
  }

  window.RGBadges = window.RGBadges || {};
  window.RGBadges.renderNavBadges = renderNavBadges;

  document.addEventListener("DOMContentLoaded", renderNavBadges);
})();