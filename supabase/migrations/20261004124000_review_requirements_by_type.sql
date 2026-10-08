create or replace function public.business_review_requirements(p_business_id uuid)
returns table (requirement_key text, satisfied boolean, message text)
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if not public.current_user_is_admin()
     and not public.user_can_manage_business(p_business_id) then
    raise exception 'business access required' using errcode = '42501';
  end if;

  return query
  with b as (
    select * from public.businesses where id = p_business_id
  )
  select 'name'::text,
    exists(select 1 from b where length(btrim(name)) >= 3),
    'Agrega el nombre comercial.'::text
  union all
  select 'description',
    exists(select 1 from b where length(btrim(coalesce(description, ''))) >= 20),
    'Agrega una descripción más completa.'
  union all
  select 'category',
    exists(select 1 from b where primary_category_id is not null),
    'Selecciona una categoría.'
  union all
  select 'contact',
    exists(select 1 from b where
      nullif(btrim(coalesce(phone, '')), '') is not null
      or nullif(btrim(coalesce(whatsapp, '')), '') is not null
      or nullif(btrim(coalesce(email, '')), '') is not null),
    'Agrega teléfono, WhatsApp o email.'
  union all
  select 'coverage',
    exists(select 1 from public.business_coverage bc
      where bc.business_id = p_business_id),
    'Selecciona al menos una localidad.'
  union all
  select 'service_items',
    exists(select 1 from public.business_services bs
      where bs.business_id = p_business_id and bs.active),
    'Selecciona al menos un servicio.'
  where exists(select 1 from b where business_type = 'service')
  union all
  select 'lodging_details',
    exists(select 1 from public.lodging_details ld
      where ld.business_id = p_business_id
        and ld.price_per_night > 0 and ld.max_guests > 0
        and ld.bedrooms > 0 and ld.beds > 0),
    'Completa detalles y tarifa base del alojamiento.'
  where exists(select 1 from b where business_type = 'lodging');
end;
$$;
