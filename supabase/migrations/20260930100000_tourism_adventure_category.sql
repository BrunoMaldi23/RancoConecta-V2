-- Add the main tourism category without changing tables or RLS.
insert into public.categories (
  name,
  slug,
  icon_key,
  theme_key,
  active,
  sort_order
)
values (
  'Turismo y Aventura',
  'turismo-aventura',
  'terrain',
  'moss',
  true,
  3
)
on conflict (slug) do update set
  name = excluded.name,
  icon_key = excluded.icon_key,
  theme_key = excluded.theme_key,
  active = true;
