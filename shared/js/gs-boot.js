// /shared/js/gs-boot.js
// Enterprise boot loader for Rental Genie / GenieSphere apps
// Purpose:
// - wait for app-config.js
// - wait for sb-client.js
// - optionally refresh auth header
// - provide one stable boot promise for all pages

(function () {
  "use strict";

  let _bootPromise = null;

  function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async function waitFor(checkFn, {
    timeout = 8000,
    interval = 40,
    name = "resource"
  } = {}) {
    const start = Date.now();

    while (Date.now() - start < timeout) {
      try {
        const result = await checkFn();
        if (result) return result;
      } catch (_) {
        // keep waiting
      }
      await sleep(interval);
    }

    throw new Error(`[GSBoot] Timed out waiting for ${name}`);
  }

  async function waitForConfig() {
    return waitFor(
      async () => {
        if (!window.GSConfig || typeof window.GSConfig.getConfigPromise !== "function") {
          return null;
        }
        const cfg = await window.GSConfig.getConfigPromise();
        if (!cfg?.supabaseUrl || !cfg?.supabaseAnonKey) return null;
        return cfg;
      },
      { name: "GSConfig" }
    );
  }

  async function waitForSbClient() {
    return waitFor(
      async () => {
        if (typeof window.getSbClient === "function") {
          const sb = await window.getSbClient();
          if (sb) return sb;
        }

        if (window.sb) return window.sb;
        if (window.GS?.sb) return window.GS.sb;
        if (window.GSClient?.getAsync) {
          const sb = await window.GSClient.getAsync();
          if (sb) return sb;
        }

        return null;
      },
      { name: "Supabase client" }
    );
  }

  async function refreshHeaderSafe() {
    try {
      if (window.GSAuthHeader && typeof window.GSAuthHeader.refreshHeader === "function") {
        await window.GSAuthHeader.refreshHeader();
      }
    } catch (_) {
      // non-fatal
    }
  }

  async function boot() {
    if (_bootPromise) return _bootPromise;

    _bootPromise = (async () => {
      const config = await waitForConfig();
      const sb = await waitForSbClient();

      await refreshHeaderSafe();

      const api = {
        config,
        sb,
        user: null
      };

      try {
        const { data } = await sb.auth.getUser();
        api.user = data?.user || null;
      } catch (_) {
        api.user = null;
      }

      return api;
    })();

    return _bootPromise;
  }

  window.GSBoot = {
    ready: boot,
    getClient: waitForSbClient,
    getConfig: waitForConfig
  };
})();