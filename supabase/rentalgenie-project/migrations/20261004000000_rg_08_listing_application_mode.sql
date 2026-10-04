-- db: per-property application mode, and applications only where the listing takes them.
--
-- 1. properties.listing_application_mode: how renters apply to a public listing.
--      rental_genie  the Rental Genie application form on listings.html (default, today's behaviour)
--      external      a link to the landlord's own application (listing_application_url, http/https)
--      contact       no application; renters contact the landlord (listing_contact_email/phone)
--    public_listings exposes both columns so the public page can show the right button.
--
-- 2. "public can submit applications" was WITH CHECK (true): anyone could file an application
--    against any property, listed or not, and set any column, including a "completed"
--    screening_status, a screening_report_url, or another user's applicant_user_id. Inserts now
--    need a public, non-archived listing in rental_genie mode, and start as a plain submission:
--    status 'submitted', screening untouched, no tenant link, applicant_user_id empty or the
--    caller. listings.html already sends exactly that.
--
-- 3. anon had no INSERT grant on applications at all (in the shared project too), so the
--    public form failed with "permission denied" for anyone not signed in. anon now gets
--    INSERT on the applicant's own columns only; status, screening, tenant and user links
--    stay at their defaults even for a hand-made request.

alter table public.properties
  add column if not exists listing_application_mode text not null default 'rental_genie',
  add column if not exists listing_application_url text;

alter table public.properties
  add constraint properties_listing_application_mode_check
    check (listing_application_mode in ('rental_genie', 'external', 'contact')),
  add constraint properties_listing_application_url_check
    check (listing_application_url is null or listing_application_url ~* '^https?://[^[:space:]"''<>]+$'),
  add constraint properties_listing_external_needs_url_check
    check (listing_application_mode <> 'external' or listing_application_url is not null);

-- Appends two columns; the existing ones keep their order.
create or replace view public.public_listings as
 SELECT p.id,
    p.name,
    p.address,
    p.property_type,
    p.units,
    p.bedrooms,
    p.bathrooms,
    p.square_feet,
    p.year_built,
    p.listing_rent,
    p.listing_deposit,
    p.listing_available_date,
    p.listing_description,
    p.listing_photos,
    p.listing_pet_policy,
    p.listing_contact_email,
    p.listing_contact_phone,
    p.listing_published_at,
    p.listing_application_mode,
    p.listing_application_url
   FROM properties p
  WHERE p.is_public_listing = true;

-- anon can't read properties under RLS, so the policy asks through a definer function.
create or replace function public.rg_listing_accepts_applications(p_property_id uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
 set row_security to 'off'
as $function$
  select exists (
    select 1 from public.properties
    where id = p_property_id
      and is_public_listing = true
      and archived_at is null
      and listing_application_mode = 'rental_genie'
  );
$function$;

revoke all on function public.rg_listing_accepts_applications(uuid) from public;
grant execute on function public.rg_listing_accepts_applications(uuid) to anon, authenticated;

-- Altered in place: the policy keeps its name, roles (anon, authenticated) and command (insert).
alter policy "public can submit applications" on public.applications
  with check (
    status = 'submitted'
    and screening_status = 'not_requested'
    and screening_report_url is null
    and screening_requested_at is null
    and tenant_id is null
    and (applicant_user_id is null or applicant_user_id = auth.uid())
    and public.rg_listing_accepts_applications(property_id)
  );

grant insert (
  property_id, property_name, property_address,
  applicant_name, applicant_email, applicant_phone, desired_move_in, household_size, message,
  current_address, employer_name, employment_status, monthly_income, occupants_count,
  has_pets, pet_details, emergency_contact_name, emergency_contact_phone, screening_consent
) on public.applications to anon;
