(function(){
  const LOGIN_URL = "/onboarding/login.html";

  const qs = (sel, root=document)=>root.querySelector(sel);
  const qsa = (sel, root=document)=>Array.from(root.querySelectorAll(sel));
  const safeOn = (el, evt, fn)=>{ if(el) el.addEventListener(evt, fn); };

  async function loadPartial(intoId, url){
    const host = document.getElementById(intoId);
    if(!host) return;
    try{
      const res = await fetch(url, {cache:"no-store"});
      if(!res.ok) throw new Error("HTTP "+res.status);
      host.innerHTML = await res.text();
    }catch(err){
      console.warn("Partial load failed:", url, err);
    }
  }

  function setActiveNav(){
    const path = (location.pathname || "").split("/").pop() || "index.html";
    const map = {
      "index.html":"dashboard",
      "property-management.html":"properties",
      "manage-properties.html":"properties",
      "add-property.html":"properties",
      "lease-rent-center.html":"leases",
      "lease-form.html":"leases",
      "view-lease.html":"leases",
      "rent-log.html":"leases",
      "payments.html":"leases",
      "expense-tracking.html":"expenses",
      "maintenance-requests.html":"maintenance",
      "reports-analytics.html":"reports"
    };
    const key = map[path] || "";
    qsa('[data-nav]').forEach(a=>{
      if(!key) return;
      if(a.getAttribute('data-nav') === key) a.classList.add('active');
      else a.classList.remove('active');
    });
  }

  function wireDrawer(){
    const btn = qs("#hamburgerBtn");
    const drawer = qs("#mobileDrawer");
    const backdrop = qs("#drawerBackdrop");

    const open = ()=>{
      if(!drawer || !backdrop) return;
      drawer.classList.add("open");
      backdrop.classList.add("open");
      drawer.setAttribute("aria-hidden","false");
      backdrop.setAttribute("aria-hidden","false");
      document.documentElement.style.overflow = "hidden";
    };

    const close = ()=>{
      if(!drawer || !backdrop) return;
      drawer.classList.remove("open");
      backdrop.classList.remove("open");
      drawer.setAttribute("aria-hidden","true");
      backdrop.setAttribute("aria-hidden","true");
      document.documentElement.style.overflow = "";
    };

    safeOn(btn, "click", ()=> (drawer && drawer.classList.contains("open")) ? close() : open());
    safeOn(backdrop, "click", close);
    document.addEventListener("keydown", (e)=>{ if(e.key==="Escape") close(); });
  }

  function wireUserDropdown(){
    const pill = qs("#userPill");
    const dd = qs("#userDropdown");
    if(!pill || !dd) return;

    const close = ()=> dd.style.display = "none";
    const toggle = ()=>{
      dd.style.display = (dd.style.display==="block") ? "none" : "block";
    };

    safeOn(pill, "click", (e)=>{ e.preventDefault(); e.stopPropagation(); toggle(); });
    document.addEventListener("click", ()=> close());
  }

  function setAuthUI(session){
    const user = session?.user || null;
    const authed = !!user;
    const email = user?.email || "User";
    const name = user?.user_metadata?.full_name || user?.user_metadata?.name || email;

    const u1 = qs("#usernameLabel");
    const u2 = qs("#mobileUsernameLabel");
    if(u1) u1.textContent = name;
    if(u2) u2.textContent = name;

    const loginA = qs("#mobileLogin");
    const logoutWrap = qs("#mobileLogoutContainer");
    if(loginA) loginA.style.display = authed ? "none" : "block";
    if(logoutWrap) logoutWrap.style.display = authed ? "block" : "none";

    const accountLink = qs("#mobileAccountLink");
    if(accountLink) accountLink.style.display = authed ? "block" : "none";
  }

  async function initAuth(){
    // Load config (shared config.json)
    const cfg = await (window.GSConfig?.getConfigPromise?.() || Promise.resolve(null));
    if(!cfg || !cfg.supabaseUrl || !cfg.supabaseAnonKey){
      console.error("Missing supabase config. Ensure /shared/config.json is reachable and /shared/js/app-config.js loaded.");
      return { session: null, client: null };
    }

    // Single client instance
    if(!window.sb){
      if(!window.supabase?.createClient){
        console.error("Supabase JS not loaded.");
        return { session: null, client: null };
      }
      window.sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      });
    }

    const sb = window.sb;

    // Validate session
    const { data } = await sb.auth.getSession();
    const session = data?.session || null;

    // Keep GSAuthHeader cache in sync (if your system uses it)
    if(session?.user?.email && window.GSAuthHeader?.setCachedUser){
      window.GSAuthHeader.setCachedUser({ email: session.user.email, name: session.user.user_metadata?.full_name || session.user.email });
    }

    // Auth changes
    sb.auth.onAuthStateChange((_evt, newSession)=>{
      setAuthUI(newSession);
      setActiveNav();
      if(!newSession?.user){
        // If user logs out elsewhere, send to login
        if(!location.pathname.endsWith("login.html")) location.href = LOGIN_URL;
      }
    });

    return { session, client: sb };
  }

  function wireLogout(){
    const doLogout = async ()=>{
      try{
        if(window.sb) await window.sb.auth.signOut();
      }catch(e){
        console.warn("Logout error", e);
      }finally{
        location.href = LOGIN_URL;
      }
    };
    safeOn(qs("#logoutBtn"), "click", (e)=>{ e.preventDefault(); doLogout(); });
    safeOn(qs("#mobileLogoutBtn"), "click", (e)=>{ e.preventDefault(); doLogout(); });
  }

  async function boot(){
    // Inject shared header/footer
    await loadPartial("gsHeader", "/shared/partials/rental-header.html");
    await loadPartial("gsFooter", "/shared/partials/rental-footer.html");

    // Wire UI behaviors
    wireDrawer();
    wireUserDropdown();
    setActiveNav();
    wireLogout();

    // Auth (redirect if required)
    const { session } = await initAuth();
    setAuthUI(session);

    // If this page requires auth, redirect (most Rental Genie pages do)
    const isPublic = document.body?.hasAttribute("data-public");
    if(!isPublic && !session?.user){
      location.href = LOGIN_URL;
      return;
    }

    // Optional: allow pages to hook post-auth
    if(typeof window.pageBoot === "function"){
      await window.pageBoot(session);
    }
  }

  document.addEventListener("DOMContentLoaded", boot);
})();
