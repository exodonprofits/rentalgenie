-- Rental Genie views: respect row-level security
--
-- These views were owned by postgres without security_invoker, so they ran with the owner's rights
-- and bypassed RLS, and anon/authenticated had SELECT on them. Anyone with the public anon key (it
-- ships in every page) could read every company's rent payments, leases (tenant names and emails),
-- properties, expenses and maintenance requests. Tested: anon saw 110 rent rows, 11 leases, 12
-- expenses, 6 requests, 7 properties.
--
-- With security_invoker the base tables' RLS applies to whoever queries the view, and anon loses
-- access entirely. No page used these views. public_listings stays definer on purpose: it exposes
-- only listing fields of properties the owner published.

alter view public.active_companies            set (security_invoker = true);
alter view public.active_expenses             set (security_invoker = true);
alter view public.active_leases               set (security_invoker = true);
alter view public.active_maintenance_requests set (security_invoker = true);
alter view public.active_properties           set (security_invoker = true);
alter view public.active_rent_log             set (security_invoker = true);
alter view public.property_monthly_costs      set (security_invoker = true);

revoke all on public.active_companies            from anon;
revoke all on public.active_expenses             from anon;
revoke all on public.active_leases               from anon;
revoke all on public.active_maintenance_requests from anon;
revoke all on public.active_properties           from anon;
revoke all on public.active_rent_log             from anon;
revoke all on public.property_monthly_costs      from anon;
