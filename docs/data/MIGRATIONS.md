# Migration, content publishing and seeding

Schema is declared in infrastructure/appwrite during P1; exported console configuration is reviewed against this specification. Migrations have monotonic ID, owner, environment, checksum, dry-run diff and receipt. SDK method/column/index identifiers are resolved against pinned node-appwrite API; no imaginary JSON column or partial unique index.

Procedure: validate configuration → snapshot/export private data securely → create new columns/tables/indexes → await available status → verify permission probes → backfill in cursor batches≤50 → dual-read only during reviewed transition → enable new writer/version → smoke → retain rollback reads. Schema operations are outside row transactions. Default migrate command refuses dropping a populated table/column. Production deletes/resets require a separate explicit request.

Rollback: deploy prior compatible service artifact and repoint content publishedVersion to prior immutable manifest; do not delete new evidence/ledger. Contract change uses expand/contract and at least one compatible release before removing old fields. Retired content is readable90days, then outstanding offline work receives the documented rejection.

Seeds: deterministic course vi_en, sections a1_basics/a1_daily, six units with four nodes each, two lessons per node. Topics greetings, people, food, routines, places/directions, daily conversation. Each lesson has10 originals; distribute all12 exercise types across the seed, with text alternatives for every media item. One authored guidebook/story/listening node per unit; speaking scenarios introduced after basic vocabulary. Placement10 items samples units1–2. Seeds never import competitor user data or prompt an LLM during deterministic CI.

Fixture classes: guest intro; unlocked/locked/mastered path; perfect/mistake/assisted/replay lesson; offline pending/rejected; delayed reward; midnight/timezone/DST; speech denied/silence/native disconnected; private social/empty league/settling league; insufficient wallet; deleted account. Fakes and API fixtures share contract shapes, not private server entities.

Expected initial public assets≤100MB; private per-demo-user rows bounded by test cohort. Audio pre-generation is an explicit author tool run with quota preview; prefer recorded/bundled audio when no free allowance. Validate voice/speed/text cache key and asset hash before publishing. No live AI in seed generation during CI.

Backup: Appwrite Education/Pro may provide managed backups; [current pricing](https://appwrite.io/pricing) lists Pro daily/7-day retention, Free none. Keep a separate encrypted daily JSON export of authoritative content/profile/progress ledgers outside Git; keys outside archive. Before benefit expiry export and rehearse restoration. Auth passwords/identities are not portable application data; restored account mapping may require user re-login/recreation. Document ID mapping and no claim of seamless auth migration.
