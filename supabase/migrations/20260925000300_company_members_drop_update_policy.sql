-- company_members: no client updates
--
-- company_members_update_self let a user update any row where user_id = auth.uid(), including its
-- company_id. Anyone who owns a workspace (every landlord who signs up) could repoint their own
-- membership at another company and get full access to it through rg_company_access(). Tested in a
-- rolled-back transaction: one UPDATE exposed all 110 rent rows of another company.
--
-- No page updates memberships (they only insert right after creating a company), so the policy is
-- removed rather than patched. Role changes, when needed, should go through a SECURITY DEFINER
-- function that checks the caller owns the company.

drop policy if exists company_members_update_self on public.company_members;
