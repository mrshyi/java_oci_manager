#!/bin/sh
set -eu

service="${RBOT_SERVICE:-rbot}"
config="${RBOT_CONFIG:-/var/lib/rbot/client_config}"

exec docker compose exec -T "${service}" \
  sh -eu -c '
config="$1"
[ -r "${config}" ] || exit 1

username="$(sed -n "s/^username=//p" "${config}" | head -n 1)"
password="$(sed -n "s/^password=//p" "${config}" | head -n 1)"

[ -n "${username}" ] || exit 1
[ -n "${password}" ] || exit 1

printf "/bindclient %s %s\n" "${username}" "${password}"
' sh "${config}"
