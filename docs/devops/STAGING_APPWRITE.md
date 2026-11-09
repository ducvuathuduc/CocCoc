# Staging Appwrite project (independent of TEST)

Status (2026-11-09): **procedure and offline checks only; no staging project exists and nothing was created, deployed or applied.** The shared TEST project (`coccoc-test`, see [APPWRITE_SETUP](APPWRITE_SETUP.md)) is not staging: it trusts the published dev content key, its function domains are public, and several people write to it. Staging means a second, empty project that shares no id, domain, key or OAuth client with TEST.

Keys, secrets and who holds them stay in the [keys and config checklist](KEYS_AND_CONFIG_CHECKLIST.md); this file only adds what staging changes.

## Decisions a human must make first

| # | Decision | Why it blocks |
|---|---|---|
| D1 | Allow the live ops scripts to target a staging profile | `schema.mjs`, `ops.mjs` and `live-probe.mjs` run only with `APPWRITE_PROJECT_ENV=test`, `ALLOW_*=reviewed-test-project`, and a project id equal to `appwrite/ops/project.json`. A staging apply needs a reviewed change that reads the overlay and adds `reviewed-staging-project` gates. `appwrite/schema` is an exclusive change area, so one owner makes it. Until then nothing can be applied by script. |
| D2 | Who creates the project and accepts its cost | Creating a project, function executions and bandwidth can cost money; no agent creates one. |
| D3 | Staging login | Google OAuth is disabled in the overlay (a new OAuth client is its own task). Email/password stays. |
| D4 | Who holds the staging maintainer and test learner accounts | Publish, rollback, unpublish and the CMS all need real Appwrite users. |

## Files prepared

| File | Purpose |
|---|---|
| [`appwrite/ops/project.staging.example.json`](../../appwrite/ops/project.staging.example.json) | Overlay on `project.json`: only what must differ from TEST. |
| [`apps/mobile/config/staging.public.example.json`](../../apps/mobile/config/staging.public.example.json) | Public build defines for a staging APK. |
| `tools/scripts/staging-preflight.mjs` | Offline check that the filled-in files share nothing with TEST. |
| `tools/content/generate-content-key.mjs` | Makes the staging Ed25519 content key. |

`node tools/scripts/staging-preflight.mjs` exits 0 only when the overlay and the mobile profile are filled in and independent of TEST (different project, endpoint-consistent domains, no dev content key, no key material in files, a maintainer listed, the same project in the mobile profile). It exits 2 with `BLOCKED` while the files do not exist. A pass is not runtime evidence.

## Procedure

Each step lists what proves it. Every live step also needs D1 and the credentials named, which are set in the process environment, never in a file.

