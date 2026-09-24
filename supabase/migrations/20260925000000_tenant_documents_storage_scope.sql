-- tenant-documents storage: scope writes to the company that owns the folder
--
-- The bucket's INSERT, UPDATE and DELETE policies only checked bucket_id and applied to role
-- `public`, so anyone holding the anon key (it ships in every page) — signed in or not — could
-- upload, overwrite or delete any landlord's tenant documents. Reads were already scoped.
--
-- Pages upload to <company_id>/<property-slug>/<timestamp>_<file> (property-documents.html,
-- view-lease.html), the same layout rg_tenant_docs_select already relies on. Writes now require
-- rg_company_access() on that first folder. The bucket was empty when this was applied.

drop policy if exists "Authenticated users can upload tenant documents" on storage.objects;
drop policy if exists "Authenticated users can update tenant documents" on storage.objects;
drop policy if exists "Authenticated users can delete tenant documents" on storage.objects;

create policy rg_tenant_docs_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'tenant-documents'
              and public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1])));

create policy rg_tenant_docs_update on storage.objects
  for update to authenticated
  using      (bucket_id = 'tenant-documents'
              and public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1])))
  with check (bucket_id = 'tenant-documents'
              and public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1])));

create policy rg_tenant_docs_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'tenant-documents'
         and public.rg_company_access(public.rg_try_uuid((storage.foldername(name))[1])));
