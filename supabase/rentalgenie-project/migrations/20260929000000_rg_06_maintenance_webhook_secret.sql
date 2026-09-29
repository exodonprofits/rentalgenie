-- Random secret generated in the database; shared by the maintenance trigger and the
-- maintenance-acknowledgment Edge Function (read through rg_maintenance_webhook_secret(), service role only).
select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'rg_maintenance_webhook_secret',
                           'Maintenance trigger -> maintenance-acknowledgment webhook secret')
where not exists (select 1 from vault.secrets where name = 'rg_maintenance_webhook_secret');
