create or replace function public.audit_category_change()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  insert into public.audit_logs (
    actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    auth.uid(),
    case
      when tg_op = 'INSERT' then 'category_created'
      when tg_op = 'DELETE' then 'category_deleted'
      when old.active and not new.active then 'category_deactivated'
      when not old.active and new.active then 'category_reactivated'
      else 'category_updated'
    end,
    'category', coalesce(new.id, old.id),
    case when tg_op = 'INSERT' then null
      else jsonb_build_object('name', old.name, 'slug', old.slug,
        'active', old.active) end,
    case when tg_op = 'DELETE' then null
      else jsonb_build_object('name', new.name, 'slug', new.slug,
        'active', new.active) end
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists audit_category_change on public.categories;
create trigger audit_category_change
after insert or update or delete on public.categories
for each row execute function public.audit_category_change();
