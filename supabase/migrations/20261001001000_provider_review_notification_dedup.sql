create unique index if not exists notifications_provider_pending_review_once
on public.notifications (user_id, entity_id)
where type = 'provider_pending_review';
