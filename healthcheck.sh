#!/bin/sh
set -eu

case "${RBOT_SSL_ENABLED:-false}" in
  true) scheme="https" ;;
  false) scheme="http" ;;
  *)
    echo "RBOT_SSL_ENABLED must be true or false" >&2
    exit 64
    ;;
esac

exec curl --fail --silent --show-error --insecure \
  --output /dev/null \
  "${scheme}://127.0.0.1:${RBOT_PORT:-9527}/"
