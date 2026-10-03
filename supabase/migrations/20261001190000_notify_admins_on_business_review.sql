-- The review notification must work without an external webhook or WhatsApp API.
-- Only active administrators receive it. A unique index from the prior
-- migration prevents duplicate notices for the same business and recipient.
create or replace function public.notify_admins_on_business_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.publication_status = 'pending_review'
     and old.publication_status is distinct from 'pending_review' then
    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      entity_type,
      entity_id,
      deep_link
    )
    select
      profile.id,
      'provider_pending_review',
      'Nuevo negocio pendiente de revisión',
      'Negocio pendiente: ' || new.name,
      'business',
      new.id,
      '/admin/businesses/' || new.id::text
    from public.profiles as profile
    where profile.role in ('admin', 'super_admin')
      and profile.account_status = 'active'
    on conflict do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.notify_admins_on_business_review()
from public, anon, authenticated;

drop trigger if exists notify_admins_on_business_review on public.businesses;
create trigger notify_admins_on_business_review
after update of publication_status on public.businesses
for each row execute function public.notify_admins_on_business_review();
