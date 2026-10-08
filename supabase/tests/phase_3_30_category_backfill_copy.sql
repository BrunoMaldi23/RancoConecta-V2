-- Exercise the evidence-only category backfill against the restored snapshot.
-- The transaction is rolled back; production and source snapshot are untouched.
begin;
create temporary table phase330_category_candidates on commit drop as
select b.id as business_id,
       case when count(distinct c.id)=1 then min(c.id::text)::uuid end as category_id,
       count(distinct c.id) as evidence_count
from public.businesses b
left join public.business_services bs on bs.business_id=b.id and bs.active
left join public.subcategories s on s.id=bs.subcategory_id
left join public.categories c on c.id=s.category_id and c.active
where b.publication_status='published' and b.primary_category_id is null
group by b.id;
do $$ declare v_rows integer; v_candidates integer; v_manual integer; begin
  select count(*), count(*) filter(where evidence_count=1), count(*) filter(where evidence_count<>1)
  into v_candidates,v_rows,v_manual from phase330_category_candidates;
  if v_candidates <> 6 or v_rows <> 3 or v_manual <> 3 then
    raise exception 'unexpected evidence distribution: total %, objective %, manual %',v_candidates,v_rows,v_manual;
  end if;
  update public.businesses b set primary_category_id=c.category_id
  from phase330_category_candidates c
  where b.id=c.business_id and c.evidence_count=1 and c.category_id is not null
    and b.primary_category_id is null;
  get diagnostics v_rows = row_count;
  if v_rows <> 3 then raise exception 'expected 3 evidence-backed backfills, got %',v_rows; end if;
  if exists (select 1 from public.businesses b join phase330_category_candidates c on b.id=c.business_id
    where c.evidence_count=1 and b.primary_category_id is distinct from c.category_id) then
    raise exception 'backfill did not match its evidence category';
  end if;
  if exists (select 1 from public.businesses b join phase330_category_candidates c on b.id=c.business_id
    where c.evidence_count<>1 and b.primary_category_id is not null) then
    raise exception 'ambiguous businesses were changed';
  end if;
end $$;
rollback;
select 'phase 3.30 snapshot category backfill contract passed (rolled back)' as result;
