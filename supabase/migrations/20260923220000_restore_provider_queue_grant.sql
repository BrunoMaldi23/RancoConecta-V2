-- Restore RPC execute permission after 20260923170000 had to drop and
-- recreate provider_service_request_queue to change its RETURNS TABLE shape.

grant execute on function public.provider_service_request_queue(uuid, text)
to authenticated;
