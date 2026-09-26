-- Shared Supabase project: remove catch-all policies that opened tables to everyone
--
-- Row-level security is on for every exposed table (only two tables in the private backup schema
-- have it off). The exposure came from permissive "true" policies: RLS grants access if ANY
-- policy matches, so a catch-all cancelled the scoped policies next to it.
--
--   _deprecated_employees    anon could read, update and DELETE 18 staff rows (PII, pay, login PINs)
--   _deprecated_tickets      anon read/insert/update, 47 rows
--   _deprecated_customers    anon read/write, 6 customers (name, phone, email)
--     -> unused by any page: every policy dropped; RLS on with no policy = service role only.
--   checkins                 anon and every signed-in user could do anything (customer names, phones)
--     -> staff of the row's salon only (salon.sg_has_access: owner, active employee, member).
--   day_off_requests         anyone could read/insert; "owner read all" let ANY salon owner read
--                            every salon's requests; no UPDATE policy, so approve/deny never worked
--     -> owners/managers of that salon read and approve (salon.can_manage_business); staff keep
--        "read own" / "insert own".
--   payment_settings         any signed-in user could read every landlord's Venmo/Zelle (Rental Genie)
--     -> the landlord's company (rg_company_access) or a tenant with a live lease with that company.
--   gift_cards, gift_card_transactions   any signed-in user could read codes and balances
--     -> staff of that salon only.
--   trip_shares              anyone could read invite tokens -> existing owner/invitee policies only.
--   salon_turn_vote          anon could update votes (table unused) -> update policy dropped.
--
-- Tested rolled back as the Victoria Nails business owner, an owner-role employee, a nail tech, a
-- receptionist, another salon's owner, a Rental Genie tenant and anon, then applied with the
-- owner's approval. Results: VN staff keep all 32 check-ins, everyone else 0; the landlord and
-- their tenant read payment_settings, nobody else; a VN time-off request is seen and approvable by
-- the VN owner and owner-role employee, seen (not approvable) by the tech who filed it, invisible to
-- the receptionist, the other salon, the tenant; staff can file their own request but not
-- someone else's. The one existing time-off row has no salon or user (a test row) and is now
-- visible only to the service role.

-- Deprecated tables: drop every policy
do $$
declare p record;
begin
  for p in select policyname, tablename from pg_policies
            where schemaname = 'public'
              and tablename in ('_deprecated_employees', '_deprecated_tickets', '_deprecated_customers') loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- checkins
drop policy if exists checkins_anon_all on public.checkins;
drop policy if exists checkins_all_authenticated on public.checkins;
drop policy if exists checkins_business_staff on public.checkins;
create policy checkins_business_staff on public.checkins
  for all to authenticated
  using (salon.sg_has_access(business_id))
  with check (salon.sg_has_access(business_id));

-- day_off_requests
drop policy if exists "Allow all select" on public.day_off_requests;
drop policy if exists "Allow insert for all" on public.day_off_requests;
drop policy if exists "owner read all day off" on public.day_off_requests;
drop policy if exists day_off_managers_read on public.day_off_requests;
drop policy if exists day_off_managers_update on public.day_off_requests;
create policy day_off_managers_read on public.day_off_requests
  for select to authenticated
  using (salon.can_manage_business(business_id));
create policy day_off_managers_update on public.day_off_requests
  for update to authenticated
  using (salon.can_manage_business(business_id))
  with check (salon.can_manage_business(business_id));

-- payment_settings (Rental Genie)
create or replace function public.rg_is_tenant_of_company(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select p_company_id is not null and public.rg_auth_email() is not null and exists (
    select 1 from public.leases l
     where l.company_id = p_company_id
       and l.archived_at is null
       and lower(l.tenant_email) = lower(public.rg_auth_email()));
$$;
revoke all on function public.rg_is_tenant_of_company(uuid) from public, anon;
grant execute on function public.rg_is_tenant_of_company(uuid) to authenticated;

drop policy if exists "authenticated users can read payment settings" on public.payment_settings;
drop policy if exists payment_settings_read_team_or_tenant on public.payment_settings;
create policy payment_settings_read_team_or_tenant on public.payment_settings
  for select to authenticated
  using (public.rg_company_access(company_id) or public.rg_is_tenant_of_company(company_id));

-- gift cards
drop policy if exists staff_read_gift_cards on public.gift_cards;
drop policy if exists gift_cards_business_staff_read on public.gift_cards;
create policy gift_cards_business_staff_read on public.gift_cards
  for select to authenticated
  using (salon.sg_has_access(business_id));

drop policy if exists staff_read_gift_card_transactions on public.gift_card_transactions;
drop policy if exists authenticated_read_gift_transactions on public.gift_card_transactions;
drop policy if exists gift_card_tx_business_staff_read on public.gift_card_transactions;
create policy gift_card_tx_business_staff_read on public.gift_card_transactions
  for select to authenticated
  using (salon.sg_has_access(business_id));

-- trip_shares, salon_turn_vote
drop policy if exists trip_shares_read_all on public.trip_shares;
drop policy if exists "allow public update" on public.salon_turn_vote;
