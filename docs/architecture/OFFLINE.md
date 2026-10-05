# Offline and reconciliation protocol

The cache is a practice aid, not an authentication or competitive scoring authority. Drift stores per-user data under a user namespace. Login change wipes private tables and the in-memory token. Public immutable content may remain.

| Action | Classification | Behavior |
|---|---|---|
| Cached catalog/path/profile | OFFLINE_READ_ONLY | show freshness time; locked nodes stay locked; no secret/private cross-user cache |
| Downloaded unlocked lesson and its audio | OFFLINE_ALLOWED | persist local session/answers immediately; local rule engine gives provisional feedback |
| Offline completion / reports | QUEUE_AND_SYNC | persistent journal; server regrades exact content version before accepting |
| Local reminder, sound/speed/accessibility setting | OFFLINE_ALLOWED | local preferences; remote profile preference sync uses revision check |
| Login/OAuth/link/reset/delete/follow/freeze purchase/quest claim | ONLINE_REQUIRED | no optimistic success; retry after reconnect |
| Live tutor/cloud pronunciation/ranked league entry | ONLINE_REQUIRED | show bundled listening/shadowing or locally retained recording for explicit later upload; no fabricated score or automatic cloud-audio journal entry |

## Cache shape and budgets

One active unit plus next unlocked lesson prefetched; retain last two complete units. Catalog freshness 24h, path freshness 5min; offline path never unlocks new server-gated nodes. Course bundle ID includes courseVersion+lessonVersion; files use content SHA-256. Audio key = sha256(normalizedText|locale|voice|speed|provider|modelVersion|format). Use authored normal+slow assets rather than regenerate during a lesson.

Fetch getManifest for the enrollment's immutable courseVersion, validate signature/membership and derive exact lessonVersion/file IDs before downloading getBundle/assets. Guest uses the shipped signed manifest. Do not assume all lessonVersion values equal courseVersion. Only cache a unit after all required bundles/assets verify; incomplete download stays temporary and old complete unit remains usable.

SQLite transaction writes session snapshot and journal operation together before acknowledging UI. Audio/image files are written to a temporary file, verified, then atomically renamed. Cache total 200 MB, public audio 150 MB maximum; LRU eviction excludes current/pending bundle. Queue max 500 operations / 10 MB metadata; beyond that stop new offline sessions with an export/reconnect message. Raw recordings max 3 MB each, ten retained, TTL 24h unless user removes earlier.

## Sync journal

Fields: operationId UUID; userId; deviceId random install ID; kind=offlineCompletion/report/profilePreference; entityId; baseRevision; contentVersion; payload; payloadSha256; createdAtLocal informational; state=PENDING/SENDING/ACKNOWLEDGED/REJECTED; attempt; nextAttemptAt; lastErrorCode. Use server-returned time only for rewards. No ordering based on a manipulable client clock.

On boot, SENDING becomes PENDING. Replay serially per user, preserve local journal insertion order, at most one request in flight. Retry transient failures at 1s/5s/30s/2m/10m, capped 10m plus jitter; pause in background and on auth expiry. Stop authentication failures until restored session; permanent validation/content-stale failures become REJECTED with explicit reason and a repeat-lesson action. A success response and local journal acknowledgement are committed together.

Offline completion sends the full first-attempt log, bundle hash, local completion ID and unlocked enrollment version, not client XP. Server loads immutable published grading rules, validates exercise IDs/order/max attempts and starting eligibility, and computes results. Client cannot award XP. Repeated completion ID returns original receipt. Another device may have advanced frontier: accept valid practice completion, never roll back frontier, and never award a first-completion bonus twice.

**Reward policy:** offline completions receive ordinary study XP and current sync-day streak credit after validation, but **zero league XP**, no backdated streak, no speed/perfect competitive bonus. Offline provisional progress can mark a downloaded lesson practiced, but further path unlock waits for server sync. This resolves the otherwise impossible trust in offline timestamps/answers. V1 is not an anti-cheat hardened public competition.

Bundle signatures detect modified/corrupt bytes when verified against an embedded public key; they do not hide answer rules on the device. Course content revocation: retain published version 90 days; a revoked or expired version returns CONTENT_VERSION_RETIRED, retains user practice record locally, gives no authoritative completion, and offers current-version repeat.

## Conflict rules

Session answers are append-only by session/exercise ordinal; reused key with changed answer is rejected. Frontier is monotonic. Reward ledgers are append-only. Profile preferences use expectedRevision with server 409 returning current revision; user resolves language/timezone conflict explicitly. No last-write-wins for XP, streak, wallets or lesson completion. Social mutations remain online.

Realtime reconnect performs a full owner-authorized refetch; events may be duplicated or missing. It is never the recovery log. Cache corruption deletes only the affected user's cache fragment after preserving valid pending operations; journal corruption halts sync, exports nonsecret metadata and prompts repeat/reconnect, never guesses completions.
