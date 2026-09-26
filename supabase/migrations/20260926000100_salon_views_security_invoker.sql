-- Shared Supabase project: salon schema views stop leaking across salons
--
-- These salon views were owned by postgres without security_invoker, so they bypassed row-level
-- security. anon had no access, but ANY signed-in user (a Rental Genie tenant, another salon's
-- owner) could read every salon's rows: 241 task assignments, 31 employee role profiles, message
-- threads, inventory, color stock, and every user's business and role.
--
-- 1. Fourteen views become security_invoker, so the salon tables' own RLS applies. Tested rolled
--    back as the Victoria Nails business owner, an owner-role employee, a nail tech, a
--    receptionist, another salon's owner and a non-salon user:
--      v_task_assignments_live, color_inventory_view, inventory_usage_velocity,
--      inventory_items_enriched, v_employee_role_profile: Victoria Nails staff keep the same rows;
--        the other salon and the outsider drop to 0.
--      v_features_for_business, v_shades_for_business: each user sees only their own salons'
--        rows (manage-features filters by salon anyway).
--      my_salons, my_salon_plan, my_work_tasks, qbo_sync_status, recent_usage_enriched,
--        v_marketing_inbox_counts: unchanged (they already filter by auth.uid()).
--      message_threads (unused by any page): staff keep 3 threads; the business-owner login that
--        isn't an employee row loses them (the table's RLS doesn't cover that account).
-- 2. v_user_role_context reads auth.users, so security_invoker would break it. It stays definer
--    and now returns only the caller's own row (WHERE o.user_id = auth.uid()). Tested: every
--    user gets exactly one row, their own, with the right role. That also fixes
--    employee-profile.html, whose .maybeSingle() read failed on 37 rows.
--
-- Applied with the owner's approval. Recorded here because this repo holds the shared project's
-- migration history.

alter view salon.color_inventory_view      set (security_invoker = true);
alter view salon.inventory_items_enriched  set (security_invoker = true);
alter view salon.inventory_usage_velocity  set (security_invoker = true);
alter view salon.message_threads           set (security_invoker = true);
alter view salon.my_salon_plan             set (security_invoker = true);
alter view salon.my_salons                 set (security_invoker = true);
alter view salon.my_work_tasks             set (security_invoker = true);
alter view salon.qbo_sync_status           set (security_invoker = true);
alter view salon.recent_usage_enriched     set (security_invoker = true);
alter view salon.v_employee_role_profile   set (security_invoker = true);
alter view salon.v_features_for_business   set (security_invoker = true);
alter view salon.v_marketing_inbox_counts  set (security_invoker = true);
alter view salon.v_shades_for_business     set (security_invoker = true);
alter view salon.v_task_assignments_live   set (security_invoker = true);

create or replace view salon.v_user_role_context as
 WITH prefs AS (
         SELECT up.user_id,
            COALESCE(up.selected_business_id, up.active_business_id) AS active_business_id
           FROM public.user_preferences up
        ), active_business AS (
         SELECT u.id AS user_id,
            COALESCE(p.active_business_id, owned.first_owned_business_id) AS business_id
           FROM auth.users u
             LEFT JOIN prefs p ON p.user_id = u.id
             LEFT JOIN LATERAL ( SELECT bp_1.id AS first_owned_business_id
                   FROM public.business_profiles bp_1
                  WHERE bp_1.owner_id = u.id
                  ORDER BY bp_1.created_at DESC NULLS LAST
                 LIMIT 1) owned ON true
        ), ownership AS (
         SELECT ab.user_id,
            ab.business_id,
            bp_1.owner_id = ab.user_id AS is_owner
           FROM active_business ab
             LEFT JOIN public.business_profiles bp_1 ON bp_1.id = ab.business_id
        ), staff AS (
         SELECT e.user_id,
            e.business_id,
            lower(regexp_replace(e.role, '\s+'::text, '_'::text, 'g'::text)) AS staff_role
           FROM salon.employees e
          WHERE e.user_id IS NOT NULL
        )
 SELECT o.user_id,
    o.business_id,
    bp.business_name,
    bp.location,
    o.is_owner,
    s.staff_role,
        CASE
            WHEN o.is_owner THEN 'owner'::text
            WHEN s.staff_role IS NOT NULL THEN s.staff_role
            ELSE 'staff'::text
        END AS effective_role
   FROM ownership o
     LEFT JOIN staff s ON s.user_id = o.user_id AND s.business_id = o.business_id
     LEFT JOIN public.business_profiles bp ON bp.id = o.business_id
  WHERE o.user_id = auth.uid();
