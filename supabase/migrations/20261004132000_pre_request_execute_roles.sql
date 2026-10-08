-- PostgREST switches to the JWT role before invoking db_pre_request.
grant execute on function public.reject_suspended_api_request()
to anon, authenticated;
