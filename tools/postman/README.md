# CocEnglish Postman assets

Generated Postman Collection v2.1 and two public environments for every operation in
[`docs/api/openapi.yaml`](../../docs/api/openapi.yaml) (valid JSON despite the `.yaml` name).

| File | Purpose |
|---|---|
| `CocEnglish.postman_collection.json` | All 91 current OpenAPI operations plus positive/idempotency chains. Generated; do not hand-edit. |
| `CocEnglish-local.postman_environment.json` | Loopback URLs and empty secrets for `pnpm dev:services`. |
| `CocEnglish-TEST-template.postman_environment.json` | Placeholder TEST URLs and empty secrets. Fill them locally; never commit real values. |
| `generate.mjs` | Deterministic generator. No third-party dependency. |
| `check.mjs` | Coverage, secret, regeneration and HMAC-vector gate. |

## Coverage

| Owner folder | Baseline operations |
|---|---:|
| Learning (business routes) | 21 |
| Progress (business routes) | 49 |
| AI (business routes) | 11 |
| Internal (`/health`, `/ready`, `/internal/*`) | 10 |
| **OpenAPI total** | **91** |

The collection also contains 53 scenario/chain requests (144 requests total). Every baseline
request carries an `OpenAPI operation:` marker, so `check.mjs` can prove exact coverage and reject
duplicates, stale operation IDs or a missing operation.

## Start the local services

From the repository root, with the portable Node 22 toolchain:

```sh
export PATH="/c/FPT/PRM193/node-v22.23.3-win-x64:$PATH"
pnpm install --frozen-lockfile
COC_DEV_AUTH=1 pnpm dev:services
```

Ports: Learning `4101`, Progress `4102`, AI `4103`, bound to `127.0.0.1` only. Dev stores are
in-memory. All three services accept the explicit opt-in dev identity
(`COC_DEV_AUTH=1`, `Authorization: Bearer dev-<id>`); without it, user routes fail closed. The
hosted bundles never include this adapter.

`/ready` is expected to return **503 `SERVICE_NOT_CONFIGURED`** locally: an in-memory adapter is
never admitted for readiness. `/health` returns 200. Do not describe this as cloud or durable
integration.

`/health` and `/ready` are represented once each because OpenAPI defines them once for the shared
runtime. Their baseline requests use `learning_base_url`; change only the base URL in a duplicated
request, or run `curl`, if you want to probe Progress and AI too.

## Import and select an environment

1. Postman: **Import** -> select the collection and both environment files from this directory.
2. Select **CocEnglish Local** in the environment selector.
3. Fill the local secrets in Postman (they are intentionally empty in git):
   - `token_a` = `dev-user-a`
   - `token_b` = `dev-user-b`
   - `token_maintainer` = `dev-maintainer` (optional; internal requests use HMAC, not a token)
4. Leave `service_signing_mode=dev-keyring`, the `service_key_id_*` values (`dev-learning`, etc.)
   and the empty `service_secret_hex_*` entries as generated. In this mode the collection
   pre-request script derives the well-known dev key exactly like
   [`services/shared/src/testing/dev-keyring.ts`](../../services/shared/src/testing/dev-keyring.ts):
   `sha256("cocenglish-dev-only:" + sender)`. These are local-only values, not hosted secrets.

For the TEST template, select **CocEnglish TEST template**, replace the three `.test.invalid`
base URLs, set `service_signing_mode=keyring`, and fill `service_key_id_<sender>` plus
`service_secret_hex_<sender>` (32+ bytes of hex) from the secure keyring used by `COC_SERVICE_KEYS`.
Every secret field is empty in the committed files; keep it that way. Do not export or commit a
populated environment.

## Token acquisition

- Local: start with `COC_DEV_AUTH=1`, then use `dev-user-a` / `dev-user-b` as above. The dev
  adapter strips `dev-` and uses `user-a` / `user-b` as the subject. Never use these tokens outside
  loopback dev.
- TEST: sign in through the official Appwrite Account SDK, call `createJWT()` after the session
  exists, and paste the short-lived JWT (approximately 15 minutes) into `token_a` / `token_b`.
  Business services verify it with `Account.get`; decode-only tokens are not accepted. Refresh by
  creating a new JWT; do not paste a session cookie, API key or admin key.
