-- PREPARED ONLY. Do not execute unless explicitly needed to restore the exact
-- grants observed immediately before 20261007160000 was applied.
-- Re-grants TRUNCATE to anon/authenticated on the 42 audited public tables;
-- re-grants EXECUTE to anon on the 12 audited RPCs; and restores PUBLIC EXECUTE
-- only on the 9 functions where that ACL was present before the hotfix.

grant truncate on table
  public.analytics_events,
  public.audit_logs,
  public.business_coverage,
  public.business_hours,
  public.business_media,
  public.business_members,
  public.business_offers,
  public.business_review_events,
  public.business_sensitive_change_requests,
  public.business_services,
  public.businesses,
  public.categories,
  public.commission_rules,
  public.communes,
  public.conversation_members,
  public.conversations,
  public.favorites,
  public.featured_placements,
  public.gastronomy_menu_categories,
  public.gastronomy_menu_items,
  public.gastronomy_table_reservations,
  public.locations,
  public.lodging_bookings,
  public.lodging_calendar,
  public.lodging_details,
  public.membership_plans,
  public.memberships,
  public.messages,
  public.notifications,
  public.operation_events,
  public.operations,
  public.payments,
  public.plan_features,
  public.profiles,
  public.quotes,
  public.regions,
  public.request_attachments,
  public.reviews,
  public.service_requests,
  public.subcategories,
  public.system_settings,
  public.user_consents
to anon, authenticated;

grant execute on function public.admin_analytics_summary() to anon;
grant execute on function public.admin_business_review_detail(uuid) to anon;
grant execute on function public.admin_business_review_queue(text, text, text, integer, integer) to anon;
grant execute on function public.admin_business_review_stats() to anon;
grant execute on function public.admin_get_business_review(uuid) to anon;
grant execute on function public.admin_list_users(integer, integer) to anon;
grant execute on function public.admin_publish_business(uuid) to anon;
grant execute on function public.admin_reject_business(uuid, text, boolean) to anon;
grant execute on function public.admin_request_business_changes(uuid, text) to anon;
grant execute on function public.admin_restore_business(uuid) to anon;
grant execute on function public.admin_suspend_business(uuid, text) to anon;
grant execute on function public.admin_update_whatsapp_settings(text, boolean, boolean, boolean, boolean) to anon;

grant execute on function public.admin_business_review_detail(uuid) to public;
grant execute on function public.admin_business_review_queue(text, text, text, integer, integer) to public;
grant execute on function public.admin_business_review_stats() to public;
grant execute on function public.admin_get_business_review(uuid) to public;
grant execute on function public.admin_publish_business(uuid) to public;
grant execute on function public.admin_reject_business(uuid, text, boolean) to public;
grant execute on function public.admin_request_business_changes(uuid, text) to public;
grant execute on function public.admin_restore_business(uuid) to public;
grant execute on function public.admin_suspend_business(uuid, text) to public;
