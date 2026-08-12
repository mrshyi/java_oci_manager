#!/usr/bin/env bash
set -euo pipefail

requested_version="${1:-}"
repository="semicons/java_oci_manage"

if [[ -n "${requested_version}" ]]; then
  requested_version="${requested_version#v}"
  api_url="https://api.github.com/repos/${repository}/releases/tags/v${requested_version}"
  is_latest=false
else
  api_url="https://api.github.com/repos/${repository}/releases/latest"
  is_latest=true
fi

auth_args=()
if [[ -n "${GH_TOKEN:-}" ]]; then
  auth_args=(-H "Authorization: Bearer ${GH_TOKEN}")
fi

release_json="$(curl --fail --silent --show-error --location \
  --retry 5 \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${auth_args[@]}" \
  "${api_url}")"

source_tag="$(jq -er '.tag_name' <<< "${release_json}")"
version="${source_tag#v}"
published_at="$(jq -er '.published_at' <<< "${release_json}")"

if ! grep -Eq '^[0-9]+([.][0-9A-Za-z-]+)*$' <<< "${version}"; then
  echo "Unexpected upstream version: ${source_tag}" >&2
  exit 1
fi

asset_digest() {
  local asset_name="$1"
  local digest
  digest="$(jq -er --arg name "${asset_name}" \
    '.assets[] | select(.name == $name) | .digest' <<< "${release_json}")"
  digest="${digest#sha256:}"
  if ! grep -Eq '^[0-9a-f]{64}$' <<< "${digest}"; then
    echo "Missing or invalid SHA-256 for ${asset_name}" >&2
    exit 1
  fi
  printf '%s' "${digest}"
}

sha256_amd64="$(asset_digest 'gz_client_bot_x86_compatible.tar.gz')"
sha256_arm64="$(asset_digest 'gz_client_bot_aarch.tar.gz')"

printf 'version=%s\n' "${version}"
printf 'source_tag=%s\n' "${source_tag}"
printf 'published_at=%s\n' "${published_at}"
printf 'is_latest=%s\n' "${is_latest}"
printf 'sha256_amd64=%s\n' "${sha256_amd64}"
printf 'sha256_arm64=%s\n' "${sha256_arm64}"

