# .NET staging deployment configuration

Implementation status: prepared, not validated or deployed. Follow [pending verification](../../migration/VERIFICATION_PENDING.md) and the [cutover runbook](../../migration/CUTOVER_RUNBOOK.md) before admitting traffic.

The selected hosting direction is a VPS/server with Docker Compose. Host layout, the optional systemd unit and operator-controlled update/rollback procedure are in [VPS setup](vps/README.md).

This Compose definition runs one instance of each existing .NET service from prebuilt images. API ports bind to host loopback: Learning 5101, Progress 5102, AI 5103. The hosting operator supplies HTTPS termination, certificates, access controls for internal routes and routing to these ports. Inter-service URLs must be HTTPS endpoints reachable from inside the containers; container names with plain HTTP do not satisfy the current relay configuration.

## Configure the host

1. Choose the staging host and registry with the repository owner. Record a reviewed commit/build ID and immutable image digest for each service.
2. Copy `images.env.example` to an operator-owned metadata file. Replace the image placeholders and set `COC_STAGING_SECRETS_DIR` to an absolute private directory on that host.
3. Copy the four service configuration templates (`common`, `progress`, `learning`, `ai`) into that private directory as `common.env`, `progress.env`, `learning.env`, `ai.env`. Restrict access to the deployment operator. Populate credentials there; keep the files outside the checkout and Docker build context.
4. Supply separate owner-scoped Appwrite server keys. Populate each service's HMAC keyring for its accepted inbound producers and its outbound signer. Use matching key IDs/secrets across the relevant sender/receiver pairs. Configure content public keys from the published curriculum's signer.
5. Set reviewed HTTPS service URLs and any required CORS origins. The image packaging script embeds the commit as `BUILD_ID`; keep it out of environment/secret overrides so health and logs identify the packaged revision. Keep admission/readiness values empty and workers disabled until their evidence is accepted. Hosted billing simulation remains disabled by the existing composition policy.

Staging/Production hosts require `COC_PROGRESS_APPWRITE_KEY`, `COC_LEARNING_APPWRITE_KEY` and `COC_AI_APPWRITE_KEY` as separate owner credentials. The shared `APPWRITE_API_KEY` fallback is accepted only by a host whose `ASPNETCORE_ENVIRONMENT` is `Development`; it cannot configure this Staging Compose stack. This keeps the test runner's `APPWRITE_API_KEY` separate from runtime service credentials.

The templates now pin the current Node-compatible defaults explicitly: `COC_ENERGY_MODE=UNLIMITED`, Max-only roleplay/video-call gates, a 60-second worker interval with every worker flag still false, blank maintainer IDs, and speech provider `disabled`. Speech provider keys stay blank in `ai.env`. Only after device/quality/privacy/cost acceptance, place the approved provider key files under `ai/` in the private directory and add the optional `compose.staging.ai-provider-secrets.yaml` overlay. Do not set `COC_AI_SPEECH_ADMITTED` or change the provider flag before that gate is reviewed.

## Mount secrets as files

The shared .NET host now reads `/run/secrets` through the ASP.NET Core key-per-file provider. A filename is the configuration key and its contents are the value. Files override ordinary environment/JSON/command-line configuration at startup. The directory is optional for existing deployments; live reload is disabled, so rotate files and recreate the affected container using the [key rotation runbook](../../migration/KEY_ROTATION.md). This implementation has not been built or tested yet.

To use file-mounted secrets, keep secret fields empty in the service `.env` files and create this layout under the private configuration directory:

```text
common.env
progress.env
learning.env
ai.env
progress/
  COC_PROGRESS_APPWRITE_KEY
  COC_SERVICE_KEYS
  COC_PROGRESS_CODE_SECRET
learning/
  COC_LEARNING_APPWRITE_KEY
  COC_SERVICE_KEYS
ai/
  COC_AI_APPWRITE_KEY
  COC_SERVICE_KEYS
  COC_AZURE_SPEECH_KEY                    # optional provider overlay only
  COC_ASSEMBLYAI_API_KEY                  # optional provider overlay only
  COC_DEEPGRAM_API_KEY                    # optional provider overlay only
```

Put only the raw value in each file, without `KEY=`, shell quotes or a UTF-8 BOM. HMAC files contain the JSON array accepted by `ServiceHmac.ParseKeyring`. Restrict source-file access on the host and ensure the image's non-root application user can read the mounted files. Local Compose file-backed secrets use bind mounts; do not assume a declared secret `uid`/`gid` will change host-file ownership. Validate permissions on the chosen host.

After deployment authorization, include the file-secret overlay in every staging Compose invocation; the reviewed launch sequence below does this.

Each service receives only its own mounted Appwrite key and keyring; Progress also receives its code secret. Secret values are absent from container environment variables when using this mode. Blank or invalid files do not establish Appwrite/HMAC admission. The overlay does not enable workers or readiness gates.

