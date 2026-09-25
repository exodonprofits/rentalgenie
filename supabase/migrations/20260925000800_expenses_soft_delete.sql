-- expenses: soft delete only
--
-- Pages hard-deleted expenses (expense-tracking, add-expense), so a mis-click erased a tax record
-- with no way back. archive_expense / unarchive_expense already existed but nothing called them.
--   * Both now check rg_company_access() (owner or member, like every other RLS check) instead of
--     is_company_member(), which ignored owners without a membership row. anon can't call them.
--   * A restrictive policy blocks DELETE for signed-in users, so a hard delete can't happen from a
--     page even by mistake. The service role (SQL editor, Edge Functions) is unaffected.
-- Pages call archive_expense and filter archived_at is null when reading.

create or replace function public.archive_expense(p_expense_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $f$
declare v_company_id uuid;
begin
  select company_id into v_company_id from public.expenses where id = p_expense_id;
  if v_company_id is null or not public.rg_company_access(v_company_id) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  update public.expenses set archived_at = now(), archived_by = auth.uid()
   where id = p_expense_id and archived_at is null;
end $f$;

create or replace function public.unarchive_expense(p_expense_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $f$
declare v_company_id uuid;
begin
  select company_id into v_company_id from public.expenses where id = p_expense_id;
  if v_company_id is null or not public.rg_company_access(v_company_id) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  update public.expenses set archived_at = null, archived_by = null where id = p_expense_id;
end $f$;

revoke all on function public.archive_expense(integer) from public, anon;
revoke all on function public.unarchive_expense(integer) from public, anon;
grant execute on function public.archive_expense(integer) to authenticated;
grant execute on function public.unarchive_expense(integer) to authenticated;

drop policy if exists expenses_no_hard_delete on public.expenses;
create policy expenses_no_hard_delete on public.expenses
  as restrictive for delete to authenticated
  using (false);
