-- Some production snapshots have the guard function but no trigger attached.
-- Install the guard idempotently and trust only privileged function owners.
create or replace function public.protect_profile_privileged_fields()
returns trigger language plpgsql
set search_path = pg_catalog
as $$
declare
  v_trusted_write boolean := current_user in ('postgres', 'supabase_admin')
    and (current_setting('ranco.admin_profile_write', true) = 'on'
      or current_setting('ranco.provider_role_reconciliation', true) = 'on');
begin
  if (new.role <> old.role or new.account_status <> old.account_status)
     and auth.role() is distinct from 'service_role' and not v_trusted_write then
    raise exception 'profile role and account status require a privileged server-side operation'
      using errcode = '42501';
  end if;
  if new.role <> 'provider' and old.role <> new.role
     and coalesce(current_setting('ranco.provider_role_reconciliation', true), 'off') <> 'on'
     and (exists (select 1 from public.businesses b where b.owner_id = old.id)
       or exists (select 1 from public.business_members bm
         where bm.user_id = old.id and bm.status = 'active'
           and bm.role in ('owner', 'manager'))) then
    raise exception 'PROVIDER_HAS_BUSINESS' using errcode = '23514';
  end if;
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger t
    where t.tgrelid = 'public.profiles'::regclass
      and t.tgfoid = 'public.protect_profile_privileged_fields()'::regprocedure
      and not t.tgisinternal
  ) then
    create trigger profiles_protect_privileged_fields_reconciled
      before update of role, account_status on public.profiles
      for each row execute function public.protect_profile_privileged_fields();
  end if;
end;
$$;
