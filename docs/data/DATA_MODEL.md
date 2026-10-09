# Data model and ownership

One serverless TablesDB database, ID cocenglish. Row/table/index APIs, not mixed DocumentsDB collection APIs. Native database relationships are unnecessary; use IDs and owner validation. Appwrite supports atomic staged row operations and conflict detection; see [transactions](https://appwrite.io/docs/products/databases/tablesdb/transactions).

Types: id=ASCII opaque string≤36; timestamp=UTC ISO8601 datetime; revision=integer≥0; text has explicit maximum; JSON means validated JSON **encoded into a string column**, not an assumed native JSON column. Large content is in Storage. Every mutable row has revision, createdAt, updatedAt; these are project fields beside Appwrite system fields. Deterministic IDs are first32 hexadecimal characters of SHA-256(namespace|stableParts), with collision detection; external event/operation IDs are UUID. Appwrite IDs must satisfy platform constraints.

Every listed unique index is created and awaited before enabling writes. Composite queries use explicit indexes. No default broad client table permission; [PERMISSIONS](PERMISSIONS.md) governs every table.

## Tables

| Table / owner | Columns and invariants | Indexes / retention |
|---|---|---|
| l_courses / Learning | courseId, sourceLocale≤16, targetLocale≤16, title≤120, publishedVersion≤36, status DRAFT/PUBLISHED/RETIRED, manifestFileId | unique(sourceLocale,targetLocale); key(status,courseId); immutable published pointer updates |
| l_content_versions / Learning | courseId, versionId, manifestFileId, manifestSha256(64), schemaVersion int, publishedAt, retiredAt nullable, rewardMappingJson≤16384 | unique(courseId,versionId); keep published versions≥90 days |
| l_enrollments / Learning | userId, courseId, courseVersion, frontierNodeOrder int0..23, completedLessonsJson≤16384, masteredNodesJson≤4096, placementUsed bool | unique(userId,courseId); key(userId); monotonic frontier, version mapping on course upgrade |
| l_active_slots / Learning | userId,courseId,sessionId,expiresAt | deterministic user/course ID; unique(userId,courseId); released in session completion/abandon/expiry transaction |
| l_sessions / Learning | userId,courseId,lessonId,lessonVersion,rewardIdentity,mode LESSON/REVIEW/MASTERY/PLACEMENT, source ONLINE/OFFLINE,status ACTIVE/COMPLETED/ABANDONED/EXPIRED,bundleHash,bundleSnapshotJson nullable≤65536,nextOriginalOrdinal0..20,retryPass0..2,assisted bool,startedAt,expiresAt,completedAt nullable,resultJson≤8192 | key(userId,status); key(userId,completedAt); completed retained1year for demo dedupe |
| l_answers / Learning | sessionId,userId,exerciseId,attemptOrdinal0..2,answerJson≤8192,correct bool,assisted bool,substituted bool,receivedAt,resultJson≤4096 | unique(sessionId,exerciseId,attemptOrdinal); key(sessionId,receivedAt); same session retention |
| l_review_items / Learning | userId,courseId,vocabularyId,skillId,stage0..4,dueAt,firstAttemptWindowJson≤4096,lastReviewedAt | unique(userId,courseId,vocabularyId); key(userId,dueAt); max20 evidence window |
| l_reports / Learning | userId,exerciseId,lessonVersion,category CONTENT/ANSWER/AUDIO/OTHER,note≤512,status OPEN/CLOSED | key(status,createdAt); 90days after closed |
| l_receipts / Learning | userId,operation,key,bodyHash,statusCode,responseJson≤16384,expiresAt | unique(userId,operation,key); 30days; durable session IDs prevent late duplicate side effects |
| l_outbox / Learning | eventId,type,schemaVersion,aggregateId,occurredAt,payloadJson≤16384,attempt,nextAttemptAt,leaseOwner nullable,leaseUntil nullable,status PENDING/LEASED/ACK/DEAD,ackAt nullable | unique(eventId); key(status,nextAttemptAt); key(status,occurredAt); ACK90days; DEAD retained until repaired |
| l_inbox / Learning | eventId,type,bodyHash,appliedAt | unique(eventId); deletion dedupe1year |
| p_profiles / Progress | userId,nickname≤40,avatarId nullable,publicOptIn bool,emailVerifiedSnapshot bool,dailyGoal5/10/15,learningZone≤64,pendingZone nullable,zoneEffectiveAt nullable,lastZoneChangedAt,deletedAt nullable | unique(userId); key(publicOptIn,nickname); no email/password/raw identities |
| p_zone_history / Progress | userId,zone≤64,effectiveAt | unique(userId,effectiveAt); key(userId,effectiveAt); immutable history |
| p_rewards / Progress | userId,studyXp int≥0,leagueXpLifetime int≥0,gems int≥0,freezeSlots0..2,currentStreak0..365,bestStreak0..365,lastQualifiedDay nullable | unique(userId); ledger-derived, never client-writable |
| p_reward_ledger / Progress | eventId,completionId,userId,rewardIdentity,kind INITIAL/FIRST/REPLAY/QUEST/FREEZE,studyXpDelta,leagueXpDelta,gemsDelta,learningDay≤10,leagueWeek≤10,occurredAt,capped bool | unique(eventId,kind); unique(userId,completionId,kind); key(userId,learningDay); append-only; non-lesson commands use deterministic operation resource ID as completionId |
| p_first_rewards / Progress | userId,rewardIdentity,completionId | unique(userId,rewardIdentity); permanent until account deletion; protects replays/version remaps |
| p_day_activity / Progress | userId,day≤10,zone≤64,active bool,protected bool,studyXp int,replayXp int,completedLessons int,originalCorrect int,reviewSessions int | unique(userId,day); key(userId,day); last365days for V1 streak history plus archived export |
| p_freeze_ledger / Progress | userId,operationId,action BUY/CONSUME,day nullable,gemsDelta,slotDelta | unique(userId,operationId); CONSUME ID is hash(userId,day); append-only1year |
| p_quests / Progress | userId,period DAY/MONTH/WEEK,periodKey,questId,metricValue,target,claimed bool,claimOperationId nullable | unique(userId,period,periodKey,questId); key(userId,periodKey); daily/monthly/friend templates in SRS |
| p_follows / Progress | fromUserId,toUserId,status ACTIVE/BLOCKED | unique(fromUserId,toUserId); key(toUserId,status); forbid self follows |
| p_friend_quests / Progress | weekId,pairId,userIdsJson≤128,target10,count,claimedUserIdsJson≤128,membershipFrozenAt | unique(weekId,pairId); key(weekId); max2 members |
| p_league_members / Progress | weekId,cohortId,userId,tier0..9,eligibleXp,lastXpAt nullable,rank nullable,settled bool | unique(weekId,userId); key(weekId,cohortId,eligibleXp,lastXpAt,userId); owner sorts last tie explicitly |
| p_league_runs / Progress | weekId,cohortId,status OPEN/SETTLING/CLOSED,watermarkAt nullable,checkpointUserId nullable,closedAt nullable,snapshotJson≤32768 | unique(weekId,cohortId); max30 members; immutable closed result |
| p_activity / Progress | eventId,userId,kind MILESTONE/QUEST/STREAK,publicSummary≤160,visible bool | unique(eventId); key(userId,createdAt); only opt-in public summaries |
| p_achievements / Progress | userId,achievementId,earnedAt,sourceEventId | unique(userId,achievementId); immutable until account deletion |
| p_notifications / Progress | userId,completionId,status PENDING/CREDITED,profileRevision,rewardRevision | unique(userId,completionId); owner-read row; realtime hint, 30days |
| p_inbox / Progress | eventId,type,bodyHash,appliedAt,resultJson≤2048 | unique(eventId); retain1year; rejects payload substitution |
| p_outbox / Progress | same structural fields as l_outbox; account.deleted.v1 targets Learning/AI with target acknowledgements | key(status,nextAttemptAt); keep deletion until all owners acknowledge |
| p_receipts / Progress | same receipt shape, own commands only | unique(userId,operation,key); 30days |
| p_deletions / Progress | userId,requestId,status REQUESTED/REVOKED/PURGING/COMPLETED,ownerAcksJson≤1024,requestedAt,completedAt nullable | unique(userId); tombstone stops initialization/rewards until complete |
| a_voice_sessions / AI | userId,sessionId,providerAlias,mode LIVE/TURN,status RESERVED/ACTIVE/CLOSED/EXPIRED,createdAt,expiresAt,lastHeartbeatAt,epoch,consumedSeconds0..180,configVersion | unique(sessionId); key(userId,status); no provider token persisted; metadata7days |
| a_active_slots / AI | userId,sessionId,expiresAt,epoch | deterministic userId ID; unique(userId); atomically reserved with a_usage; no second active native grant |
| a_usage / AI | userId,utcDay,liveReservedSeconds,liveUsedSeconds,liveGrants,textRequests,recordedSpeechSeconds,recordedReservedSeconds,reservationIdsJson≤16384 | unique(userId,utcDay); live used+reserved≤600; grants≤2; text≤100/day; recorded used+reserved≤600s/day including TURN/assessment retries; expire90days |
| a_jobs / AI | userId,jobId,kind TUTOR/ASSESSMENT,status QUEUED/RUNNING/SUCCEEDED/FAILED/EXPIRED,referenceId,locale,inputHash,audioFileId nullable,leaseUntil nullable,attempt,dispatchState NOT_SENT/CLAIMED/SENT/AMBIGUOUS,reservedSeconds,chargedSeconds,resultJson nullable≤32768,expiresAt | result strictly OpenAPI TutorResult/Assessment with scoreState, nullable metrics, locale/reference hash/provider/model; unique(jobId); key(status,createdAt); key(userId,createdAt); audio24h/results7days |
| a_receipts / AI | own receipt shape; voice stores only sessionId/expiry/state, never token; native same-key retry never remints, uses VOICE_TOKEN_DELIVERY_UNCERTAIN | unique(userId,operation,key); 30days |
| a_inbox / AI | deletion eventId/bodyHash/appliedAt | unique(eventId); 1year |
| a_outbox / AI | same structural fields as l_outbox, only account.purged.v1 acknowledgement | unique(eventId); key(status,nextAttemptAt); redacted acknowledgement retained until Progress accepts |

No table is freely modified by another service. The database ID is shared for cost, not a shared domain model. Consumers store only validated event projections; private profile reads use Progress API. Client read access is limited to published files and own p_notifications.

## ERD / reference graph

~~~mermaid
erDiagram
  APPWRITE_USER ||--o{ L_ENROLLMENT : subject
  L_COURSE ||--o{ L_CONTENT_VERSION : publishes
  L_ENROLLMENT ||--o{ L_SESSION : opens
  L_SESSION ||--o{ L_ANSWER : records
  L_SESSION ||--o{ L_OUTBOX : emits
  APPWRITE_USER ||--|| P_PROFILE : owns
  APPWRITE_USER ||--|| P_REWARDS : owns
  P_REWARDS ||--o{ P_REWARD_LEDGER : derives
  P_PROFILE ||--o{ P_DAY_ACTIVITY : calendar
  P_PROFILE ||--o{ P_LEAGUE_MEMBER : opts_in
  P_PROFILE ||--o{ A_JOB : authorizes
  P_PROFILE ||--o{ A_VOICE_SESSION : authorizes
~~~

Diagram links are logical references, not Appwrite cross-service foreign keys.

## Storage bucket and content schema

Bucket learning-assets, fileSecurity enabled. File IDs deterministic hash from owner/type/content hash. Published l_ assets read public; draft assets no client permission; temporary a_ audio only AI server credential. Prefix is an app convention, not bucket-level security. No mobile upload permission; assessment audio is bounded base64 to AI, which writes privately.

LessonBundle fields are exactly OpenAPI: schemaVersion=1, course/node/lesson/version/reward identifiers, title/skills, optional guideText, typed exercises, assets, gradingRulesVersion, manifestHash, signatureKeyId and signature. Normal lesson has10 originals; generated review5–20. Exercise gradingRule holds acceptedText/choice/token/pair rules and normalization flags. fillBlank has one authored blank and a text answer in V1. Retries reuse the original immutable item. PairAnswer carries actual leftId/rightId matches; compare against authored Pair.left.id/Pair.right.id, reject duplicates/unknown IDs. Publication rejects contradictory rules, empty accepted text or missing media alternative. Alternative exercise may not itself contain alternatives, preventing recursive bundles.

Content integrity: RFC8785 JCS-canonicalize the bundle with only manifestHash and signature omitted; preserve all string codepoints and include signatureKeyId. SHA-256 of these UTF-8 bytes is manifestHash; Ed25519 signs the same bytes, encoded base64url without padding (86 chars). Node22 crypto signs/verifies; Flutter cryptography verifies with public32-byte key selected from embedded keyId allowlist. Private signing key stays in author secret store/server configuration. Reject unknown key/hash/signature before caching; no runtime key download from untrusted content. P4 has shared Dart/TS canonical bytes/signature fixtures including Unicode, reordered keys and tampering. Source: [JCS](https://www.rfc-editor.org/rfc/rfc8785), [Node22 crypto](https://nodejs.org/docs/latest-v22.x/api/crypto.html).

Publisher semantic checks beyond JSON shape: choice/image/listen/story require correctChoiceId in choices; token exercises require a nonempty exact correctTokenIds sequence of known unique IDs; pair rule correctPairIds is exactly the full declared pair set (no hidden subset), with unique left/right IDs; text/dictation/fill/speech require nonempty curated acceptedText. Normal bundle contains exactly10 originals; assets/alternatives reference existing verified IDs; alternatives preserve skills and terminate at depth1. dialogueTurn is a scripted reference response; open conversational calls are separate practice and never LLM-graded course answers.

CourseManifest schema in OpenAPI owns section/unit/node membership and lesson file indexes: seed exactly2sections/6units/24ordered nodes,2lessons/node,48ordinary bundles plus one10-item placement bundle. Sections/units/nodes must reference each other consistently and orders0..23 are contiguous; bundle indexes map exact immutable lessonVersion/rewardIdentity/fileId/raw-file SHA-256. A placement bundle uses reserved sectionId/unitId/nodeId=placement and order0, excluded from ordinary node membership. Generated review uses review sentinels and order0. CourseManifest uses the same JCS/hash/signature algorithm. l_content_versions.manifestSha256 and PublishRequest.manifestSha256 refer to the full uploaded file's raw bytes, distinct from the object's manifestHash computed with self-hash/signature omitted.

Learning holds a dedicated server-only review signing key to sign generated private review bundles; its public key ID joins the app's embedded allowlist. Published author key and review key are separate, both rotated with retained verification keys during90-day version support. No temporary review bundle is publicly uploaded. Private signing keys are secret configuration, not generated into app assets/Git. P1 proves crypto/config loading; P4 proves publication and P6 review verification.

Asset fields: fileId, sha256, mime, bytes, durationMs optional, width/height optional, locale, voice, speed, provider, modelVersion, altText. Assessment/TURN input: PCM WAV mono16kHz≤15s/480044 bytes, MIME audio/wav; base64 field≤640064 chars and full JSON request≤750000 UTF-8 bytes. No arbitrary URL fetch from a mobile-supplied asset URL.

## Transaction boundaries

Learning start touches active slot, session and receipt. Answer touches session revision, unique answer and receipt; aggregate read is staged/touched so concurrent commands conflict. Completion touches session, active slot, enrollment, up to20 review items, receipt and outbox. Offline full replay has≤60answer writes plus those bounded rows, below Free100 operations. Published manifest pointer flip is separate from asset uploads; incomplete uploads stay unreferenced and are cleaned later.

Progress consume touches unique inbox, first-reward marker when applicable, reward ledger, aggregate, day counters, quest counters, notification and receipt; recompute streak uses paginated day reads and conditional aggregate revision. A conflict restages every dependent read/write; no stale aggregate overwrite. Caps and first-reward decision use rows written in the same transaction. League close is checkpointed at≤30-member cohort boundary, and final result is published only after all cohort rows and watermark verified.

AI reserves user daily allowance, active slot and session/job in one transaction before outbound provider call. Provably failed token mint releases reservation; ambiguous mint consumes the entire180s admission budget. Successful mint moves180s reserved→used permanently for the UTC day; closing/heartbeat does not refund it. Expiry releases active slot only. Provider token never stored in logs/database.

Profile initialization writes p_rewards plus one INITIAL ledger credit of20 gems, profile, zone history and receipt atomically. Every later wallet delta also has a ledger row; totals reconcile including initialization. Deletion across more than100 rows uses paginated owner checkpoints; final private-row purge and account.purged.v1 outbox acknowledgement commit together, not a best-effort callback. Learning uses l_outbox; AI uses a_outbox.

Receipts store immutable small response fields plus resource/version references. Start-session receipt reconstructs its original immutable bundle rather than storing a >16KB duplicate response. REVIEW uses a private server-generated bundle snapshot≤64KB, built from due/mistake items from retained published versions; read through owner session API, never public file access. Lesson count is10; review count5–20. Placement starts before enrollment with expectedEnrollmentRevision=0, no reward/activity.