The speech provider overlay is separate and optional. Only after device/quality/privacy/cost acceptance, provision the three files above (unused providers may have empty files), keep the values blank in `ai.env`, and add `compose.staging.ai-provider-secrets.yaml` alongside the base and Appwrite secret overlays. The current systemd unit does not include it; after acceptance, update its start and stop Compose file lists together. Do not activate the provider/admission flags solely by adding the secret overlay.

Before a later deployment, run the read-only [staging configuration preflight](../../tools/check-staging-config.sh) on the Linux host:

```sh
bash backend-dotnet/tools/check-staging-config.sh /srv/cocenglish/deployments/<release-id>/images.env
```

It checks immutable image digests, replaced `.invalid` HTTPS service hosts, required env/secret files, distinct Appwrite keys for the three owners, secret values kept out of env files, host file modes, and the merged Compose configuration via [`docker compose config --quiet`](https://docs.docker.com/reference/cli/docker/compose/config). It never sources env files or prints resolved values; Compose validation diagnostics are suppressed on failure to avoid exposing them. It does not verify access as the container UID, inspect key scopes or HMAC pairings, contact Appwrite, or start containers; those checks remain separate.

## Optional OTLP metrics export

The API hosts can export only the `CocEnglish.Api` and `CocEnglish.Workers` meters over OTLP/HTTP. Export remains off when `COC_OTEL_METRICS_ENDPOINT` is blank. When enabled, set it in `common.env` to the full metrics endpoint, for example `https://collector.example.com/v1/metrics`; a private Docker-network collector may use HTTP if that network is restricted. Do not put credentials in the URL.

If the collector requires headers, create one private file per service at `progress/COC_OTEL_METRICS_HEADERS`, `learning/COC_OTEL_METRICS_HEADERS` and `ai/COC_OTEL_METRICS_HEADERS`. Each file contains only its comma-separated header pairs. Add `compose.staging.otel-secrets.yaml` to both the `up` and `down` Compose file lists; the systemd unit does not include the optional overlay by default. Header files are mounted under `/run/secrets` and are not added to container environment variables. Do not enable export until a trusted collector, TLS/network boundary, retention and alert ownership are selected. This overlay adds no collector, dashboard, log export, trace export or public scrape endpoint.

## Build and launch

The manual [image workflow](../../../.github/workflows/dotnet-images.yml) packages the three runtime images without executing tests. Its default `publish=false` job has read-only repository permissions and uploads build metadata with local image IDs. Selecting `publish=true` explicitly starts the publishing job, which requests `packages: write`, logs into GHCR with the workflow token and uploads `images.env` with immutable registry manifest references. No job deploys containers or changes Appwrite. The workflow has not been executed.

The repository owner must enable Actions and allow the publishing job to create/update the corresponding GHCR packages. For existing packages, grant the repository's workflow access in package settings. Merely being able to push code does not establish package publication rights. The hosting operator additionally needs permission to pull the published packages; use a credential managed on that host when packages are private.

Use the published `images.env` artifact as deployment metadata and add the private configuration directory on the staging host. The image's baked `BUILD_ID` and OCI revision label come from the same checkout commit recorded in `images.json`; `/health` and request logs read that build ID by default. Build-only metadata has `pullReference: null` and cannot supply remotely pullable images. The packaging script refuses dirty checkouts and existing output directories, and leaves `.pending` metadata on incomplete builds. A failed publication may already have published some image tags; only the completed three-image metadata set is suitable for a release candidate.

The operator uses the existing Dockerfile to build/publish images, then this definition to pull and run the reviewed digests. Run the read-only preflight first. These commands use the same Compose project name and both files as the systemd unit so manual operations do not create a second stack:

```sh
bash backend-dotnet/tools/check-staging-config.sh /absolute/private/images.env
docker compose --project-name cocenglish-dotnet-staging --env-file /absolute/private/images.env -f backend-dotnet/docker/compose.staging.yaml -f backend-dotnet/docker/compose.staging.secrets.yaml pull
docker compose --project-name cocenglish-dotnet-staging --env-file /absolute/private/images.env -f backend-dotnet/docker/compose.staging.yaml -f backend-dotnet/docker/compose.staging.secrets.yaml up -d --wait --no-build --pull never
```

This is a documented procedure only; no staging pull or start has been executed.

Do not publish expanded Compose output: environment files contain credentials. A container's health check proves `/health` liveness; it does not prove `/ready` admission, identity, Appwrite permissions or event delivery.

Workers share the service host. Keep one instance for an owner while its worker is enabled, and do not enable an external scheduler for the same jobs simultaneously. `replicas: 1` describes the intended topology; the operator must also prevent manual scaling or a second stack from creating duplicate writers. Stop the old owner's Node writers/workers before admitting its .NET replacement. Use the runbook for rollback and preserve data.

Log rotation limits each container's local JSON logs. Retention, disk capacity, remote logging, alerting and resource limits still require validation on the chosen host.

Request log fields and the built-in meters are documented in [observability notes](../../migration/OBSERVABILITY.md). The exporter is optional and disabled by default; this Compose definition does not include a collector or dashboards, and the configuration remains unverified.
