# Durable local development — 2026-10-26

This profile runs actual Appwrite Auth/TablesDB/Storage and the three container API/worker entrypoints. It is separate from the ephemeral `pnpm dev:services` fixture. Hosting and real-money payments remain outside this local setup. Architecture and feature scope remain owned by the [approved plan](../agent/REAL_FEATURES_SETUP_PLAN_20261025.md) and [runtime ADR](../architecture/adr/0018-container-event-cache-runtime.md).

## This Windows machine

- Dedicated Ubuntu 24.04 WSL2 distribution: `CocEnglishDev`, imported under `%LOCALAPPDATA%/CocEnglish/wsl` from the Canonical Ubuntu Base archive after SHA-256 verification.
- Docker Engine **28.5.2**, Compose **2.39.1**; systemd starts Docker. No Windows reboot or Docker Desktop is required.
- A hidden `wsl.exe … sleep infinity` keeper prevents WSL from stopping the distribution when command clients exit. Its PID is private local state; reuse checks process identity. `local:stop` stops project containers and intentionally leaves the keeper available. Do not use `wsl --shutdown` to manage this project.
- Docker images, named volumes and databases stay inside this distribution. Source remains in the Windows checkout. First-time image downloads/builds take several minutes.

Use Node 22; this checkout already has the verified portable runtime:

```powershell
$env:PATH = "$PWD\.cache\toolchains\node-v22.23.3-win-x64;$env:PATH"
pnpm install --frozen-lockfile
pnpm local:setup
pnpm local:status
```

`local:setup` creates private configuration and a development CA, starts containers, creates/reuses the isolated `cocenglish-local` project and scoped server keys, applies additive schema, runs permission/transaction probes, verifies/publishes authored curriculum, admits durable adapters and runs the authenticated learning smoke. It never reads the caller's cloud Appwrite settings. Failed probes block admission. Re-running recovers existing resources and preserves passwords/data.

For another Windows machine, WSL2 and an Ubuntu 24.04 distribution named `CocEnglishDev` must exist first. The checked `tools/scripts/local-wsl-bootstrap.sh` installs the pinned engine inside that dedicated distribution as root. Restart **only that distribution** after enabling systemd. The setup script does not enable Windows features, accept SDK terms, register cloud resources or reboot the computer.

## Daily use

```powershell
pnpm local:up
pnpm local:doctor
pnpm local:smoke
pnpm local:logs learning
pnpm local:stop
pnpm local:up
pnpm local:smoke --verify-restart
```

`local:stop` preserves every named volume. There is deliberately no reset/down-volume command. The smoke creates two synthetic local users, uses real cookie-derived JWTs, exercises grading/idempotency/private access and waits for actual Progress credit. Its read-only restart phase reauthenticates and checks the same stored reward.

| Surface | Windows host | Android emulator |
|---|---|---|
| Appwrite API | `https://127.0.0.1:8443/v1` | `https://10.0.2.2:8443/v1` |
| Learning | `https://127.0.0.1:4101` | `https://10.0.2.2:4101` |
| Progress | `https://127.0.0.1:4102` | `https://10.0.2.2:4102` |
| AI | `https://127.0.0.1:4103` | `https://10.0.2.2:4103` |
| Local email capture | `http://127.0.0.1:8025` | `http://10.0.2.2:8025` |

All published ports bind to loopback. Redis, RabbitMQ and PostgreSQL expose no host ports. `/health` is public liveness; `/ready` requires maintainer HMAC and checks durable persistence. An unauthenticated `401` at `/ready` is expected.

## Android API build

```powershell
pnpm local:apk
# With an emulator already running:
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk
```

The debug build uses `DATA_SOURCE=api`, real Appwrite auth and a generated public CA certificate. It does not embed server keys. Release/profile reject this CA define; TLS validation stays enabled. A dedicated Gradle cache caps the local heap at 1.5 GB and workers at two. A physical phone requires separately reviewed reachable addresses/certificates; these loopback bindings do not expose the machine on the LAN.

Configuration, console credentials, scoped API keys, CA private keys and synthetic smoke credentials are in Git-ignored `.secrets/local-dev/`. Treat that directory as private; do not paste it into chat or commit it. Diagnostic logs are in Git-ignored `.cache/local-dev/` and dated validation cache. No system-wide certificate trust is changed.

## Verified and still pending

On 2026-10-26 the local schema had **62 tables, 664 columns, no pending/extra drift**. Publish verified **514 JSON files and 1,760 media files**. The two-account HTTP acceptance completed a real lesson and credited **25 XP once**; stopping and restarting the complete stack retained the completed session and identical reward identity/revision.

RabbitMQ and the separate derived-cache Redis run with persistent broker storage and private-network credentials. Business events still use the existing signed direct relay; cache selection remains disabled. The new Redis adapter has fault tests, but AMQP application receipts/cutover and live cache admission remain required by ADR-0018. Container startup does not prove those feature gates.

Local SMTP capture is not public email deliverability. OAuth credentials, production callback domains, external Gemini/speech quality/quota, physical-device offline/process-kill recovery and release signing remain separate acceptance work. A successful HTTP smoke or APK build must not be reported as those results.

## Pause checkpoint

The user requested a pause and push to `main` on 2026-10-26. Local containers, the dedicated WSL distribution, emulator and active Android build were stopped; database volumes and private credentials remain intact.

- Backend: **222 passed, 12 environment-gated skipped, zero failed**. Local tooling: **30 passed**. Schema tests: **24 passed**. Contracts, OpenAPI lint, blueprint, audit and shifted-port dev HTTP smoke passed.
- Real local email verification, password recovery and email OTP all passed through Appwrite and Mailpit; callback UI navigation remains untested.
- Flutter analyzer was clean. Full Windows Flutter run: **1,258 passed, 273 failed**, including screenshot comparison failures. No golden baseline was regenerated or tolerance weakened. This is not an all-green mobile receipt; the previously green GitHub baseline is a different run.
- The API APK build was interrupted for the requested pause. The new two-process Android offline acceptance test and private defines generator were added and analyzed, but network disable → force-stop → reopen → replay was **not executed**.
- Resume with the API APK/native offline acceptance and screenshot triage, then remaining cache/broker admission and feature work from the approved plan. No cloud deployment was performed.
