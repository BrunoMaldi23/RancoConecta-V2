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

The migration also adds `protect_profile_privileged_fields()` so client-side profile updates cannot change `role` or `account_status`; those fields require a privileged server-side operation.

Known limitations:

- admin and super admin policies are intentionally deferred until secure server-side role management exists;
- payment and membership mutation from Flutter is not allowed;
- open service requests need a privacy-preserving provider discovery design before broader provider visibility is added;
- provider review replies currently permit updating a review row and should be narrowed through a secure RPC or column-level strategy later.

Service role keys must only live in backend environments such as Supabase Edge Functions.
