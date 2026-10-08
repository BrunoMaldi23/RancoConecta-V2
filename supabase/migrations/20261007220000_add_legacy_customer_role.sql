-- Keep historical customer profiles without treating customers as a product role.
-- PostgreSQL requires a newly added enum value to be committed before it is used.
alter type public.app_role add value if not exists 'legacy_customer';
