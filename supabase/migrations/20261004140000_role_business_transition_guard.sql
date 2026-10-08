create or replace function public.protect_profile_privileged_fields()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if new.role <> 'provider' and old.role <> new.role
     and (exists (select 1 from public.businesses b where b.owner_id = old.id)
       or exists (select 1 from public.business_members bm
         where bm.user_id = old.id and bm.status = 'active'
           and bm.role in ('owner', 'manager'))) then
    raise exception 'PROVIDER_HAS_BUSINESS' using errcode = '23514';
  end if;
  if (new.role <> old.role or new.account_status <> old.account_status)
     and auth.role() <> 'service_role'
     and not (
       current_user = 'postgres'
       and current_setting('ranco.admin_profile_write', true) = 'on'
     ) then
    raise exception 'profile role and account status require a privileged server-side operation'
      using errcode = '42501';
  end if;
  return new;
end;
$$;
