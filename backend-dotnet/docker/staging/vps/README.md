# VPS with Docker Compose

Chosen deployment direction: a VPS/server running Docker Compose. The included systemd unit is a template for a Linux VPS using systemd; it has not been installed, started or tested. It manages the existing three-service staging stack and does not install Docker, configure a firewall/TLS or change Appwrite.

## Host layout

An optional host Nginx routing template is in [nginx/README.md](nginx/README.md). It supplies three HTTPS virtual hosts and a default-deny internal-route allowlist; real domains, certificates, trusted egress addresses and existing-host integration are still required.

```text
/etc/cocenglish/dotnet-staging.env              # Current release paths; no API/HMAC keys
/srv/cocenglish/releases/<commit>/              # Reviewed checkout, including Compose files
/srv/cocenglish/deployments/<release-id>/
  images.env                                   # Published image digest metadata + private directory
  images.json                                  # Commit/image evidence from packaging workflow
/srv/cocenglish/private/dotnet-staging/         # Owner-specific config and mounted secret files
```

Keep the exact Compose files, image metadata and private configuration references used for the active release. Retain the previous release and metadata for operator-controlled rollback. Do not edit the unit's release paths while it is active: its stop command must refer to the same release that was started.

## Prerequisites to prepare

- A Linux VPS with Docker Engine, the Compose plugin, systemd and `/usr/bin/docker`. Adjust the unit if the executable or host layout differs.
- Permission to install/manage a systemd unit, access the Docker daemon and provision the private configuration directory. The sample unit runs with systemd's default root account; use a reviewed deployment account if the hosting setup requires one.
- GHCR pull access when the selected images are private. Authenticate on the VPS through its managed registry credentials; never copy the GitHub Actions token from a workflow.
- Disk/memory capacity, firewall rules, backups and log collection chosen for the host. The current Compose limits are initial settings, not measured capacity.
- HTTPS termination and trusted certificates for the three service URLs. Route them to loopback Learning 5101, Progress 5102 and AI 5103; keep those API ports off the public interface. Ensure service-to-service requests can reach the HTTPS URLs, and configure internal-route network access controls alongside HMAC.
- The private configuration layout and owner-only secret mounts described in [staging setup](../README.md). Preserve the Node-compatible HMAC keys/code secret during migration unless a coordinated rotation is explicitly planned.

## Operator-controlled installation sequence

These are deployment steps for later authorization, not steps executed during implementation:

1. Place the reviewed checkout under its commit-specific release directory. Place the matching published `images.env`/`images.json` in a new deployment directory and set `COC_STAGING_SECRETS_DIR` in `images.env` to the private host path.
2. Provision non-secret env files and secret files. Confirm the container application user can read the mounts. Keep workers and admission/readiness flags disabled until their gates are accepted.
3. Pull the exact digests using the two Compose files and that `images.env` before starting the unit. The unit first runs the release's read-only staging preflight, then deliberately uses `--pull never` and `--no-build` so a restart reuses the prepared artifacts.
4. Populate `/etc/cocenglish/dotnet-staging.env` from the provided template. Install `cocenglish-dotnet.service` under `/etc/systemd/system/`, then reload systemd definitions. Do not enable boot startup while the migration still has overlapping Node writers/workers or missing acceptance gates.
5. Follow the [cutover runbook](../../../migration/CUTOVER_RUNBOOK.md) before starting/admitting any .NET owner. The unit can start the stack with admission/worker flags disabled for configuration work, but container health is only liveness.
6. Start the unit only when authorized. Enable boot startup only after the operator has accepted topology, restart behavior and cutover evidence.

## Update and rollback behavior

Stop the active unit while its path file still references the active release. Wait for the old owner's writers/workers to stop according to the runbook. Then update the path file to the prepared release and start the unit. Keep prior images and metadata; avoid unreviewed image pruning or data deletion.

The stop command stops containers without removing volumes or learner data. It does not drain a public proxy or coordinate upstream schedulers; those remain operator steps. For rollback to Node, stop the .NET writers/workers before restoring Node traffic and schedulers. For rollback between .NET releases, likewise stop the active release before changing its metadata paths.

The unit is `oneshot` with `RemainAfterExit`: systemd's active state means Compose startup finished, not that all APIs remain healthy or ready. Container restart policy handles process restarts; hosting must separately monitor health/readiness, log errors, outbox backlog and disk capacity. Test these behaviors before enabling unattended operation.

## Flutter client profile

The mobile app already accepts public HTTPS URLs through `LEARNING_API_URL`, `PROGRESS_API_URL` and `AI_API_URL`. A separate [VPS profile example](../../../../apps/mobile/config/dotnet-vps.public.example.json) points those values to reserved `.invalid` hostnames while preserving the coccoc-test Appwrite Auth project. Copy it to an operator/developer profile, replace service and recovery/verification callback hosts only after DNS/TLS and routing are ready, and build with `--dart-define-from-file`. Keep `apps/mobile/config/real.public.json` on the current Appwrite Function endpoints until the accepted cutover; never place server API/HMAC keys in mobile build defines.