- Internal routes never use a bearer token. They require `X-Service-Key-Id`,
  `X-Service-Timestamp` and `X-Service-Signature`, which the collection pre-request script
  computes.

## HMAC signing (internal requests)

The collection-level pre-request script mirrors
[`services/shared/src/service-hmac.ts`](../../services/shared/src/service-hmac.ts):

```text
timestamp \n METHOD \n canonicalPathAndCanonicalQuery \n sha256hex(rawBody)
```

- Canonical path: decode each segment, reject empty/dot/`..`/encoded-slash segments, re-encode per
  RFC 3986.
- Canonical query: decode, reject duplicate/unknown keys, sort keys by code unit, re-encode with
  uppercase `%XX`, prefix `?` only when non-empty.
- Raw body is resolved from Postman variables **before** hashing; request bodies for internal
  routes contain no unresolved placeholders on the wire.
- Default senders: `/ready` maintainer, `/internal/events` learning (sample
  `lesson.completed.v1`), `/internal/outbox-watermark` progress, `/internal/billing/notifications`
  maintainer, `/internal/jobs/*` scheduler. The script refuses unknown senders and senders outside
  the route policy. Scenario requests may deliberately choose a valid but unauthorized key to
  prove the receiver allowlist; the helper header `X-Coc-Signing-Sender` is removed before sending.
- `check.mjs` compares the embedded signer against three vectors produced by the real
  `service-hmac.ts` signer (`/ready`, watermark query, Unicode event body) and checks canonical
  query rejection, duplicate query rejection, dot segments and body tampering.

Mobile clients never sign internal requests.

## Run order

The collection order is:

1. **Learning / Golden path (enroll -> answers -> complete -> rewards)**. Run this first on freshly
   restarted services. It initializes both synthetic users, makes them public, grants simulated
   MAX to A, discovers the seeded course/lesson, starts a session, builds an answer plan from the
   returned bundle, answers up to 20 exercises, completes the session, and reads the credited
   reward from Progress.
2. **Learning / Idempotency (Learning)**. Enroll, start and abandon replay with the same key/body;
   changed-body requests must return 409 `IDEMPOTENCY_CONFLICT`.
3. **Progress / Idempotency (Progress)**. Simulated MAX purchase replay for B, then a changed
   product with the same key -> 409.
4. **AI / Idempotency (AI)**. Scripted TURN lease replay, changed scenario -> 409, then close.
5. **Ops baseline folders** under each owner. These assert that the status is one of the statuses
   documented in OpenAPI, that JSON is returned, and that any error uses the canonical envelope.
   They are contract/smoke checks, not a promise that every operation can succeed from an empty
   in-memory store.
6. **Internal / Idempotency and HMAC negatives (Internal)**. Signed delivery accepted, same event
   replayed, changed payload -> 409, AI key impersonating Learning -> 403, unsigned -> 401.
7. **Internal baseline** health/readiness, watermark, scheduler ticks, billing notification.

If you run individual folders, preserve this order or restart services first. IDs and revisions are
captured into the selected environment by test scripts; do not guess them. The environment ships
with empty session/completion/purchase/etc. values on purpose.

## Expected results

- `/health` 200; dev `/ready` 503 `SERVICE_NOT_CONFIGURED`.
- Golden path: exact 200 at each step; completion reports all originals graded; rewards report
  `status=credited`, a matching `completionId` and `studyXp > 0`.
- Idempotency: exact 200 on first write and replay (same key + same body); exact 409
  `IDEMPOTENCY_CONFLICT` for a changed body with the same key. Replays must never mint a second
  session, purchase or lease.
- AI: capabilities 200; tutor 200 (scripted/fallback); TURN voice session 200; a valid 0.1 s silent
  WAV fixture is included in `wavBase64`/`audioSha256`, so TURN speech and assessment are testable
  without a provider. Assessment returns 202 with null scores and `AZURE_DISABLED` in dev. LIVE
  native leases would return 503 `NATIVE_LIVE_DISABLED`; the collection intentionally uses TURN.
  Conversations require MAX, which the golden path grants through a simulation purchase.