1. **Project isolation.** Create a new project in its own organization (D2). Record its id. Create one server API key for the setup operator and keep it in the vault. Confirm `projectId` differs from `6acc656d0025cc57bd81`. *Proof:* preflight `SAME_PROJECT_AS_TEST` absent.
2. **Overlay.** Copy the two example files to `appwrite/ops/project.staging.json` and `apps/mobile/config/staging.public.json` (both untracked), replace every `REPLACE_` value, run the preflight. *Proof:* `{"status":"PASS"}`.
3. **Content signing key.** `node tools/content/generate-content-key.mjs --key-id staging-content-1`. Put `publicKeyHex` in the overlay's `COC_CONTENT_PUBLIC_KEYS`. Store `seedHex` in the vault as `COC_CONTENT_SIGNING_SEED_HEX` with `COC_CONTENT_SIGNING_KEY_ID=staging-content-1`; the version published to staging is built with them (`tools/content/build-course.mjs`), because TEST's committed `v2` is signed by the dev key and staging refuses it. *Proof:* preflight `DEV_CONTENT_KEY` absent; a rebuild's manifest carries `signatureKeyId: staging-content-1`.
4. **Schema and Storage.** Offline first: `pnpm schema:plan && pnpm schema:test && pnpm seed:check`. Then apply with the staging profile (D1). Expected: the declared tables, indexes and the `learning-assets` bucket with File Security on and no bucket permissions. *Proof:* a staging `schema:check-live` equivalent with 0 missing, drift, extra or pending.
5. **Functions.** Declared once in `appwrite/appwrite.config.json` (`coc-learning`, `coc-progress`, `coc-ai`, `node-22`, 60 s). Apply the overlay's variables, let apply generate `COC_SERVICE_KEYS` as a secret variable, deploy each service (`pnpm appwrite:deploy -- --service learning`, D1). Keep `COC_LEARNING_ADMITTED=reviewed-cloud-gate` only after the cloud admission gates in [OPERATIONS](OPERATIONS.md) pass on staging. Optional media gate tuning: `COC_MEDIA_VERIFY_CONCURRENCY`, `COC_MEDIA_VERIFY_DEADLINE_MS`. *Proof:* `GET /health` on each domain returns 200 with the matching service and build id.
6. **Maintainer authorization.** Create the staging maintainer user and one learner user. Put the maintainer's user id in `COC_MAINTAINER_USER_IDS` (Learning) and `CMS_ADMIN_USER_IDS` (CMS). *Proof:* a learner token gets `MAINTAINER_REQUIRED` on `GET /v1/admin/courses/vi_en/content-versions`; the maintainer token gets 200.
7. **CMS configuration.** Set `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY` for staging **in the process environment**. The CMS otherwise reads `.secrets/real.env`, which is the TEST pair, and a CMS pointed at TEST writes `c_*` rows there. Set `CMS_LEARNING_URL` to the staging Learning domain. Leave `CMS_ALLOW_PUBLISH` unset until the dry run is read. *Proof:* login succeeds for the listed maintainer only.
8. **Publish to staging.** Always pass the target explicitly: `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY`, then `node tools/content/publish-appwrite.mjs --course vi_en --version <v> --dry-run`, read it, then run without `--dry-run`. (The script falls back to the TEST project id when `APPWRITE_PROJECT_ID` is unset; never rely on the fallback.) The Learning publish use case verifies manifest, bundles and every declared media file in the bucket before the pointer moves. *Proof:* `publish: accepted`; `lifecycle-appwrite.mjs --action verify-media --course vi_en` prints `PASS`.
9. **Mobile test configuration.** `flutter build apk --debug --dart-define-from-file=config/staging.public.json` from `apps/mobile`. Release builds keep `config/real.public.json`; `tools/tests/mobile-release-config.test.mjs` enforces it. *Proof:* sign in as the learner, open the course list, open a lesson with audio.
10. **Smoke tests.** In order: three health checks; learner `GET /v1/courses`, manifest, one bundle; maintainer publish `vN+1` with `expectedPublishedVersion`, rollback to `vN`, `verify-media`, unpublish; the Mobile staging build re-reads the course list after each; the CMS journey in the [acceptance protocol](#cms-browser-acceptance-protocol). Also fetch one audio and one image `…/storage/buckets/learning-assets/files/<fileId>/view?project=<staging id>` anonymously: both must return 200 and hash to the bundle's `sha256`, because the publish gate trusts file permissions and an anonymous read is the only proof of what Mobile will do. The self-hosted lane `pnpm local:smoke` and the API lane `pnpm mobile:api-lane` use stub or local identities; they do not replace these.

## CMS browser acceptance protocol

Run by a person or by a Playwright script against the staging CMS and staging maintainer credentials supplied at run time. Record a screenshot or trace per step.

| Step | Expected |
|---|---|
| Create course | A draft appears in the course list; no `l_*` row exists. |
| Create unit | Unit appears with its position id (`uNN`). |
| Upload media | Only keys the course derives are accepted; ADTS AAC or 512x512 WebP; the media report moves from missing to present. |
| Readiness | Every blocking row names a screen that fixes it; the Publish button agrees. |
| Publish | The dry run lists files; the real run needs `CMS_ALLOW_PUBLISH=1` and the dialog; the course appears on Mobile. |
| Version history | New version is `LIVE`, the previous `SUPERSEDED`. |
| Rollback | Pointer returns to the older version; the newer stays in history. |
| Unpublish | The course disappears from the Mobile course list; history is kept. |

## Rollback and cleanup

- **Content:** `node tools/content/lifecycle-appwrite.mjs --action rollback --course <id> --version <older> --expect <live>`; `--action unpublish --expect <live>` takes a course offline. Both refuse a stale `--expect`. Rollback re-audits the target's media.
- **Function code:** redeploy the previous commit with `pnpm appwrite:deploy -- --service <svc>` (D1) or activate the previous deployment in the console.
- **Keys:** a leaked signing seed means a new key id, a new `COC_CONTENT_PUBLIC_KEYS` entry and a rebuild; a leaked API key is revoked in the console.
- **Teardown:** delete the staging project in its own organization after checking its id is not `6acc656d0025cc57bd81`; revoke its keys; remove its vault entries and local `project.staging.json` / `staging.public.json`; delete the staging test users. Nothing here ever runs against TEST.

## Evidence required before a release verdict can be READY

Preflight `PASS`; three health 200s; the maintainer/learner authorization pair above; publish, rollback and unpublish receipts with version history; `verify-media` `PASS` on the live version; a Mobile staging session; the CMS journey table completed. Until those exist the release verdict stays NOT READY.
