-- Expand the existing category catalog without changing existing rows.
insert into public.categories (name, slug, icon_key, theme_key, sort_order)
values
  ('Turismo y Aventura', 'turismo-aventura', 'terrain', 'moss', 22),
  ('Propiedades y terrenos', 'propiedades-terrenos', 'real_estate', 'lake', 23),
  ('Servicios profesionales', 'servicios-profesionales', 'professional', 'forest', 24),
  ('Otros servicios', 'otros-servicios', 'more', 'clay', 25)
on conflict (slug) do nothing;

insert into public.subcategories (category_id, name, slug, icon_key, sort_order)
select c.id, item.name, item.slug, item.icon_key, item.sort_order
from public.categories c
join (values
  ('propiedades-terrenos', 'Venta de terrenos', 'venta-terrenos', 'real_estate', 1),
  ('propiedades-terrenos', 'Venta de propiedades', 'venta-propiedades', 'real_estate', 2),
  ('propiedades-terrenos', 'Arriendo de propiedades', 'arriendo-propiedades', 'real_estate', 3),
  ('propiedades-terrenos', 'Parcelas', 'parcelas', 'terrain', 4),
  ('propiedades-terrenos', 'Corretaje inmobiliario', 'corretaje-inmobiliario', 'real_estate', 5),
  ('servicios-profesionales', 'Abogados', 'abogados', 'professional', 1),
  ('servicios-profesionales', 'Contadores', 'contadores', 'professional', 2),
  ('servicios-profesionales', 'Arquitectos', 'arquitectos', 'professional', 3),
  ('servicios-profesionales', 'Diseñadores', 'disenadores', 'professional', 4),
  ('servicios-profesionales', 'Fotografía', 'fotografia', 'camera', 5),
  ('servicios-profesionales', 'Marketing', 'marketing', 'professional', 6),
  ('servicios-profesionales', 'Asesorías profesionales', 'asesorias-profesionales', 'professional', 7),
  ('otros-servicios', 'Eventos', 'eventos', 'event', 1),
  ('otros-servicios', 'Transporte', 'transporte-servicios', 'truck', 2),
  ('otros-servicios', 'Mascotas', 'mascotas', 'pets', 3),
  ('otros-servicios', 'Clases particulares', 'clases-particulares', 'school', 4),
  ('otros-servicios', 'Artesanos', 'artesanos', 'craft', 5),
  ('otros-servicios', 'Emprendimientos locales', 'emprendimientos-locales', 'store', 6)
) as item(category_slug, name, slug, icon_key, sort_order)
  on item.category_slug = c.slug
where not exists (
  select 1 from public.subcategories existing
  where existing.category_id = c.id and existing.slug = item.slug
);