- State-dependent operations may return documented 400/403/404/409/503 (for example a quest not
  complete, an item not in the catalog, a promo code that does not exist, or publish without a
  maintainer token). Those requests show the exact status and envelope rather than claiming
  business success.
- Internal event: first signed delivery `accepted`, identical replay `replayed`, changed payload
  409, unauthorized sender 403, unsigned 401.
- No cloud, durable, paid-provider or device result is claimed by this collection.

## Synthetic reset

Stop `pnpm dev:services` with Ctrl+C and start it again. All Learning/Progress/AI in-memory rows,
revisions, sessions, purchases and idempotency receipts disappear. Then reselect the local
environment and run the Golden path again. Do **not** run `schema:apply`, reset a cloud project or
delete Appwrite data for this. In the Postman UI, clear the environment's captured values only if
you also restart the services; otherwise a captured ID can point at a restarted empty store.

## Run with an existing runner (optional, no heavy install)

The repository also has a lightweight execution path requiring only the existing
Node runtime:

```sh
pnpm postman:test
pnpm postman:run:local
```

`run-local.mjs` starts three isolated in-memory services on loopback ports
25101–25103 with explicit dev identities, executes the generated collection's
current synchronous `pm` script subset and sends actual HTTP requests. It refuses
external URLs/redirects and unsupported script APIs, then closes its services.
It is specific to this trusted generated collection, not a general Postman or
Newman implementation. No populated environment is exported.

Results are written to ignored `.cache/postman-local-result.json`. The verified
run sends 137 requests, executes all 91 baseline operations and passes 408
assertions. Seven unused answer slots are explicitly skipped after the 13 authored
exercises. Baselines allowing documented negative statuses remain contract smoke
checks; those must not be reported as successful business journeys. This proves
local in-memory behavior only, not durable Appwrite, cloud or provider acceptance.

If `newman` is already available, run the whole collection (the local environment still has empty
secrets, so pass the dev tokens as CLI environment variables):

```sh
newman run tools/postman/CocEnglish.postman_collection.json \
  -e tools/postman/CocEnglish-local.postman_environment.json \
  --env-var token_a=dev-user-a \
  --env-var token_b=dev-user-b \
  --reporters cli
```

Or run the ordered positive chain only:

```sh
newman run tools/postman/CocEnglish.postman_collection.json \
  -e tools/postman/CocEnglish-local.postman_environment.json \
  --env-var token_a=dev-user-a \
  --env-var token_b=dev-user-b \
  --folder "Learning" \
  --folder "Golden path (enroll -> answers -> complete -> rewards)"
```

`--folder` selection still executes the selected folder in collection order; use one `--folder`
per desired folder or run the whole collection. If `newman` is not installed, open the collection
in Postman. Do not install Newman or other heavy tooling solely for this collection unless you
choose to; `npx --no-install newman --version` is the non-installing availability check.

## Regenerate and verify

```sh
export PATH="/c/FPT/PRM193/node-v22.23.3-win-x64:$PATH"
node tools/postman/generate.mjs     # deterministic; safe to run twice
node tools/postman/check.mjs        # coverage, secrets, bytes, HMAC vectors
pnpm postman:check                  # same check via package.json
```

`check.mjs` fails if any OpenAPI operation is missing, a baseline is duplicated, a request moved
outside its owner folder, a JSON body is malformed after variable substitution, an environment
secret is non-empty, regeneration differs from the committed files, or the embedded signer differs
from the service HMAC vectors.

## Notes and limits

- The collection is generated from the current spec; when OpenAPI changes, regenerate and commit
  the collection and environments together.
- Baseline bodies are minimal valid JSON generated from the request schemas, with captured IDs and
  revisions substituted where the contract allows. No endpoint is invented.
- `deleteAccount`, family join, gift redemption and referral redemption act as token B; all other
  user requests use token A.
- Provider-disabled behavior is represented honestly: no fake pronunciation score, no transcript,
  no paid provider call.
- No Newman/Postman CLI was available in the generating environment, so the collection itself was
  not executed here. The generated HMAC script was exercised against the live loopback dev
  services for `/ready`, `/internal/events`, the watermark and a scheduler tick; those checks are
  separate from a full Postman runner result.
