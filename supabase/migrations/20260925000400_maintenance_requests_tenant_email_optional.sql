-- maintenance_requests: tenant_email is optional
--
-- A landlord logging a repair themselves (found on a walk-through, a vacant unit) has no tenant to
-- name, and add-maintenance-request.html treats the field as optional, but the column was NOT NULL,
-- so those saves failed. Tenant-filed requests still set it. The maintenance-acknowledgment Edge
-- Function already skips records without a tenant_email.

alter table public.maintenance_requests alter column tenant_email drop not null;
