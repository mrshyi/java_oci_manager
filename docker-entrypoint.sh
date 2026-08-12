#!/bin/sh
set -eu

umask 077

data_dir="${RBOT_DATA_DIR:-/var/lib/rbot}"
port="${RBOT_PORT:-9527}"
config_file="${data_dir}/client_config"
bootstrap_config="/config/client_config"
default_config="/opt/rbot/client_config.default"

case "${port}" in
  ''|*[!0-9]*)
    echo "RBOT_PORT must be an integer between 1 and 65535" >&2
    exit 64
    ;;
esac

if [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
  echo "RBOT_PORT must be an integer between 1 and 65535" >&2
  exit 64
fi

mkdir -p "${data_dir}"

if [ ! -e "${config_file}" ]; then
  if [ -r "${bootstrap_config}" ]; then
    cp "${bootstrap_config}" "${config_file}"
    echo "Imported initial configuration from ${bootstrap_config}"
  elif [ -r "${default_config}" ]; then
    cp "${default_config}" "${config_file}"
    echo "Initialized ${config_file} from the upstream template"
  else
    echo "No readable initial client_config was found" >&2
    exit 66
  fi
  chmod 0600 "${config_file}"
fi

if [ ! -r "${config_file}" ] || [ ! -w "${config_file}" ]; then
  echo "${config_file} must be readable and writable by UID 10001" >&2
  exit 73
fi

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

cd "${data_dir}"
exec /opt/rbot/r_client \
  "--server.port=${port}" \
  "--configPath=${config_file}"

