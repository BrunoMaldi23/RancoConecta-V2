insert into regions (name, slug, sort_order) values
  ('Los Ríos', 'los-rios', 1)
on conflict (slug) do nothing;

insert into communes (region_id, name, slug, sort_order)
select r.id, item.name, item.slug, item.sort_order
from regions r
cross join (values
  ('Lago Ranco', 'lago-ranco', 1),
  ('Futrono', 'futrono', 2)
) as item(name, slug, sort_order)
where r.slug = 'los-rios'
on conflict (slug) do nothing;

insert into locations (commune_id, name, slug, sort_order)
select c.id, item.name, item.slug, item.sort_order
from communes c
join (values
  ('lago-ranco', 'Lago Ranco', 'lago-ranco', 1),
  ('futrono', 'Futrono', 'futrono', 2),
  ('futrono', 'Llifén', 'llifen', 3),
  ('lago-ranco', 'Riñinahue', 'rininahue', 4),
  ('lago-ranco', 'Calcurrupe', 'calcurrupe', 5),
  ('futrono', 'Maihue', 'maihue', 6),
  ('lago-ranco', 'Dollinco', 'dollinco', 7),
  ('lago-ranco', 'Caunahue', 'caunahue', 8),
  ('futrono', 'Curriñe', 'currine', 9),
  ('lago-ranco', 'Cerrillos', 'cerrillos', 10),
  ('lago-ranco', 'Notuela', 'notuela', 11)
) as item(commune_slug, name, slug, sort_order) on item.commune_slug = c.slug
on conflict (slug) do nothing;

insert into categories (name, slug, icon_key, theme_key, sort_order) values
  ('Servicios hogar', 'home-services', 'tools', 'forest', 1),
  ('Comercios', 'commerce', 'store', 'lake', 2),
  ('Gastronomía', 'gastronomy', 'restaurant', 'clay', 3),
  ('Alojamientos', 'lodging', 'bed', 'moss', 4)
on conflict (slug) do nothing;

insert into subcategories (category_id, name, slug, description, icon_key, sort_order)
select c.id, item.name, item.slug, item.description, item.icon_key, item.sort_order
from categories c
join (values
  ('home-services', 'Gasfitería', 'plumbing', 'Instalación y reparación de agua, cañerías y artefactos.', 'plumbing', 1),
  ('home-services', 'Electricidad', 'electricity', 'Servicios eléctricos domiciliarios y comerciales.', 'electricity', 2),
  ('home-services', 'Calefacción', 'heating', 'Mantención e instalación de calefacción.', 'heating', 3),
  ('home-services', 'Transporte', 'transport', 'Traslados, fletes y logística local.', 'transport', 4),
  ('commerce', 'Almacenes', 'local-stores', 'Comercio de abarrotes y productos diarios.', 'store', 1),
  ('commerce', 'Ferretería', 'hardware', 'Materiales, herramientas e insumos.', 'hardware', 2),
  ('gastronomy', 'Restaurantes', 'restaurants', 'Comida preparada y atención en local.', 'restaurant', 1),
  ('gastronomy', 'Cafeterías', 'coffee', 'Café, repostería y espacios de encuentro.', 'coffee', 2),
  ('lodging', 'Cabañas', 'cabins', 'Cabañas y alojamientos familiares.', 'cabin', 1),
  ('lodging', 'Hospedajes', 'guesthouses', 'Hospedajes y habitaciones locales.', 'lodging', 2)
) as item(category_slug, name, slug, description, icon_key, sort_order) on item.category_slug = c.slug
on conflict (slug) do nothing;

insert into membership_plans (id, business_type, name, price_clp, duration_days, features) values
  ('service_basic', 'service', 'Service Basic', 9990, 365, '{"listing": true, "quote_requests": true}'::jsonb),
  ('commerce_pro', 'commerce', 'Commerce Pro', 19990, 365, '{"listing": true, "featured_catalog": true}'::jsonb),
  ('gastronomy_featured', 'gastronomy', 'Gastronomy Featured', 29990, 365, '{"listing": true, "featured": true}'::jsonb),
  ('lodging_standard', 'lodging', 'Lodging', 39990, 365, '{"listing": true, "seasonal_visibility": true}'::jsonb)
on conflict (id) do nothing;
