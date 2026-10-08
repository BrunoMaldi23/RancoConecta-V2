-- Preserve pre-041330 role and non-PII evidence before its legacy bulk UPDATE.
-- This lets the final reconciliation retain only objectively supported provider
-- identities without changing the historical migration file.
create table if not exists public.provider_role_migration_candidates (
  profile_id uuid primary key references public.profiles(id) on delete restrict,
  original_role text not null,
  provider_registration boolean not null,
  has_published_business boolean not null,
  has_onboarding_progress boolean not null,
  captured_at timestamptz not null default now(),
  resolution text check (resolution in (
    'DEBE_SER_PROVIDER', 'DEBE_SEGUIR_CUSTOMER', 'AMBIGUO', 'MANUAL_REVIEW'
  )),
  resolved_at timestamptz
);

alter table public.provider_role_migration_candidates enable row level security;
revoke all on public.provider_role_migration_candidates
  from public, anon, authenticated;

insert into public.provider_role_migration_candidates (
  profile_id, original_role, provider_registration,
  has_published_business, has_onboarding_progress
)
select p.id,
  p.role::text,
  lower(coalesce(u.raw_user_meta_data ->> 'provider_registration', 'false')) = 'true',
  exists (
    select 1 from public.businesses b
    where b.owner_id = p.id and b.publication_status = 'published'
  ),
  exists (
    select 1 from public.businesses b
    where b.owner_id = p.id
      and coalesce(b.onboarding_metadata, '{}'::jsonb)
        ?| array['last_section', 'terms_accepted', 'provider_registration']
  )
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'customer'
  and (
    exists (select 1 from public.businesses b where b.owner_id = p.id)
    or exists (
      select 1 from public.business_members bm
      where bm.user_id = p.id and bm.status = 'active'
        and bm.role in ('owner', 'manager')
    )
  )
on conflict (profile_id) do nothing;
