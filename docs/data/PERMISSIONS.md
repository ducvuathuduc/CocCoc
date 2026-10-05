# Permissions and trust enforcement

Appwrite table and row permissions are additive: a broad table read grant defeats per-row privacy. Row permissions work only with Row Security enabled. [Official permissions](https://appwrite.io/docs/products/databases/tablesdb/permissions).

| Resource | Table/bucket permissions | Row/file permissions | Writer |
|---|---|---|---|
| Every l_ business table | no client read/create/update/delete | no client grant | Learning privileged adapter only |
| p_profiles/rewards/ledger/follows/quests/leagues/deletions | no client grant, Row Security enabled | no client grant; public API projection enforces opt-in | Progress only |
| p_notifications | no broad table grant, Row Security enabled | read(Role.user(userId)); no client writes | Progress |
| All a_ tables | no client grant | no client grant | AI |
| learning-assets bucket | no broad bucket read/write, File Security enabled | published l_ file read(Role.any()); drafts/private a_ none | Learning content CLI / AI within owned prefix |
| Function execute access / public domains | Any needed for direct HTTP | authenticate every protected route; /health only public | verify JWT, then domain authorization |
| Maintainer content publish | verified JWT + server-authoritative maintainer team membership | no trusting nickname/header role | Learning |
| Internal consumers | no user auth sufficient | HMAC verification and event/body dedupe | allowlisted sender/key ID |

Use a new JWT SDK client per request, Account.get to establish subject, and a separate privileged storage client for controlled business writes. A client-supplied userId is rejected in owner-only commands; derive subject from authenticated account. Never initialize one global SDK client and swap JWTs between concurrent requests.

API-key scopes restrict capability classes, not assumed table ownership. Function dynamic keys are configured to minimum documented scopes (row read/write and file operations only as needed; user administration solely Progress deletion path). P1 reads current scope identifiers from Cloud reference/console, creates a checked deployment manifest, and tests denied extra operations. Do not invent unsupported resource restrictions. Restrict each adapter's table/bucket-file prefix allowlist; tests assert no cross-owner access. This is logical service isolation within a trusted project.

Private profile API excludes email, identities, tokens, deletion internals and raw transcripts. Public profile shows only opted-in nickname/avatar/achievement/stats summary. Leaderboard members have opt-in pseudonyms. Storage file IDs are validated against owner records; knowledge of an ID is not permission.

Negative tests: other user JWT, missing JWT, expired JWT, forged x-appwrite-user-id, forged schedule header, header injection/HMAC mismatch, direct table write, broad table permission accidental grant, disabled Row/File security, traversal assetId, malicious JSON, repeated body under same event ID. A failed probe blocks the deployment gate.
