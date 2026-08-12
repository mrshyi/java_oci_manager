#!/bin/sh
set -eu

repository="mrshyi/java_oci_manager"
branch="main"
image="ghcr.io/mrshyi/java_oci_manager:latest"
deploy_dir="${DEPLOY_DIR:-java_oci_manager}"
archive_url="https://github.com/${repository}/archive/refs/heads/${branch}.tar.gz"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

for command in docker curl tar sed; do
  command -v "${command}" >/dev/null 2>&1 || fail "${command} is required"
done

docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is required"
docker info >/dev/null 2>&1 || fail "Docker is not running or the current user cannot access it"

if [ -e "${deploy_dir}" ]; then
  [ -d "${deploy_dir}" ] || fail "${deploy_dir} exists and is not a directory"
  [ -z "$(ls -A "${deploy_dir}")" ] || fail "${deploy_dir} already exists and is not empty"
else
  mkdir -p "${deploy_dir}"
fi


printf 'Downloading deployment files...\n'
curl --fail --silent --show-error --location "${archive_url}" \
  | tar --extract --gzip --directory "${deploy_dir}" --strip-components=1

cp "${deploy_dir}/.env.example" "${deploy_dir}/.env"
sed -i.bak "s|^RBOT_IMAGE=.*|RBOT_IMAGE=${image}|" "${deploy_dir}/.env"
rm -f "${deploy_dir}/.env.bak"
mkdir -p "${deploy_dir}/config" "${deploy_dir}/secrets"

printf 'Pulling %s...\n' "${image}"
docker pull "${image}"

printf 'Starting the service...\n'
(
  cd "${deploy_dir}"
  docker compose up -d --no-build
  docker compose ps
)


printf '\nDeployment completed.\n'
printf 'Open https://127.0.0.1:9527 on the Docker host.\n'
printf 'Deployment directory: %s\n' "$(cd "${deploy_dir}" && pwd)"
printf 'View logs: cd %s && docker compose logs --tail=200 -f rbot\n' "${deploy_dir}"
