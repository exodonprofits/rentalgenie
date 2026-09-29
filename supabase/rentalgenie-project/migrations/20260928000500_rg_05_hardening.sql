-- pg_net's extension object belongs outside the exposed schema; its functions live in schema net either way
drop extension if exists pg_net;
create extension pg_net with schema extensions;

-- pin search_path on the functions that had none (behaviour unchanged: they only reference public.*)
alter function public.auto_unpublish_listing() set search_path = public;
alter function public.block_tenant_email_change() set search_path = public;
alter function public.is_company_member(uuid) set search_path = public;
alter function public.rg_auth_email() set search_path = public;
alter function public.rg_normalize_name(text) set search_path = public;
alter function public.rg_sync_property_status(uuid) set search_path = public;
alter function public.rg_try_uuid(text) set search_path = public;
alter function public.set_company_id_from_property() set search_path = public;
alter function public.set_owner_and_property_ids() set search_path = public;
alter function public.trg_sync_property_status_from_leases() set search_path = public;
