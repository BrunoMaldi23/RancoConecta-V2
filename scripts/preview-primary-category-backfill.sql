-- Read-only candidates for published businesses with a missing primary category.
-- Propose only a sole active category across all active service rows.
select
  b.id as business_id,
  b.primary_category_id as current_category_id,
  case when count(distinct c.id) = 1 then min(c.id::text)::uuid end as proposed_category_id,
  case when count(distinct c.id) = 1
    then 'business_services -> subcategories.category_id'
    else 'MANUAL_REVIEW_REQUIRED'
  end as source,
  case when count(distinct c.id) = 1 then 'HIGH' else 'NONE' end as confidence
from public.businesses b
left join public.business_services bs on bs.business_id = b.id and bs.active
left join public.subcategories s on s.id = bs.subcategory_id
left join public.categories c on c.id = s.category_id and c.active
where b.publication_status = 'published' and b.primary_category_id is null
group by b.id, b.primary_category_id
order by b.id;
