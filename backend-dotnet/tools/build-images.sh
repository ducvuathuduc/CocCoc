#!/usr/bin/env bash
# Packaging only. Invoked manually; does not run tests or deploy services.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
publish="${COC_IMAGE_PUBLISH:-false}"
output_dir="${COC_IMAGE_OUTPUT_DIR:-$repository_root/.cache/dotnet-images}"
case "$publish" in true|false) ;; *) printf 'COC_IMAGE_PUBLISH must be true or false.\n' >&2; exit 2 ;; esac

revision="$(git -C "$repository_root" rev-parse HEAD)"
if [[ -n "${GITHUB_SHA:-}" && "$GITHUB_SHA" != "$revision" ]]; then
  printf 'Checkout revision differs from the requested workflow revision.\n' >&2
  exit 2
fi
if [[ -n "$(git -C "$repository_root" status --porcelain --untracked-files=normal)" ]]; then
  printf 'Commit the intended build inputs before packaging a revision-labelled image.\n' >&2
  exit 2
fi

namespace="${GITHUB_REPOSITORY:-}"
namespace="${namespace,,}"
if [[ "$publish" == true && ! "$namespace" =~ ^[a-z0-9_.-]+/[a-z0-9_.-]+$ ]]; then
  printf 'Publishing requires the workflow repository owner/name.\n' >&2
  exit 2
fi

mkdir -p "$(dirname "$output_dir")"
if ! mkdir -- "$output_dir"; then
  printf 'Use a fresh output directory; existing image metadata will not be overwritten.\n' >&2
  exit 2
fi
# Keep partial output separate so a failed image cannot produce a complete image set.
manifest="$output_dir/images.json.pending"
images_env="$output_dir/images.env.pending"
printf '{"commit":"%s","published":%s,"images":[' "$revision" "$publish" > "$manifest"
printf '# Commit: %s\n# Add COC_STAGING_SECRETS_DIR on the deployment host.\n' "$revision" > "$images_env"
separator=''
for service in Progress Learning AI; do
  lower="${service,,}"
  if [[ "$publish" == true ]]; then
    image_repository="ghcr.io/$namespace/dotnet-$lower"
  else
    image_repository="cocenglish-dotnet-$lower"
  fi
  tag="$image_repository:sha-$revision"
  docker build --platform linux/amd64 --target runtime --pull \
    --file "$repository_root/backend-dotnet/docker/Dockerfile" \
    --build-arg "SERVICE=$service" \
    --build-arg "BUILD_ID=$revision" \
    --label "org.opencontainers.image.revision=$revision" \
    --label "org.opencontainers.image.title=CocEnglish.$service" \
    --tag "$tag" "$repository_root"
  image_id="$(docker image inspect --format '{{.Id}}' "$tag")"
  digest_json=null
  if [[ "$publish" == true ]]; then
    docker push "$tag"
    pull_reference=''
    while IFS= read -r candidate; do
      if [[ "$candidate" == "$image_repository@sha256:"* ]]; then pull_reference="$candidate"; break; fi
    done < <(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$tag")
    if [[ -z "$pull_reference" ]]; then
      printf 'No published manifest digest was returned for %s.\n' "$service" >&2
      exit 1
    fi
    digest_json="\"$pull_reference\""
    printf 'COC_%s_IMAGE=%s\n' "${service^^}" "$pull_reference" >> "$images_env"
  fi
  printf '%s{"service":"%s","tag":"%s","localImageId":"%s","pullReference":%s}' \
    "$separator" "$lower" "$tag" "$image_id" "$digest_json" >> "$manifest"
  separator=','
done
printf ']}\n' >> "$manifest"
mv -- "$manifest" "$output_dir/images.json"
if [[ "$publish" == true ]]; then
  mv -- "$images_env" "$output_dir/images.env"
else
  # A local image ID is not a registry manifest digest and cannot be deployed remotely.
  mv -- "$images_env" "$output_dir/build-only.env"
fi
printf 'Prepared image metadata for commit %s (published=%s). No deployment or acceptance checks ran.\n' "$revision" "$publish"
