-- Anonymous Auth sessions are valid authenticated sessions in Supabase. Keep
-- visitor accounts out of business ownership even when a client bypasses UI.
create or replace function public.user_can_manage_business(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and (
      exists (
        select 1
        from public.business_members bm
        where bm.business_id = p_business_id
          and bm.user_id = auth.uid()
          and bm.status = 'active'
          and bm.role in ('owner', 'manager')
      )
      or exists (
        select 1
        from public.businesses b
        where b.id = p_business_id
          and b.owner_id = auth.uid()
      )
    );
$$;

create or replace function public.reject_anonymous_business_management()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.jwt() ->> 'is_anonymous' = 'true' then
    raise exception 'Anonymous visitors cannot manage businesses'
      using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all on function public.reject_anonymous_business_management() from public, anon, authenticated;

drop trigger if exists reject_anonymous_business_management on public.businesses;
create trigger reject_anonymous_business_management
before insert or update or delete on public.businesses
for each row execute function public.reject_anonymous_business_management();
