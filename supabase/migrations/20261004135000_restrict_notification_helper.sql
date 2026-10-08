-- The helper is called by trusted review RPCs, never directly by a client.
revoke all on function public.notify_business_managers(uuid, text, text, text)
from public, anon, authenticated;
