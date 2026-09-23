// rental-header.js

const SUPABASE_URL = 'https://pbojacnagutipfhcxltj.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBib2phY25hZ3V0aXBmaGN4bHRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgwMDkwODAsImV4cCI6MjA2MzU4NTA4MH0.ZLCcAzTYljoZycpBGwMtthP5VyAJ4schuIvt4HibGc0';

// ✅ Create ONE shared Supabase client in this tab
if (!window.supabaseClient) {
  window.supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}
const supabaseClient = window.supabaseClient;

async function loadHeader() {
  const placeholder = document.getElementById('header-placeholder');
  if (!placeholder) return;

  try {
    const resp = await fetch('rental-header.html');
    const html = await resp.text();
    placeholder.innerHTML = html;
    wireNavLinks();
    await setupAuthControls();
  } catch (e) {
    console.error('Error loading rental header:', e);
  }
}

// Turn top nav links into working links
function wireNavLinks() {
  const map = {
    'nav-dashboard': 'index.html',
    'nav-properties': 'manage-properties.html',
    'nav-leases': 'lease-center.html',
    'nav-rent': 'rent-payments.html',
    'nav-maintenance': 'maintenance-requests.html',
    'nav-reports': 'reports.html'
  };

  Object.entries(map).forEach(([id, href]) => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener('click', (e) => {
        e.preventDefault();
        window.location.href = href;
      });
    }
  });

  // Login link – goes to login.html with redirect back to current page
  const loginLink = document.getElementById('nav-login');
  if (loginLink) {
    loginLink.addEventListener('click', (e) => {
      e.preventDefault();
      const redirect = encodeURIComponent(window.location.pathname.replace(/^.*\//, '') + window.location.search);
      window.location.href = 'login.html?redirect=' + redirect;
    });
  }

  // Simple "Log out" in account menu (optional)
  const logoutLink = document.getElementById('nav-logout');
  if (logoutLink) {
    logoutLink.addEventListener('click', async (e) => {
      e.preventDefault();
      try {
        await supabaseClient.auth.signOut();
        window.location.href = 'login.html';
      } catch (err) {
        console.error('Error signing out:', err);
      }
    });
  }
}

// Show username instead of "Log in" when authenticated
async function setupAuthControls() {
  if (!supabaseClient) {
    console.error('supabaseClient not ready in header');
    return;
  }

  const loginLink = document.getElementById('nav-login');
  const userMenu  = document.getElementById('nav-user-menu');
  const userNameEl = document.getElementById('nav-username');

  try {
    const { data, error } = await supabaseClient.auth.getUser();
    const user = data?.user || null;

    if (error) {
      console.error('Error checking auth in header:', error);
    }

    if (user) {
      // logged in
      if (loginLink) loginLink.style.display = 'none';
      if (userMenu)  userMenu.style.display  = 'flex';
      if (userNameEl) userNameEl.textContent = user.email || 'Account';
    } else {
      // logged out
      if (loginLink) loginLink.style.display = 'inline-flex';
      if (userMenu)  userMenu.style.display  = 'none';
    }
  } catch (e) {
    console.error('Unexpected auth error in header:', e);
  }
}

document.addEventListener('DOMContentLoaded', loadHeader);
