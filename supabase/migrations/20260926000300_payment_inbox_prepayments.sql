-- Payment inbox: prepayments go to future months, not to a month that is already paid
--
-- rg_confirm_incoming_payment paid unpaid months oldest-first, then posted any leftover to
-- incoming_rent_payments.suggested_due_date. Ingest sets that to the oldest unpaid due date or, when
-- nothing is owed, the CURRENT due date, which is usually already paid. Tested before this fix:
-- a tenant who is paid up sends next month's rent, and it was recorded against this month,
-- double-counting it and leaving next month unpaid. A multi-month prepayment also all landed on one
-- due date, and rg_rent_schedule caps each month at the rent, so the extra months showed unpaid.
--
-- Leftover is now applied in rent-sized pieces to the due dates AFTER the last scheduled one
-- (same due day, clamped to month end), up to 24 months ahead; any remainder smaller than a month
-- goes on the last of them. Everything else is unchanged (explicit p_due_date, arrears split,
-- alias memory, status update).

create or replace function public.rg_confirm_incoming_payment(
  p_id uuid, p_property_id uuid default null::uuid, p_due_date date default null::date, p_remember boolean default true)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
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

    -- Prepayment: rent-sized pieces on the due dates after the last scheduled one.
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
        -- a remainder smaller than one month rides on the month just written
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
$function$;
