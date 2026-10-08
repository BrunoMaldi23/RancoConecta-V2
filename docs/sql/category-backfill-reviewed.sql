-- PREPARED ONLY. Requires explicit approval and a fresh preview immediately
-- before use. Default behavior is rollback; this file is not a production apply.
begin;

create temporary table phase329_category_candidates (
  business_id uuid primary key,
  proposed_category_id uuid not null,
  source text not null check (source = 'business_services -> subcategories.category_id')
) on commit drop;

insert into phase329_category_candidates values
  ('33595129-2e00-4abb-bb72-61c5f5b9f990', '2b0fff8e-10fd-488f-9471-31a8ab447467', 'business_services -> subcategories.category_id'),
  ('b163593b-ce67-458f-92c8-faeb6b4d74b5', '9a583338-a707-4d47-9985-557b7b189aa1', 'business_services -> subcategories.category_id'),
  ('e325ad8f-7720-4517-abff-1ec0050676f6', '6521897c-a7c7-46ff-95f4-587cb252c0ce', 'business_services -> subcategories.category_id');

-- PRE-ASSERT: exactly three published, still-NULL businesses; proposed active
-- category matches their only active service category; no ambiguity or missing evidence.
do $$
begin
  if (select count(*) from phase329_category_candidates) <> 3 then
    raise exception 'expected exactly three reviewed candidates';
  end if;
  if exists (
    select 1 from phase329_category_candidates c
    left join public.businesses b on b.id = c.business_id
    left join public.categories target on target.id = c.proposed_category_id and target.active
    where b.id is null or b.publication_status <> 'published'
       or b.primary_category_id is not null or target.id is null
       or (select count(distinct s.category_id)
           from public.business_services bs
           join public.subcategories s on s.id = bs.subcategory_id
           join public.categories cat on cat.id = s.category_id and cat.active
           where bs.business_id = c.business_id and bs.active) <> 1
       or exists (
         select 1 from public.business_services bs
         join public.subcategories s on s.id = bs.subcategory_id
         join public.categories cat on cat.id = s.category_id and cat.active
         where bs.business_id = c.business_id and bs.active
           and s.category_id <> c.proposed_category_id
       )
  ) then
    raise exception 'category pre-assert failed; refresh preview and stop';
  end if;
end;
$$;

create temporary table phase329_category_changed (
  business_id uuid primary key,
  category_id uuid not null,
  source text not null
) on commit drop;

with updated as (
  update public.businesses b
  set primary_category_id = c.proposed_category_id
  from phase329_category_candidates c
  where b.id = c.business_id
    and b.publication_status = 'published'
    and b.primary_category_id is null
  returning b.id, b.primary_category_id
)
insert into phase329_category_changed (business_id, category_id, source)
select u.id, u.primary_category_id, c.source
from updated u join phase329_category_candidates c on c.business_id = u.id;

-- POST-ASSERT: only three approved rows changed and each value equals evidence.
do $$
begin
  if (select count(*) from phase329_category_changed) <> 3
     or exists (
       select 1 from phase329_category_candidates c
       left join phase329_category_changed changed on changed.business_id = c.business_id
       left join public.businesses b on b.id = c.business_id
       where changed.business_id is null
          or changed.category_id <> c.proposed_category_id
          or b.primary_category_id <> c.proposed_category_id
     ) then
    raise exception 'category post-assert failed; rollback required';
  end if;
end;
$$;

select business_id, category_id, source from phase329_category_changed order by business_id;

-- Intentionally do not persist. Production apply must use a newly reviewed
-- transaction/script after human approval; the 3 other rows remain manual review.
rollback;
