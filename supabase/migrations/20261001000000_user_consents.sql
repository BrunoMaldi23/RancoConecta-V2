create table if not exists public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  data_processing_authorized boolean not null check (data_processing_authorized),
  consent_context text not null,
  accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists user_consents_user_id_idx on public.user_consents (user_id);
alter table public.user_consents enable row level security;

create policy "users read own consents" on public.user_consents
  for select to authenticated using (auth.uid() = user_id);
create policy "users record own consents" on public.user_consents
  for insert to authenticated with check (auth.uid() = user_id);

create or replace function public.record_signup_consent()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.raw_user_meta_data ->> 'consent_terms_version' is not null
     and new.raw_user_meta_data ->> 'consent_privacy_version' is not null
     and new.raw_user_meta_data ->> 'consent_data_processing' = 'true' then
    insert into public.user_consents
      (user_id, terms_version, privacy_version, data_processing_authorized, consent_context)
    values
      (new.id, new.raw_user_meta_data ->> 'consent_terms_version',
       new.raw_user_meta_data ->> 'consent_privacy_version', true, 'provider_signup');
  end if;
  return new;
end;
$$;

create trigger auth_users_record_signup_consent
  after insert on auth.users
  for each row execute function public.record_signup_consent();
