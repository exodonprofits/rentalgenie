-- functions (bodies checked at first call; several reference each other out of order)
set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.archive_expense(p_expense_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id from public.expenses where id = p_expense_id;
  if v_company_id is null or not public.rg_company_access(v_company_id) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  update public.expenses set archived_at = now(), archived_by = auth.uid()
   where id = p_expense_id and archived_at is null;
end $function$
;

CREATE OR REPLACE FUNCTION public.archive_lease(p_lease_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.leases
  where id = p_lease_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.leases
  set archived_at = now(),
      archived_by = auth.uid()
  where id = p_lease_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.archive_maintenance_request(p_request_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.maintenance_requests
  where id = p_request_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.maintenance_requests
  set archived_at = now(),
      archived_by = auth.uid()
  where id = p_request_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.archive_property(p_property_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.properties
  where id = p_property_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.properties
  set archived_at = now(),
      archived_by = auth.uid()
  where id = p_property_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.archive_rent_log(p_rent_log_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.rent_log
  where id = p_rent_log_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.rent_log
  set archived_at = now(),
      archived_by = auth.uid()
  where id = p_rent_log_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_unpublish_listing()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.occupancy_status is distinct from 'vacant'
     and new.is_public_listing = true
     and (new.listing_available_date is null or new.listing_available_date <= current_date) then
    new.is_public_listing := false;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.block_tenant_email_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.email is distinct from old.email then
    raise exception 'Tenant email cannot be changed.';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_my_applications()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  my_email text;
  claimed_count int;
begin
  select email into my_email from auth.users where id = auth.uid();
  if my_email is null then
    return 0;
  end if;

  update public.applications
    set applicant_user_id = auth.uid()
    where applicant_user_id is null
      and lower(applicant_email) = lower(my_email);

  get diagnostics claimed_count = row_count;
  return claimed_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.is_company_member(p_company_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  select exists (
    select 1
    from public.company_members cm
    where cm.company_id = p_company_id
      and cm.user_id = auth.uid()
  );
$function$
;

CREATE OR REPLACE FUNCTION public.rg_auth_email()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select lower(coalesce(auth.email(), auth.jwt() ->> 'email'));
$function$
;

CREATE OR REPLACE FUNCTION public.rg_can_access_property(p_property_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select exists (
    select 1 from public.properties p
    where p.id = p_property_id
      and (p.owner_id = auth.uid() or public.rg_company_access(p.company_id))
  );
$function$
;

CREATE OR REPLACE FUNCTION public.rg_cascade_property_rename()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
begin
  if new.name is not distinct from old.name then return null; end if;
  update public.leases                 set property_name = new.name where property_id = new.id;
  update public.rent_log               set property_name = new.name where property_id = new.id;
  update public.expenses               set property_name = new.name where property_id = new.id;
  update public.maintenance_requests   set property_name = new.name where property_id = new.id;
  update public.applications           set property_name = new.name where property_id = new.id;
  update public.hoa_history            set property_name = new.name where property_id = new.id;
  update public.property_hoa           set property_name = new.name where property_id = new.id;
  update public.incoming_rent_payments set property_name = new.name where property_id = new.id;
  update public.reimbursement_requests set property_name = new.name where property_id = new.id;
  update public.tenant_documents set property_name = new.name
   where property_id = new.id or (property_id is null and company_id = new.company_id and property_name = old.name);
  update public.tenant_messages set property_name = new.name
   where property_id = new.id or (property_id is null and company_id = new.company_id and property_name = old.name);
  update public.tenants t set property_name = new.name
   where t.property_name = old.name
     and exists (select 1 from public.leases l where l.property_id = new.id and lower(l.tenant_email) = lower(t.email));
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_company_access(p_company_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select p_company_id is not null and (
    exists (select 1 from public.company_members m
            where m.company_id = p_company_id and m.user_id = auth.uid())
    or exists (select 1 from public.companies c
               where c.id = p_company_id and c.owner_user_id = auth.uid())
  );
$function$
;

CREATE OR REPLACE FUNCTION public.rg_confirm_incoming_payment(p_id uuid, p_property_id uuid DEFAULT NULL::uuid, p_due_date date DEFAULT NULL::date, p_remember boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_in        public.incoming_rent_payments%rowtype;
  v_prop      uuid;
  v_pname     text;
  v_tenant    text;
  v_left      numeric;
  v_ids       uuid[] := '{}';
  v_new       uuid;
  r           record;
  v_last_due  date;
  v_due_day   int;
  v_rent      numeric;
  v_next      date;
  v_chunk     numeric;
  v_i         int := 0;
begin
  select * into v_in from public.incoming_rent_payments where id = p_id for update;
  if not found then raise exception 'Payment not found'; end if;
  if v_in.status <> 'pending' then raise exception 'Payment is already %', v_in.status; end if;

  v_prop := coalesce(p_property_id, v_in.property_id);
  if v_prop is null then raise exception 'Choose a property for this payment'; end if;

  select p.name into v_pname from public.properties p where p.id = v_prop;
  select s.tenant_name into v_tenant
  from public.rg_rent_status(v_in.company_id, coalesce(v_in.date_paid, current_date)) s
  where s.property_id = v_prop;

  v_left := v_in.amount;

  if p_due_date is not null then
    insert into public.rent_log (company_id, property_id, property_name, tenant_name, amount, date_paid,
                                 method, applied_to_due_date, note, source, incoming_payment_id)
    values (v_in.company_id, v_prop, v_pname, v_tenant, v_left, v_in.date_paid, v_in.method, p_due_date,
            nullif(concat_ws(' · ', v_in.memo, 'from ' || v_in.tenant_name), ''), 'email', v_in.id)
    returning id into v_new;
    v_ids := v_ids || v_new;
    v_left := 0;
  else
    for r in
      select s.due_date, s.balance
      from public.rg_rent_schedule(v_in.company_id, coalesce(v_in.date_paid, current_date)) s
      where s.property_id = v_prop and s.balance > 0.01
      order by s.due_date
    loop
      exit when v_left <= 0.01;
      insert into public.rent_log (company_id, property_id, property_name, tenant_name, amount, date_paid,
                                   method, applied_to_due_date, note, source, incoming_payment_id)
      values (v_in.company_id, v_prop, v_pname, v_tenant, least(v_left, r.balance), v_in.date_paid,
              v_in.method, r.due_date,
              nullif(concat_ws(' · ', v_in.memo, 'from ' || v_in.tenant_name), ''), 'email', v_in.id)
      returning id into v_new;
      v_ids := v_ids || v_new;
      v_left := v_left - least(v_left, r.balance);
    end loop;

    if v_left > 0.01 then
      select max(s.due_date), max(s.due_day), max(s.rent_amount)
        into v_last_due, v_due_day, v_rent
        from public.rg_rent_schedule(v_in.company_id, coalesce(v_in.date_paid, current_date)) s
       where s.property_id = v_prop;

      v_next := v_last_due;
      while v_left > 0.01 loop
        v_i := v_i + 1;
        if v_next is null or v_due_day is null then
          v_next := coalesce(v_in.suggested_due_date, v_in.date_paid, current_date);
        else
          v_next := (date_trunc('month', v_next) + interval '1 month')::date
                    + (least(v_due_day,
                             extract(day from (date_trunc('month', v_next) + interval '2 month' - interval '1 day'))::int) - 1);
        end if;
        v_chunk := case when v_rent is null or v_rent <= 0 or v_i >= 24 then v_left else least(v_left, v_rent) end;
        if v_i > 1 and v_left < v_rent and v_left > 0.01 and v_ids <> '{}' then
          update public.rent_log set amount = amount + v_left where id = v_ids[array_upper(v_ids, 1)];
          v_left := 0;
          exit;
        end if;
        insert into public.rent_log (company_id, property_id, property_name, tenant_name, amount, date_paid,
                                     method, applied_to_due_date, note, source, incoming_payment_id)
        values (v_in.company_id, v_prop, v_pname, v_tenant, v_chunk, v_in.date_paid, v_in.method, v_next,
                nullif(concat_ws(' · ', v_in.memo, 'from ' || v_in.tenant_name, 'prepayment'), ''), 'email', v_in.id)
        returning id into v_new;
        v_ids := v_ids || v_new;
        v_left := v_left - v_chunk;
        exit when v_i >= 24;
      end loop;
    end if;
  end if;

  update public.incoming_rent_payments
     set status = 'confirmed', property_id = v_prop, property_name = v_pname,
         rent_log_ids = v_ids, reviewed_at = now(), reviewed_by = auth.uid()
   where id = v_in.id;

  if p_remember and public.rg_normalize_name(v_in.tenant_name) is not null then
    insert into public.tenant_payer_aliases (company_id, property_id, tenant_name, payer_name_norm)
    values (v_in.company_id, v_prop, v_tenant, public.rg_normalize_name(v_in.tenant_name))
    on conflict (company_id, payer_name_norm)
    do update set property_id = excluded.property_id, tenant_name = excluded.tenant_name;
  end if;

  return jsonb_build_object('status', 'confirmed', 'rent_log_ids', to_jsonb(v_ids));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_dismiss_incoming_payment(p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  update public.incoming_rent_payments
     set status = 'dismissed', reviewed_at = now(), reviewed_by = auth.uid(),
         raw_body = null
   where id = p_id and status = 'pending'
  returning jsonb_build_object('status', 'dismissed', 'id', id);
$function$
;

CREATE OR REPLACE FUNCTION public.rg_fill_property_id_by_company()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
begin
  if new.property_id is null and new.property_name is not null and new.company_id is not null then
    select p.id into new.property_id from public.properties p
     where p.company_id = new.company_id and p.name = new.property_name
     order by p.created_at limit 1;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_fill_property_id_from_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
begin
  if new.property_id is null and new.property_name is not null then
    select p.id into new.property_id
    from public.properties p
    where p.name = new.property_name
      and (p.owner_id = auth.uid() or public.rg_company_access(p.company_id))
    order by p.created_at
    limit 1;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_ingest_payment_email(p_inbox_token text, p_message_id text, p_source text, p_method text, p_payer text, p_amount numeric, p_date_paid date, p_memo text DEFAULT NULL::text, p_transaction_ref text DEFAULT NULL::text, p_subject text DEFAULT NULL::text, p_body text DEFAULT NULL::text, p_sender_verified boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_company   uuid;
  v_existing  record;
  v_payer     text := public.rg_normalize_name(p_payer);
  v_memo      text := lower(coalesce(p_memo, ''));
  v_best      record;
  v_min_rent  numeric;
  v_id        uuid;
  v_status    text;
  v_conf      numeric;
begin
  if p_amount is null or p_amount <= 0 or p_message_id is null then
    return jsonb_build_object('status', 'rejected', 'reason', 'missing amount or message id');
  end if;

  select id into v_company from public.companies where payment_inbox_token = lower(p_inbox_token);
  if v_company is null then
    return jsonb_build_object('status', 'unknown_inbox');
  end if;

  select id, status into v_existing
  from public.incoming_rent_payments
  where company_id = v_company and source_message_id = p_message_id;
  if found then
    return jsonb_build_object('status', 'duplicate', 'id', v_existing.id, 'existing_status', v_existing.status);
  end if;

  select min(rent_amount) into v_min_rent
  from public.rg_rent_status(v_company, coalesce(p_date_paid, current_date));

  -- Score each property's lease in effect
  with st as (
    select * from public.rg_rent_status(v_company, coalesce(p_date_paid, current_date))
  ),
  scored as (
    select st.*,
      case
        when exists (select 1 from public.tenant_payer_aliases a
                     where a.company_id = v_company and a.property_id = st.property_id
                       and a.payer_name_norm = v_payer)                                  then 1.0
        when v_payer is not null and public.rg_normalize_name(st.tenant_name) = v_payer  then 0.9
        when v_payer is not null and exists (
               select 1 from unnest(string_to_array(public.rg_normalize_name(st.tenant_name), ' ')) t(tok)
               where length(tok) >= 3 and tok = any (string_to_array(v_payer, ' ')))    then 0.6
        else 0
      end as name_score,
      case
        when abs(p_amount - st.rent_amount) < 0.01                                        then 1.0
        when st.balance > 0.01 and abs(p_amount - st.balance) < 0.01                      then 1.0
        when abs(p_amount - st.rent_amount) <= st.rent_amount * 0.02                      then 0.8
        when st.balance > 0.01 and p_amount < st.balance
             and mod(p_amount, st.rent_amount) = 0                                        then 0.8
        when st.balance > 0.01 and p_amount < st.rent_amount
             and p_amount >= st.rent_amount * 0.25                                        then 0.4
        else 0
      end as amount_score,
      case
        when v_memo ~ 'rent' then 0.1
        when st.property_name is not null
             and v_memo like '%' || lower(split_part(st.property_name, ' ', 1)) || '%'    then 0.1
        else 0
      end as memo_bonus
    from st
  )
  select *, least(1.0, name_score * 0.6 + amount_score * 0.4 + memo_bonus) as conf
  into v_best
  from scored
  order by least(1.0, name_score * 0.6 + amount_score * 0.4 + memo_bonus) desc,
           balance desc
  limit 1;

  v_conf := coalesce(v_best.conf, 0);

  -- Not rent-like: no name link and amount doesn't fit any lease
  if v_best.property_id is null
     or (coalesce(v_best.name_score, 0) = 0 and coalesce(v_best.amount_score, 0) < 0.8)
     or (coalesce(v_best.name_score, 0) = 0 and v_min_rent is not null and p_amount < v_min_rent * 0.25) then
    insert into public.incoming_rent_payments
      (company_id, source, source_message_id, method, amount, date_paid, status, match_reason, sender_verified)
    values
      (v_company, p_source, p_message_id, p_method, p_amount, p_date_paid, 'ignored', 'not rent-like', p_sender_verified)
    returning id into v_id;
    return jsonb_build_object('status', 'ignored', 'id', v_id);
  end if;

  v_status := 'pending';   -- v1: every rent-like payment waits for the landlord

  insert into public.incoming_rent_payments
    (company_id, property_name, tenant_name, method, amount, date_paid, memo,
     source, source_message_id, raw_subject, raw_body, status,
     property_id, lease_id, suggested_due_date, match_confidence, match_reason,
     transaction_ref, sender_verified)
  values
    (v_company, v_best.property_name, p_payer, p_method, p_amount, p_date_paid, p_memo,
     p_source, p_message_id, left(p_subject, 500), left(p_body, 8000), v_status,
     v_best.property_id, v_best.lease_id,
     coalesce(v_best.oldest_unpaid_due, v_best.current_due_date),
     round(v_conf, 2),
     concat_ws(', ',
       case v_best.name_score when 1.0 then 'known payer' when 0.9 then 'name matches tenant'
                              when 0.6 then 'partial name match' end,
       case when v_best.amount_score >= 1.0 then 'amount matches'
            when v_best.amount_score >= 0.8 then 'amount close or multiple months'
            when v_best.amount_score > 0    then 'partial amount' end,
       case when v_best.memo_bonus > 0 then 'memo mentions rent/property' end),
     p_transaction_ref, p_sender_verified)
  returning id into v_id;

  return jsonb_build_object('status', v_status, 'id', v_id,
                            'property', v_best.property_name, 'confidence', round(v_conf, 2));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_is_tenant_of_company(p_company_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select p_company_id is not null and public.rg_auth_email() is not null and exists (
    select 1 from public.leases l
     where l.company_id = p_company_id
       and l.archived_at is null
       and lower(l.tenant_email) = lower(public.rg_auth_email()));
$function$
;

CREATE OR REPLACE FUNCTION public.rg_maintenance_webhook_secret()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select decrypted_secret from vault.decrypted_secrets
  where name = 'rg_maintenance_webhook_secret'
  limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_normalize_name(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select nullif(trim(regexp_replace(lower(coalesce(p, '')), '[^a-z ]+', ' ', 'g')), '')
$function$
;

CREATE OR REPLACE FUNCTION public.rg_rent_schedule(p_company_id uuid DEFAULT NULL::uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS TABLE(property_id uuid, property_name text, company_id uuid, lease_id uuid, tenant_name text, lease_state text, rent_amount numeric, due_day integer, grace_days integer, lease_end date, charge_end date, due_date date, paid numeric, balance numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with lease_pick as (
  select distinct on (p.id)
    p.id as property_id, p.name as property_name, p.company_id,
    l.id as lease_id, l.tenant_name,
    lower(coalesce(l.status, ''))     as lstatus,
    lower(coalesce(l.lease_type, '')) as ltype,
    l.lease_start, l.lease_end, l.terminated_date,
    l.rent_amount::numeric as rent_amount,
    coalesce(l.rent_due_day, l.due_day, extract(day from l.lease_start)::int) as due_day,
    coalesce(l.grace_period, l.late_fee_grace_days, 0)::int as grace_days
  from public.properties p
  join public.leases l
    on l.property_id = p.id
    or (l.property_id is null and l.property_name = p.name
        and l.company_id is not distinct from p.company_id)
  where p.archived_at is null
    and l.archived_at is null
    and (p_company_id is null or p.company_id = p_company_id)
    and l.lease_start is not null
    and l.lease_start <= p_as_of
    and coalesce(l.rent_amount, 0) > 0
  order by p.id, l.lease_start desc
),
windowed as (
  select lp.*,
    case
      when lp.terminated_date is not null then least(lp.terminated_date, p_as_of)
      when lp.lstatus = 'terminated'      then least(coalesce(lp.lease_end, p_as_of), p_as_of)
      else p_as_of
    end as charge_end,
    case
      when lp.terminated_date is not null or lp.lstatus = 'terminated' then 'ended'
      when lp.ltype like '%month%' or lp.ltype = 'm2m'
        or lp.lstatus in ('month_to_month', 'holdover')             then 'month_to_month'
      when lp.lease_end is not null and lp.lease_end < p_as_of      then 'holdover'
      else 'active'
    end as lease_state
  from lease_pick lp
),
dues as (
  select w.property_id,
         (m::date + (least(w.due_day,
            extract(day from (m + interval '1 month' - interval '1 day'))::int) - 1)) as due_date
  from windowed w
  cross join lateral generate_series(
    date_trunc('month', w.lease_start),
    date_trunc('month', w.charge_end),
    interval '1 month') as m
),
pay as (
  select w.property_id, r.applied_to_due_date as due_date, sum(r.amount::numeric) as paid
  from windowed w
  join public.rent_log r
    on (r.property_id = w.property_id
        or (r.property_id is null and r.property_name = w.property_name))
   and r.company_id is not distinct from w.company_id
   and r.archived_at is null
   and r.applied_to_due_date is not null
  group by w.property_id, r.applied_to_due_date
)
select
  w.property_id, w.property_name, w.company_id, w.lease_id, w.tenant_name, w.lease_state,
  w.rent_amount, w.due_day, w.grace_days, w.lease_end, w.charge_end,
  d.due_date,
  coalesce(pay.paid, 0),
  greatest(w.rent_amount - coalesce(pay.paid, 0), 0)
from windowed w
join dues d on d.property_id = w.property_id
left join pay on pay.property_id = d.property_id and pay.due_date = d.due_date
where d.due_date >= w.lease_start and d.due_date <= w.charge_end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_rent_status(p_company_id uuid DEFAULT NULL::uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS TABLE(property_id uuid, property_name text, lease_id uuid, tenant_name text, lease_state text, rent_amount numeric, due_day integer, grace_days integer, lease_end date, charge_end date, periods_due integer, periods_unpaid integer, total_due numeric, total_paid numeric, balance numeric, oldest_unpaid_due date, current_due_date date, current_paid numeric, current_balance numeric, days_overdue integer, is_late boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with s as (
  select * from public.rg_rent_schedule(p_company_id, p_as_of)
),
agg as (
  select s.property_id,
         count(*)::int                                        as periods_due,
         count(*) filter (where s.balance > 0.01)::int        as periods_unpaid,
         sum(s.rent_amount)                                   as total_due,
         sum(least(s.paid, s.rent_amount))                    as total_paid,
         sum(s.balance)                                       as balance,
         min(s.due_date) filter (where s.balance > 0.01)      as oldest_unpaid_due,
         max(s.due_date)                                      as current_due_date
  from s group by s.property_id
),
head as (
  select distinct on (s.property_id) s.*
  from s order by s.property_id
)
select h.property_id, h.property_name, h.lease_id, h.tenant_name, h.lease_state,
  h.rent_amount, h.due_day, h.grace_days, h.lease_end, h.charge_end,
  a.periods_due, a.periods_unpaid, a.total_due, a.total_paid, a.balance,
  a.oldest_unpaid_due, a.current_due_date,
  coalesce(cur.paid, 0), coalesce(cur.balance, 0),
  case when a.oldest_unpaid_due is null then 0 else (p_as_of - a.oldest_unpaid_due) end,
  (a.oldest_unpaid_due is not null and p_as_of > a.oldest_unpaid_due + h.grace_days)
from head h
join agg a on a.property_id = h.property_id
left join s cur on cur.property_id = h.property_id and cur.due_date = a.current_due_date;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_set_company_owner()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.owner_user_id is null then
    new.owner_user_id := auth.uid();
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_store_inbox_verification(p_inbox_token text, p_url text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.companies
     set payment_inbox_verify_url = p_url, payment_inbox_verify_at = now()
   where payment_inbox_token = lower(p_inbox_token)
  returning true;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_sync_company_from_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
begin
  if new.property_id is not null then
    select p.company_id into new.company_id
    from public.properties p
    where p.id = new.property_id;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_sync_property_status(p_property_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare v_occupied boolean;
begin
  if p_property_id is null then return; end if;
  select exists (
    select 1 from public.leases l
     where l.property_id = p_property_id
       and l.archived_at is null
       and lower(coalesce(l.status, '')) not in ('draft', 'terminated')
       and (l.lease_start is null or l.lease_start <= current_date)
       and (l.terminated_date is null or l.terminated_date > current_date)
       and (l.lease_end is null or l.lease_end >= current_date
            or lower(coalesce(l.status, '')) in ('holdover', 'month_to_month', 'signed', 'active', 'current')
            or lower(coalesce(l.lease_type, '')) like '%month%')
  ) into v_occupied;
  update public.properties set status = case when v_occupied then 'occupied' else 'vacant' end where id = p_property_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_tenant_can_file(p_company_id uuid, p_property_id uuid, p_tenant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select p_company_id is not null
    and (p_tenant_id is null or exists (
      select 1 from public.tenants t
      where t.id = p_tenant_id
        and (t.auth_user_id = auth.uid()
             or (t.auth_user_id is null and lower(t.email) = public.rg_auth_email()))
    ))
    and exists (
      select 1
      from public.leases l
      where l.company_id = p_company_id
        and l.archived_at is null
        and (p_property_id is null or l.property_id = p_property_id)
        and (lower(l.tenant_email) = public.rg_auth_email()
             or (l.tenant_id is not null and l.tenant_id = public.rg_tenant_id_for_auth_user()))
    );
$function$
;

CREATE OR REPLACE FUNCTION public.rg_tenant_id_for_auth_user()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  SELECT id FROM public.tenants WHERE auth_user_id = auth.uid() LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_tenants_limit_self_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
begin
  if auth.uid() is null or old.auth_user_id is distinct from auth.uid() then
    return new;
  end if;
  if exists (select 1 from public.leases l
             where lower(l.tenant_email) = lower(old.email)
               and public.rg_company_access(l.company_id)) then
    return new;
  end if;
  if (to_jsonb(new) - 'phone') is distinct from (to_jsonb(old) - 'phone') then
    raise exception 'Tenants can only update their phone number.' using errcode = '42501';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rg_try_uuid(p text)
 RETURNS uuid
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
begin
  return p::uuid;
exception when others then
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_company_id_from_property()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.company_id is null and new.property_id is not null then
    select company_id into new.company_id from public.properties where id = new.property_id;
  end if;
  return new;
end
$function$
;

CREATE OR REPLACE FUNCTION public.set_owner_and_property_ids()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare p record;
begin
  if (new.property_id is null) and (new.property_name is not null) then
    select id, owner_id into p from public.properties
     where name = new.property_name and (new.company_id is null or company_id = new.company_id)
     order by created_at desc limit 1;
    if p.id is not null then new.property_id := p.id; new.owner_id := p.owner_id; end if;
  end if;
  if (new.property_id is not null) and (new.owner_id is null) then
    select owner_id into new.owner_id from public.properties where id = new.property_id;
  end if;
  return new;
end
$function$
;

CREATE OR REPLACE FUNCTION public.tenant_set_preferred_payment_method(p_lease_id uuid, p_method text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.leases
  set tenant_preferred_payment_method = nullif(trim(p_method), ''),
      tenant_preferred_payment_method_updated_at = now()
  where id = p_lease_id
    and lower(tenant_email) = rg_auth_email();

  if not found then
    raise exception 'Lease not found or not owned by current tenant';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_sync_property_status_from_leases()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if tg_op = 'DELETE' then perform public.rg_sync_property_status(old.property_id); return null; end if;
  perform public.rg_sync_property_status(new.property_id);
  if tg_op = 'UPDATE' and old.property_id is distinct from new.property_id then
    perform public.rg_sync_property_status(old.property_id);
  end if;
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trigger_maintenance_acknowledgment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform net.http_post(
    url := 'https://xqmnaeujwumlcoyhgzuk.supabase.co/functions/v1/maintenance-acknowledgment',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', public.rg_maintenance_webhook_secret()
    ),
    body := jsonb_build_object('type', 'INSERT', 'table', 'maintenance_requests', 'record', to_jsonb(new))
  );
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.unarchive_expense(p_expense_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id from public.expenses where id = p_expense_id;
  if v_company_id is null or not public.rg_company_access(v_company_id) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  update public.expenses set archived_at = null, archived_by = null where id = p_expense_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.unarchive_lease(p_lease_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.leases
  where id = p_lease_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.leases
  set archived_at = null,
      archived_by = null
  where id = p_lease_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.unarchive_maintenance_request(p_request_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.maintenance_requests
  where id = p_request_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.maintenance_requests
  set archived_at = null,
      archived_by = null
  where id = p_request_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.unarchive_property(p_property_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.properties
  where id = p_property_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.properties
  set archived_at = null,
      archived_by = null
  where id = p_property_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.unarchive_rent_log(p_rent_log_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company_id uuid;
begin
  select company_id into v_company_id
  from public.rent_log
  where id = p_rent_log_id;

  if v_company_id is null or not public.is_company_member(v_company_id) then
    raise exception 'Not authorized';
  end if;

  update public.rent_log
  set archived_at = null,
      archived_by = null
  where id = p_rent_log_id;
end;
$function$
;
