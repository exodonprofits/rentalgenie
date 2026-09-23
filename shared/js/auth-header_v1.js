// /shared/js/auth-header.js
// Edge-safe header auth: does NOT depend on Supabase SDK session persistence.
// It uses a small cached user object stored at login time (first-party storage).

(function () {
  const KEY_USER = "gs_auth_user_v1";

  // Optional overrides (for different folder structures)
  let LOGIN_URL = "../onboarding/login.html";
  let AFTER_LOGOUT_URL = "../index.html";

  function safeParse(s) {
    try { return JSON.parse(s); } catch (_) { return null; }
  }

  function getCachedUser() {
    try {
      const a = localStorage.getItem(KEY_USER);
      if (a) return safeParse(a);
    } catch (_) {}

    try {
      const b = sessionStorage.getItem(KEY_USER);
      if (b) return safeParse(b);
    } catch (_) {}

    return null;
  }

  function setCachedUser(user, preferSession) {
    const payload = JSON.stringify(user || null);

    try { localStorage.removeItem(KEY_USER); } catch (_) {}
    try { sessionStorage.removeItem(KEY_USER); } catch (_) {}

    try {
      (preferSession ? sessionStorage : localStorage).setItem(KEY_USER, payload);
    } catch (_) {
      // If storage is blocked, do nothing.
    }
  }

  function clearCachedUser() {
    try { localStorage.removeItem(KEY_USER); } catch (_) {}
    try { sessionStorage.removeItem(KEY_USER); } catch (_) {}
  }

  function displayNameFromUser(u) {
    if (!u) return "";
    return (
      u.full_name ||
      u.name ||
      u.username ||
      (u.email ? String(u.email).split("@")[0] : "") ||
      "Account"
    );
  }

  function $(id) { return document.getElementById(id); }

  function setLoggedOutUI() {
    const nameEl = $("user-name-label");
    const loginBtn = $("user-auth-action");
    const logoutBtn = $("user-signout-btn");

    if (nameEl) nameEl.textContent = "Log in";
    if (loginBtn) {
      loginBtn.textContent = "Log in / Sign up";
      loginBtn.onclick = () => {
        const next = encodeURIComponent(location.pathname + location.search + location.hash);
        location.href = LOGIN_URL + "?next=" + next;
      };
    }
    if (logoutBtn) logoutBtn.style.display = "none";
  }

  function setLoggedInUI(user) {
    const nameEl = $("user-name-label");
    const loginBtn = $("user-auth-action");
    const logoutBtn = $("user-signout-btn");

    if (nameEl) nameEl.textContent = displayNameFromUser(user);
    if (loginBtn) {
      loginBtn.textContent = "Account";
      loginBtn.onclick = () => { location.href = "../onboarding/user_profile_form.html"; };
    }
    if (logoutBtn) {
      logoutBtn.style.display = "block";
      logoutBtn.onclick = async () => {
        clearCachedUser();
        setLoggedOutUI();

        // Best-effort Supabase sign out (if your global GSClient exists)
        try {
          if (window.GSClient && window.GSClient.getAsync) {
            const c = await window.GSClient.getAsync();
            if (c?.auth?.signOut) await c.auth.signOut();
          }
        } catch (_) {}

        location.href = AFTER_LOGOUT_URL;
      };
    }
  }

  function wireDropdown() {
    const toggle = $("user-menu-toggle");
    const dd = $("user-menu-dropdown");
    if (!toggle || !dd) return;

    function close() {
      dd.style.display = "none";
      toggle.setAttribute("aria-expanded", "false");
    }
    function open() {
      dd.style.display = "block";
      toggle.setAttribute("aria-expanded", "true");
    }

    toggle.addEventListener("click", (e) => {
      e.preventDefault();
      const isOpen = dd.style.display === "block";
      isOpen ? close() : open();
    });

    document.addEventListener("click", (e) => {
      if (!dd.contains(e.target) && !toggle.contains(e.target)) close();
    });
  }

  function wireDropdownNavButtons() {
    document.querySelectorAll(".dropdown-nav").forEach((btn) => {
      btn.addEventListener("click", () => {
        const target = btn.getAttribute("data-target");
        if (target) location.href = target;
      });
    });
  }

  function refreshHeader() {
    const cached = getCachedUser();
    if (cached) setLoggedInUI(cached);
    else setLoggedOutUI();
  }

  window.GSAuthHeader = {
    // Backwards compatible init() so older pages don't crash.
    // Usage: GSAuthHeader.init({ loginUrl, afterLogoutUrl })
    init(opts){
      try{
        if(opts?.loginUrl) LOGIN_URL = opts.loginUrl;
        if(opts?.afterLogoutUrl) AFTER_LOGOUT_URL = opts.afterLogoutUrl;
      }catch(_){ }
      refreshHeader();
    },
    setCachedUser,
    clearCachedUser,
    refreshHeader
  };

  wireDropdown();
  wireDropdownNavButtons();
  refreshHeader();

  window.addEventListener("storage", (e) => {
    if (e.key === KEY_USER) refreshHeader();
  });
})();
