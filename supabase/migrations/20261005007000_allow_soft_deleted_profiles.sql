-- Soft deletion uses account_status = 'deleted' while retaining Auth identity
-- and all dependent business history.
do $$
declare
  v_constraint text;
  v_type_kind "char";
  v_type_schema text;
  v_type_name text;
begin
  select t.typtype, tn.nspname, t.typname
    into v_type_kind, v_type_schema, v_type_name
  from pg_attribute a
  join pg_type t on t.oid = a.atttypid
  join pg_namespace tn on tn.oid = t.typnamespace
  where a.attrelid = 'public.profiles'::regclass
    and a.attname = 'account_status' and not a.attisdropped;

  if v_type_kind = 'e' then
    if not exists (
      select 1 from pg_enum e
      where e.enumtypid = format('%I.%I', v_type_schema, v_type_name)::regtype
        and e.enumlabel = 'deleted'
    ) then
      execute format('alter type %I.%I add value %L',
        v_type_schema, v_type_name, 'deleted');
    end if;
  else
  select pg_get_constraintdef(c.oid)
    into v_constraint
  from pg_constraint c
  where c.conrelid = 'public.profiles'::regclass
    and c.conname = 'profiles_account_status_check'
    and c.contype = 'c';

  if v_constraint is null then
    alter table public.profiles
      add constraint profiles_account_status_check
      check (account_status in ('active', 'suspended', 'disabled', 'deleted'))
      not valid;
  elsif position('deleted' in v_constraint) = 0 then
    alter table public.profiles
      drop constraint profiles_account_status_check;
    alter table public.profiles
      add constraint profiles_account_status_check
      check (account_status in ('active', 'suspended', 'disabled', 'deleted'))
      not valid;
  end if;

  alter table public.profiles
    validate constraint profiles_account_status_check;
  end if;
end;
$$;
