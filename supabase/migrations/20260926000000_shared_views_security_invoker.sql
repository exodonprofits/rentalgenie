-- Shared Supabase project: public views of the other GenieSphere products respect RLS
--
-- These 29 public views (Salon Genie, Arowana trading journal, household/vehicles, finance
-- summaries) were owned by postgres without security_invoker, so they bypassed row-level
-- security, and anon had SELECT on all but two. With only the public anon key anyone could read,
-- among others:
--   v_salon_employees            31 employees: email, phone, address, birthday, emergency
--                                contact, pay rates, login_username, login_pin, claim_code
--   option_trades_view /         1,308 / 1,168 trades with P&L and brokerage account
--   share_trades_view
--   v_inventory_items_enriched, v_vehicle_*, v_obligations_month_summary, v_salon_role_context
-- and any signed-in user could list every user's email, name and role via full_user_view.
--
-- None of these views is referenced by any page in rentalgenie, salongenie, arowanaprofits or
-- askgenie247 (the salon pages use same-named views in the salon schema). Edge Functions using
-- the service role are unaffected. Tested rolled back: the owner keeps the same rows on every view
-- with data (except v_salon_my_businesses 1->0 and v_salon_role_context 17->15, both unused), a
-- non-member user sees none of another account's rows, and anon is denied. full_user_view and
-- ai_usage_summary read auth.users, so they now return permission denied to everyone but the
-- service role; nothing uses them.
--
-- Recorded here because this repo holds the shared project's migration history. The salon
-- schema's own views are handled separately. Applied with the owner's approval.

alter view public.agent_most_used_today                 set (security_invoker = true);
alter view public.ai_usage_summary                      set (security_invoker = true);
alter view public.arowana_user_settings                 set (security_invoker = true);
alter view public.arowana_watchlist                     set (security_invoker = true);
alter view public.full_user_view                        set (security_invoker = true);
alter view public.inventory_reorder_needed              set (security_invoker = true);
alter view public.option_trades_view                    set (security_invoker = true);
alter view public.salon_vote_techs                      set (security_invoker = true);
alter view public.share_trades_view                     set (security_invoker = true);
alter view public.space_organizer_projects_with_results set (security_invoker = true);
alter view public.v_finance_by_agent_month_all          set (security_invoker = true);
alter view public.v_finance_by_workspace_month_all      set (security_invoker = true);
alter view public.v_finance_month_summary               set (security_invoker = true);
alter view public.v_finance_month_summary_all           set (security_invoker = true);
alter view public.v_finance_top_categories_month        set (security_invoker = true);
alter view public.v_finance_top_categories_month_all    set (security_invoker = true);
alter view public.v_inventory_items_enriched            set (security_invoker = true);
alter view public.v_journal_trade_candidates            set (security_invoker = true);
alter view public.v_obligations_due_next_7_days         set (security_invoker = true);
alter view public.v_obligations_month_summary           set (security_invoker = true);
alter view public.v_obligations_overdue                 set (security_invoker = true);
alter view public.v_salon_employees                     set (security_invoker = true);
alter view public.v_salon_my_businesses                 set (security_invoker = true);
alter view public.v_salon_role_context                  set (security_invoker = true);
alter view public.v_service_catalog                     set (security_invoker = true);
alter view public.v_technician_load_score               set (security_invoker = true);
alter view public.v_technician_week_current             set (security_invoker = true);
alter view public.v_vehicle_match_keys                  set (security_invoker = true);
alter view public.v_vehicle_renewal_badges              set (security_invoker = true);

revoke all on public.agent_most_used_today                 from anon;
revoke all on public.ai_usage_summary                      from anon;
revoke all on public.arowana_user_settings                 from anon;
revoke all on public.arowana_watchlist                     from anon;
revoke all on public.full_user_view                        from anon;
revoke all on public.inventory_reorder_needed              from anon;
revoke all on public.option_trades_view                    from anon;
revoke all on public.salon_vote_techs                      from anon;
revoke all on public.share_trades_view                     from anon;
revoke all on public.space_organizer_projects_with_results from anon;
revoke all on public.v_finance_by_agent_month_all          from anon;
revoke all on public.v_finance_by_workspace_month_all      from anon;
revoke all on public.v_finance_month_summary               from anon;
revoke all on public.v_finance_month_summary_all           from anon;
revoke all on public.v_finance_top_categories_month        from anon;
revoke all on public.v_finance_top_categories_month_all    from anon;
revoke all on public.v_inventory_items_enriched            from anon;
revoke all on public.v_journal_trade_candidates            from anon;
revoke all on public.v_obligations_due_next_7_days         from anon;
revoke all on public.v_obligations_month_summary           from anon;
revoke all on public.v_obligations_overdue                 from anon;
revoke all on public.v_salon_employees                     from anon;
revoke all on public.v_salon_my_businesses                 from anon;
revoke all on public.v_salon_role_context                  from anon;
revoke all on public.v_service_catalog                     from anon;
revoke all on public.v_technician_load_score               from anon;
revoke all on public.v_technician_week_current             from anon;
revoke all on public.v_vehicle_match_keys                  from anon;
revoke all on public.v_vehicle_renewal_badges              from anon;
