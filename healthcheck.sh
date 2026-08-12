#!/bin/sh
set -eu

exec curl --fail --silent --show-error --insecure \
  --output /dev/null \
  "https://127.0.0.1:${RBOT_PORT:-9527}/radiance-bot-client/roc/api/client/health"
