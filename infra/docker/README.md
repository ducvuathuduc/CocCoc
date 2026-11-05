# Local real-runtime preparation

Implements the container composition part of [W1](../../docs/agent/REAL_FEATURES_SETUP_PLAN_20261025.md) and [ADR-0018](../../docs/architecture/adr/0018-container-event-cache-runtime.md). Three business services remain independent; each API and worker uses its existing hosted handlers and owner persistence. No payment or provider is enabled automatically.

## Verify without Docker or credentials

From the repository root, using the pinned Node 22 toolchain:

```sh
pnpm install --frozen-lockfile
pnpm backend:verify
pnpm runtime:check
```

The smoke starts isolated native HTTP processes, checks liveness and refusal of unconfigured private requests, then stops them. It does not use durable test data or establish cloud admission.

## Containers

Requires a working Docker engine and Compose 2.24 or later (`env_file.required`). On this Windows machine Docker was unavailable during preparation; the Linux CI definition has not yet run for this candidate.

```sh
docker compose -f infra/docker/compose.local.yaml config --quiet
docker compose -f infra/docker/compose.local.yaml up --build -d
pnpm container:check
```

2026-10-25 local verification: standalone Compose CLI 2.39.1 was downloaded from the official release and its SHA-256 verified; `config --quiet` passed. Docker Engine is absent, so no containers were started. Each process is bounded to 1 CPU, 384 MiB memory, 128 PIDs and a 256 MiB Node heap.

The three APIs bind host loopback ports 4101–4103. `/health` is liveness. `/ready` requires signed service identity and durable admission. With the checked public template, private routes remain unavailable. The images run as an unprivileged user with a read-only root filesystem; the final stages copy only owner bundles. No server credential belongs in a build argument or image layer.

Each HTTP process admits at most `COC_HTTP_MAX_IN_FLIGHT` requests (default 128,
allowed range 1–1024). Excess requests receive a retryable 429 with `Retry-After`;
the limit includes health requests. Slots remain occupied until the handler
actually finishes, including after an HTTP deadline, so a timeout cannot hide
continuing work. Choose the cap and health-check policy from measured resource
limits; this is local backpressure, not distributed rate limiting or a capacity
guarantee.

Each owner has a separate optional ignored runtime env file: `.secrets/learning.env`, `.secrets/progress.env`, `.secrets/ai.env`. Override their locations with `COC_LEARNING_ENV_FILE`, `COC_PROGRESS_ENV_FILE`, `COC_AI_ENV_FILE`. Supply only that owner's least-privilege Appwrite key, public endpoint/project/database, reviewed admission marker and required signed relay configuration. See [Appwrite setup](../../docs/devops/APPWRITE_SETUP.md) and [permissions](../../docs/data/PERMISSIONS.md). Key presence alone does not pass the durable permission/transaction/recovery gates.

Workers are opt-in after configuration and admission:

```sh
docker compose -f infra/docker/compose.local.yaml --profile workers up -d
```

The current signed direct relay requires HTTPS for cross-service URLs. Container DNS over plain HTTP is not silently accepted. Complete the admitted TLS relay/environment setup before accepting end-to-end completion or settlement. RabbitMQ/Redis transport cutover follows W4 receipts and the ADR fault tests; this Compose foundation does not claim that cutover.

## Android local mapping

Use `apps/mobile/config/local.android.public.json` only with a debug Android emulator: `10.0.2.2` reaches the host loopback services. It explicitly opts into local HTTP; release profiles always require HTTPS. Debug manifests permit cleartext only for local development. A physical phone needs an explicitly reachable LAN/TLS profile and host binding; emulator mapping is not valid on a phone. The real native build reports unavailable while services lack credentials/admission. The approved mock browser preview on port 4173 is preserved.

## CI boundary

[Container workflow](../../.github/workflows/containers.yml) builds the same owner images, starts a disposable disabled composition, checks restart behavior and uploads bounded checksums/logs. It neither deploys nor uses cloud keys. Durable restart/replay, broker/cache faults, SBOM/security scanning and protected-host promotion remain W8 acceptance work. No production host or deploy credential has been selected.

Documentation checked through Context7: [Compose env files](https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/), [Node HTTP](https://nodejs.org/docs/latest-v22.x/api/http.html). The Node image index digest was verified against the public registry on 2026-10-25; no Docker build was run on this host.
