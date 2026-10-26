#!/usr/bin/env bash
# Runs only inside the dedicated CocEnglishDev Ubuntu 24.04 distribution.
set -euo pipefail
. /etc/os-release
if [[ "$ID" != ubuntu || "$VERSION_ID" != 24.04 || "$(id -u)" != 0 ]]; then
  echo 'Expected root in the isolated Ubuntu 24.04 CocEnglishDev distribution.' >&2
  exit 1
fi
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update -qq
engine_version='5:28.5.2-1~ubuntu.24.04~noble'
compose_version='2.39.1-1~ubuntu.24.04~noble'
containerd_version='2.4.2-3~ubuntu.24.04~noble'
buildx_version='0.38.1-1~ubuntu.24.04~noble'
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  "docker-ce=$engine_version" "docker-ce-cli=$engine_version" \
  "containerd.io=$containerd_version" "docker-buildx-plugin=$buildx_version" "docker-compose-plugin=$compose_version"
cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true
EOF
systemctl enable docker
echo 'Docker installed. Restart only CocEnglishDev, then verify docker info.'
