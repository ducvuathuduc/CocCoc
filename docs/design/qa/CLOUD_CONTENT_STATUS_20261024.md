# Cloud lesson content status — 2026-10-24

Direct read-only checks of the configured Appwrite project confirm that its public
`learning-assets` Storage bucket contains the current English v2 manifest and all 513 bundle
files: 512 course lessons plus one 10-question placement test. All downloaded bytes match the
committed SHA-256 values. The course has 6,384 exercises; placement adds 10. No files failed.
The manifest also matches the committed hash and names 16 units / 512 lessons.

This is new cloud-read evidence, distinct from the previous offline catalog verification.
No upload, seed, database write or deployment was performed in this status check.
See the [machine receipt](CLOUD_CONTENT_STATUS_20261024.json).

The database's `l_courses` published-version pointer and authenticated learning session were
not verified: anonymous hosted Learning `GET /v1/courses` returns `401 AUTH_REQUIRED`, and this
session has no Appwrite API key or authenticated service/user token. Public Storage availability
does not establish private database state, enrollment, grading, progress persistence or production
readiness. Media files were not downloaded in this cloud check. The existing web preview uses mock
data/auth and payment remains an internal simulation.

Remaining feature/UI work is tracked in the [Android reference audit](ANDROID_REFERENCE_AUDIT_20261024.md).
