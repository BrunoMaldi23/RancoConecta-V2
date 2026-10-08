\set ON_ERROR_STOP on
\if :{?bootstrap_user_id}
\else
  \echo 'Required: psql -v bootstrap_user_id=<approved-profile-uuid>'
  \quit 2
\endif

-- Run once with a privileged DB owner through psql. This script does not create
-- a callable database function; its one-shot lock is the zero-super-admin check.
begin;
select set_config('ranco.bootstrap_user_id', :'bootstrap_user_id', true);
select pg_advisory_xact_lock(hashtextextended('ranco:first-super-admin-bootstrap', 0));
do $$ begin
  if current_user <> 'postgres' and not pg_has_role(current_user, 'postgres', 'MEMBER') then
    raise exception 'BOOTSTRAP_REQUIRES_DATABASE_OWNER' using errcode = '42501';
  end if;
end $$;
set local role postgres;
\ir bootstrap-first-super-admin-core.sql
commit;
