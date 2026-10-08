-- Reproduce the business fields already present in the live schema.
-- Existing columns are accepted only when their live contract matches.
alter table public.businesses
  add column if not exists is_featured boolean not null default false,
  add column if not exists accepts_requests boolean not null default true,
  add column if not exists rating_avg numeric not null default 0,
  add column if not exists review_count integer not null default 0;

do $$
declare
  v_column record;
  v_data_type text;
  v_nullable text;
  v_default text;
  v_constraint record;
  v_has_rating_check boolean;
  v_has_count_check boolean;
  v_featured_attnum smallint;
  v_named_index_matches boolean;
  v_equivalent_index_exists boolean;
begin
  for v_column in
    select * from (values
      ('is_featured', 'boolean', 'false'),
      ('accepts_requests', 'boolean', 'true'),
      ('rating_avg', 'numeric', '0'),
      ('review_count', 'integer', '0')
    ) as expected(column_name, data_type, default_value)
  loop
    select c.data_type, c.is_nullable, c.column_default
      into v_data_type, v_nullable, v_default
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'businesses'
      and c.column_name = v_column.column_name;

    if not found
       or v_data_type <> v_column.data_type
       or v_nullable <> 'NO'
       or trim(both '()' from coalesce(v_default, '')) <> v_column.default_value then
      raise exception 'Unexpected businesses.%. Expected % NOT NULL DEFAULT %; found type %, nullable %, default %',
        v_column.column_name, v_column.data_type, v_column.default_value,
        v_data_type, v_nullable, v_default;
    end if;
  end loop;

  select exists (
    select 1 from pg_constraint c
    where c.conrelid = 'public.businesses'::regclass
      and c.contype = 'c'
      and regexp_replace(lower(pg_get_constraintdef(c.oid)),
        '[[:space:]()]', '', 'g') =
        'checkrating_avg>=0::numericandrating_avg<=5::numeric'
  ) into v_has_rating_check;

  select * into v_constraint from pg_constraint
  where conrelid = 'public.businesses'::regclass
    and conname = 'businesses_rating_avg_check';
  if found and not v_has_rating_check then
    raise exception 'businesses_rating_avg_check exists with an unexpected definition';
  end if;
  if not v_has_rating_check then
    alter table public.businesses add constraint businesses_rating_avg_check
      check (rating_avg >= 0 and rating_avg <= 5);
  end if;

  select exists (
    select 1 from pg_constraint c
    where c.conrelid = 'public.businesses'::regclass
      and c.contype = 'c'
      and regexp_replace(lower(pg_get_constraintdef(c.oid)),
        '[[:space:]()]', '', 'g') = 'checkreview_count>=0'
  ) into v_has_count_check;

  select * into v_constraint from pg_constraint
  where conrelid = 'public.businesses'::regclass
    and conname = 'businesses_review_count_check';
  if found and not v_has_count_check then
    raise exception 'businesses_review_count_check exists with an unexpected definition';
  end if;
  if not v_has_count_check then
    alter table public.businesses add constraint businesses_review_count_check
      check (review_count >= 0);
  end if;

  select a.attnum into v_featured_attnum
  from pg_attribute a
  where a.attrelid = 'public.businesses'::regclass
    and a.attname = 'is_featured' and not a.attisdropped;

  select exists (
    select 1
    from pg_index i
    join pg_class idx on idx.oid = i.indexrelid
    join pg_am am on am.oid = idx.relam
    where i.indrelid = 'public.businesses'::regclass
      and idx.relname = 'idx_businesses_featured'
      and am.amname = 'btree'
      and i.indisvalid and i.indisready
      and not i.indisunique and i.indpred is null
      and i.indnkeyatts = 1 and i.indnatts = 1
      and i.indkey[0] = v_featured_attnum and i.indoption[0] = 0
  ) into v_named_index_matches;

  if exists (
    select 1 from pg_class idx
    join pg_index i on i.indexrelid = idx.oid
    where i.indrelid = 'public.businesses'::regclass
      and idx.relname = 'idx_businesses_featured'
  ) and not v_named_index_matches then
    raise exception 'idx_businesses_featured exists with an unexpected definition';
  end if;

  select exists (
    select 1
    from pg_index i
    join pg_class idx on idx.oid = i.indexrelid
    join pg_am am on am.oid = idx.relam
    where i.indrelid = 'public.businesses'::regclass
      and am.amname = 'btree'
      and i.indisvalid and i.indisready
      and not i.indisunique and i.indpred is null
      and i.indnkeyatts = 1 and i.indnatts = 1
      and i.indkey[0] = v_featured_attnum and i.indoption[0] = 0
  ) into v_equivalent_index_exists;

  if not v_equivalent_index_exists then
    create index idx_businesses_featured on public.businesses (is_featured);
  end if;
end;
$$;
