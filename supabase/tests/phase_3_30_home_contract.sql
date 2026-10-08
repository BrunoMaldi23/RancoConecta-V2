-- Exercise the Home projection against the restored production schema.
do $$ declare v_rows bigint; begin
  select count(*) into v_rows
  from (
    select b.id, b.is_featured, b.accepts_requests, b.rating_avg,
      b.review_count, b.primary_category_id,
      count(bm.id) as media_count
    from public.businesses b
    left join public.business_media bm on bm.business_id=b.id
    left join public.categories c on c.id=b.primary_category_id
    where b.publication_status='published'
    group by b.id, b.is_featured, b.accepts_requests, b.rating_avg,
      b.review_count, b.primary_category_id
  ) home_projection;
  if v_rows = 0 then raise exception 'Home projection returned no published rows'; end if;
end $$;
select 'phase 3.30 Home projection contract passed' as result;
