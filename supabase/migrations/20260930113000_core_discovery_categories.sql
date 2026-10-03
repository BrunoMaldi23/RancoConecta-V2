-- Complete the existing Home/Explore editorial entry points.
insert into public.categories (name, slug, icon_key, theme_key, sort_order)
values
  ('Alojamiento', 'alojamiento', 'bed', 'lake', 26),
  ('Gastronomía', 'gastronomia', 'restaurant', 'clay', 27)
on conflict (slug) do nothing;
