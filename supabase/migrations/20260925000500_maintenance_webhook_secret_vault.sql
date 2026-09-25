-- maintenance-acknowledgment webhook: secret in Vault, rotated
--
-- trigger_maintenance_acknowledgment() had the x-webhook-secret value written into the function
-- body, so anyone who could read function definitions could call the Edge Function (which writes
-- tenant_messages and sends email with the service role). The secret now lives only in Vault:
--   * a new random value is generated here, inside the database (it never appears in this file);
--   * the trigger reads it through rg_maintenance_webhook_secret();
--   * the Edge Function reads the same value with the service role through the same function, so
--     there is no copy in Edge Function secrets to keep in sync.
-- To rotate later: select vault.update_secret(id, encode(extensions.gen_random_bytes(32), 'hex'))
--   from vault.secrets where name = 'rg_maintenance_webhook_secret';

select vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'hex'),
  'rg_maintenance_webhook_secret',
  'x-webhook-secret for the maintenance-acknowledgment Edge Function'
)
where not exists (select 1 from vault.secrets where name = 'rg_maintenance_webhook_secret');

create or replace function public.rg_maintenance_webhook_secret()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets
  where name = 'rg_maintenance_webhook_secret'
  limit 1;
$$;

revoke all on function public.rg_maintenance_webhook_secret() from public, anon, authenticated;
grant execute on function public.rg_maintenance_webhook_secret() to service_role;

create or replace function public.trigger_maintenance_acknowledgment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform net.http_post(
    url := 'https://pbojacnagutipfhcxltj.supabase.co/functions/v1/maintenance-acknowledgment',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', public.rg_maintenance_webhook_secret()
    ),
    body := jsonb_build_object('type', 'INSERT', 'table', 'maintenance_requests', 'record', to_jsonb(new))
  );
  return new;
end;
$function$;
