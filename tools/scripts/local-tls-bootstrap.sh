#!/usr/bin/env bash
# Dedicated local CA: Node and the debug Android client trust this CA explicitly.
set -euo pipefail
cd "$(dirname "$0")/../.."
dir=.secrets/local-dev/tls
umask 077
mkdir -p "$dir"
if [[ -f "$dir/ca.crt" && -f "$dir/server.crt" && -f "$dir/server.key" ]]; then
  openssl verify -CAfile "$dir/ca.crt" "$dir/server.crt" >/dev/null
  exit 0
fi
if find "$dir" -mindepth 1 -maxdepth 1 -type f | read -r _; then
  echo 'PARTIAL_LOCAL_TLS: restore local certificates; no keys rotated.' >&2
  exit 1
fi
openssl req -x509 -newkey rsa:3072 -nodes -sha256 -days 3650 \
  -keyout "$dir/ca.key" -out "$dir/ca.crt" -subj '/CN=CocEnglish Local Development CA' \
  -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' 2>/dev/null
openssl req -newkey rsa:2048 -nodes -keyout "$dir/server.key" \
  -out "$dir/server.csr" -subj '/CN=local-tls' 2>/dev/null
cat > "$dir/server.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:local-tls,DNS:localhost,IP:127.0.0.1,IP:10.0.2.2
EOF
openssl x509 -req -in "$dir/server.csr" -CA "$dir/ca.crt" -CAkey "$dir/ca.key" \
  -CAcreateserial -out "$dir/server.crt" -days 825 -sha256 -extfile "$dir/server.ext" 2>/dev/null
openssl verify -CAfile "$dir/ca.crt" "$dir/server.crt" >/dev/null
echo 'Local TLS ready; no system trust settings changed.'
