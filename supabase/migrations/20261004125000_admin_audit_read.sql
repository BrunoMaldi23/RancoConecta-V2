drop policy if exists "active admins read audit logs" on public.audit_logs;
create policy "active admins read audit logs"
on public.audit_logs for select to authenticated
using (public.current_user_is_admin());
