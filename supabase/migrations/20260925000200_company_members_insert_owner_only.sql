-- company_members: only a company's owner can add themselves as a member
--
-- The insert policy only checked user_id = auth.uid(), so any signed-in user could insert a
-- membership row for ANY company_id. rg_company_access() trusts company_members, so that one insert
-- granted full read/write on the company: every property, lease, tenant, rent payment and expense.
-- A tenant already sees their landlord's company_id on their own lease row, so a tenant could make
-- themselves a co-owner of the landlord's account.
--
-- Pages insert a membership only right after creating a company, and rg_set_company_owner() sets
-- owner_user_id = auth.uid() on that insert, so this still works. There is no team-invite flow; when
-- one is built it should go through a SECURITY DEFINER function that checks the inviter.
-- All existing membership rows belonged to the owner and are unaffected.

drop policy if exists company_members_insert_self on public.company_members;

create policy company_members_insert_self on public.company_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.companies c
      where c.id = company_id and c.owner_user_id = auth.uid()
    )
  );
