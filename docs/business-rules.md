# Business Rules

Initial stable states are stored in English enums. User-facing Spanish labels belong in Flutter localization and presentation mapping.

Core rules:

- users cannot self-assign administrative roles;
- businesses start as drafts and require future server-side review to publish;
- published businesses can be read publicly;
- service requests may be open or directed to a specific business;
- quotes belong to one request and one business, with one active row per pair;
- ratings must be between 1 and 5;
- prices and membership plan durations live in the backend;
- payments and membership activation require server-side authority.

Offline support is deferred. The architecture should later support read cache, favorite cache, drafts, and sync state. Payment operations must remain online.
