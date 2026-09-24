-- leases: security and pet deposit amounts
--
-- lease-form.html has always collected, saved and reloaded security_deposit and pet_deposit, but
-- the columns never existed, so the save quietly stripped them and the values were lost. Nullable
-- numerics; no existing data to migrate.

alter table public.leases add column if not exists security_deposit numeric;
alter table public.leases add column if not exists pet_deposit numeric;
