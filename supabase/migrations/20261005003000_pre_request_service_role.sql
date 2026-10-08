-- PostgREST runs the pre-request hook as the JWT role. Edge Functions use
-- service_role for validated server-side writes, so it needs EXECUTE too.
grant execute on function public.reject_suspended_api_request()
to service_role;
