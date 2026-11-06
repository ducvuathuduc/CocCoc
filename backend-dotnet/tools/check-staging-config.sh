#!/usr/bin/env bash
# Read-only VPS staging preflight. Never sources env files or prints their values.
set -euo pipefail

usage() {
  printf 'Usage: bash %s /absolute/path/to/images.env\n' "$0" >&2
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

images_env=$1
[[ "$images_env" == /* ]] || fail 'images.env path must be absolute.'
[[ -f "$images_env" && -r "$images_env" ]] || fail 'images.env must be a readable regular file.'

declare -A image_values=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}
  [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || fail 'images.env contains an unsupported line.'
  key=${BASH_REMATCH[1]}
  value=${BASH_REMATCH[2]}
  case "$key" in
    COC_PROGRESS_IMAGE|COC_LEARNING_IMAGE|COC_AI_IMAGE|COC_STAGING_SECRETS_DIR) ;;
    *) fail "images.env contains unsupported variable $key; keep secrets and other runtime settings out of this file." ;;
  esac
  [[ ! -v "image_values[$key]" ]] || fail "images.env contains duplicate variable $key."
  image_values[$key]=$value
done < "$images_env"

for service in PROGRESS LEARNING AI; do
  key="COC_${service}_IMAGE"
  image=${image_values[$key]:-}
  [[ "$image" =~ ^[a-z0-9][a-z0-9.-]*(:[0-9]+)?/[a-z0-9_./-]+@sha256:[0-9a-f]{64}$ ]] ||
    fail "$key must contain a lowercase registry reference pinned to a sha256 digest."
done

secrets_dir=${image_values[COC_STAGING_SECRETS_DIR]:-}
[[ "$secrets_dir" == /* ]] || fail 'COC_STAGING_SECRETS_DIR must be an absolute path in images.env.'
[[ -d "$secrets_dir" && -r "$secrets_dir" ]] || fail 'COC_STAGING_SECRETS_DIR must be a readable directory.'

check_private_mode() {
  local path=$1 mode mode_number
  mode=$(stat -c '%a' -- "$path") || fail "Cannot read permissions for $path."
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || fail "Unexpected Linux permission mode for $path."
  mode_number=$((8#$mode))
  (( (mode_number & 007) == 0 && (mode_number & 020) == 0 )) ||
    fail "$path must not allow world access or group write."
}

check_private_mode "$secrets_dir"

common_env="$secrets_dir/common.env"
for service in progress learning ai; do
  service_dir="$secrets_dir/$service"
  service_env="$secrets_dir/$service.env"
  [[ -d "$service_dir" && -r "$service_dir" ]] || fail "Missing or unreadable $service secret directory."
  check_private_mode "$service_dir"
  [[ -f "$service_env" && -r "$service_env" ]] || fail "Missing or unreadable $service.env."
done
[[ -f "$common_env" && -r "$common_env" ]] || fail 'Missing or unreadable common.env.'

read_env_value() {
  local file=$1 wanted=$2
  awk -v wanted="$wanted" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      separator = index($0, "=")
      if (separator == 0) next
      name = substr($0, 1, separator - 1)
      sub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name != wanted) next
      count++
      value = substr($0, separator + 1)
    }
    END {
      if (count != 1) exit 1
      print value
    }
  ' "$file"
}

appwrite_endpoint=$(read_env_value "$common_env" APPWRITE_ENDPOINT) || fail 'common.env must define APPWRITE_ENDPOINT exactly once.'
project_id=$(read_env_value "$common_env" APPWRITE_PROJECT_ID) || fail 'common.env must define APPWRITE_PROJECT_ID exactly once.'
database_id=$(read_env_value "$common_env" COC_DATABASE_ID) || fail 'common.env must define COC_DATABASE_ID exactly once.'
[[ "$appwrite_endpoint" =~ ^https://[^/@?#]+/v1/?$ ]] || fail 'APPWRITE_ENDPOINT must be HTTPS and end in /v1.'
[[ -n "$project_id" && -n "$database_id" ]] || fail 'APPWRITE_PROJECT_ID and COC_DATABASE_ID must be non-empty.'

for service in progress learning ai; do
  service_url=$(read_env_value "$common_env" "COC_${service^^}_URL") || fail "common.env must define COC_${service^^}_URL exactly once."
  [[ "$service_url" =~ ^https://[^/@?#]+/?$ && "$service_url" != *'.invalid'* ]] ||
    fail "COC_${service^^}_URL must be an HTTPS origin with its reserved placeholder host replaced."
done

for file in "$common_env" "$secrets_dir/progress.env" "$secrets_dir/learning.env" "$secrets_dir/ai.env"; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]] || continue
    key=${BASH_REMATCH[1]}
    key_upper=${key^^}
    value=${BASH_REMATCH[2]}
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    case "$value" in ''|'""'|"''"|\#*) value='' ;; esac
    [[ -z "$value" ]] && continue
    [[ "$key_upper" == COC_CONTENT_PUBLIC_KEYS || "$key_upper" == *_SIGNING_KEY_ID ]] && continue
    [[ ! "$key_upper" =~ (^|_)(KEY|KEYS|SECRET|TOKEN|PASSWORD|HEADERS)$ ]] ||
      fail "$file contains a non-empty credential-like variable $key; put credentials in file-backed secrets."
  done < "$file"
done

required_secrets=(
  progress/COC_PROGRESS_APPWRITE_KEY
  progress/COC_SERVICE_KEYS
  progress/COC_PROGRESS_CODE_SECRET
  learning/COC_LEARNING_APPWRITE_KEY
  learning/COC_SERVICE_KEYS
  ai/COC_AI_APPWRITE_KEY
  ai/COC_SERVICE_KEYS
)
for relative_path in "${required_secrets[@]}"; do
  secret_file="$secrets_dir/$relative_path"
  [[ -f "$secret_file" && -r "$secret_file" && -s "$secret_file" ]] || fail "Missing, unreadable or empty secret file: $relative_path."
  grep -q '[^[:space:]]' "$secret_file" || fail "Secret file contains only whitespace: $relative_path."
  check_private_mode "$secret_file"
done

progress_key="$secrets_dir/progress/COC_PROGRESS_APPWRITE_KEY"
learning_key="$secrets_dir/learning/COC_LEARNING_APPWRITE_KEY"
ai_key="$secrets_dir/ai/COC_AI_APPWRITE_KEY"
check_distinct_keys() {
  local left=$1 right=$2 compare_status
  if cmp -s <(tr -d '\r\n' < "$left") <(tr -d '\r\n' < "$right"); then
    fail 'Progress, Learning and AI must use three distinct Appwrite owner keys.'
  else
    compare_status=$?
    (( compare_status == 1 )) || fail 'Could not compare the owner-specific Appwrite key files.'
  fi
}
check_distinct_keys "$progress_key" "$learning_key"
check_distinct_keys "$progress_key" "$ai_key"
check_distinct_keys "$learning_key" "$ai_key"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
release_dir=$(cd -- "$script_dir/../.." && pwd)
if ! docker compose --project-name cocenglish-dotnet-staging \
  --env-file "$images_env" \
  -f "$release_dir/backend-dotnet/docker/compose.staging.yaml" \
  -f "$release_dir/backend-dotnet/docker/compose.staging.secrets.yaml" \
  config --quiet >/dev/null 2>&1; then
  fail 'Docker Compose could not validate the staging configuration; details were suppressed to protect env values.'
fi

printf 'Staging preflight passed. No environment or secret values were printed.\n'
printf 'This checks immutable image references, HTTPS host placeholders, required files, distinct owner keys, host file modes and Compose parsing.\n'
printf 'It does not verify container UID access, key scopes, HMAC pairings, Appwrite reachability, readiness or deployment.\n'
