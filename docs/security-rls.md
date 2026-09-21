# Security and RLS

RLS is enabled for every app table in Sprint 0.

Initial policies allow:

- users to read and update their own profile basics;
- public reads for active catalog tables;
- public reads for published businesses and related public details;
- business owners to manage their own draft/pending/paused businesses and supporting records;
- customers to manage their own draft requests;
- providers to read directed requests for businesses they own;
- participants to read quotes and conversations;
- users to manage only their own favorites and notifications;
- public review reads with restricted review creation.
- active business members to read businesses they belong to;
- operation participants to read their related operations and operation events.

The migration also adds `protect_profile_privileged_fields()` so client-side profile updates cannot change `role` or `account_status`; those fields require a privileged server-side operation.

Known limitations:

- admin and super admin policies are intentionally deferred until secure server-side role management exists;
- payment and membership mutation from Flutter is not allowed;
- open service requests need a privacy-preserving provider discovery design before broader provider visibility is added;
- provider review replies are deferred until a secure RPC or column-level strategy exists.
- Storage buckets are created, but object-level write policies are deferred until avatar/business-media upload flows are designed.
- `business_members` is read-only to authenticated clients in Phase 0.2; member creation/role changes require a future controlled onboarding/admin flow.
- `operations` allows draft creation by the customer but does not allow client-side status updates. Sensitive transitions must be implemented with RPC or Edge Functions.
- `operation_events` is readable by participants but not insertable by clients; future events should be written by trusted database functions or backend workflows.

## Phase 1 multivertical update

The multivertical migration adds `user_can_manage_business(business_id)` as the shared membership-aware helper. It treats active `owner` and `manager` rows in `business_members` as management authority and keeps `businesses.owner_id` as a compatibility fallback.

Owners/managers can update routine business profile fields after publication. A trigger, `protect_business_sensitive_fields`, blocks client-side changes to `owner_id`, `business_type`, `publication_status`, and `verification_status`; those require privileged server-side/admin operations.

`plan_features` and active `commission_rules` are readable configuration. `business_sensitive_change_requests` can be created/read by managers of the business, preparing future review workflows. `business_offers` is public only for active offers on published businesses and manageable by business managers.

## Phase 1 onboarding RPCs

Flutter does not insert `businesses` and `business_members` separately. `create_business_draft` is the transactional entry point and derives `owner_id` from `auth.uid()`.

`update_business_draft` requires `user_can_manage_business` and only applies to `draft` or `changes_requested` businesses. It does not accept publication, verification, owner, membership, or commission values from the client.

`submit_business_for_review` verifies ownership, validates backend requirements, records audit, and sets `publication_status = pending_review`.

Business media storage write policies now use `user_can_manage_business_path(name)`, expecting the first storage folder segment to be the business id. `request-attachments` remains closed until request-level authorization is modeled.

## Phase 2 admin security

Admin authority is stored in `profiles.role` with `admin` and `super_admin`. Flutter never receives service-role privileges.

Admin actions use specific `SECURITY DEFINER` RPCs. Each function validates `current_user_is_admin()`, derives actor from `auth.uid()`, fixes `search_path`, and records workflow/audit data.

Normal providers cannot publish, reject, suspend, restore, or change `publication_status` directly. Public reads continue to be limited to `publication_status = published`.

Service role keys must only live in backend environments such as Supabase Edge Functions.
