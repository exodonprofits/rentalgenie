-- Shared Supabase project: business_profiles public columns only; lock follow_up_requests
--
-- business_profiles: bp_anon_public_read let anyone with the anon key read every column of all 7
-- businesses, including owner_id / owner_user_id, email, business_google_email, notes and
-- company_id. Salon Genie's public pages (book, find-salon, tip, client-portal, check-in kiosk,
-- mobile check-in, login, demo, select-salon) need only a few public columns, so anon now has
-- column-level SELECT on those alone. Signed-in staff and owners keep full access through their
-- own policies. Tested rolled back as anon with each public page's exact query: all work; owner
-- IDs, emails, notes and company_id are denied. An anon `select *` now fails; no public page does
-- that (business-profile.html's select * is a signed-in owner page).
--
-- follow_up_requests: empty, tied to _deprecated_customers, and its only writer (qr-checkout.html)
-- inserts a `phone` column that doesn't exist, so it has never worked. The "any signed-in user can
-- do anything" policy is dropped; service role only until it is rebuilt with a salon column.
--
-- Applied with the owner's approval.

revoke select on public.business_profiles from anon;
grant select (id, business_name, location, phone, business_hours, hours, logo_url, is_listed,
              website, tagline, industry, business_type, google_place_id)
  on public.business_profiles to anon;

drop policy if exists followups_staff_all on public.follow_up_requests;
