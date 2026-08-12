#!/bin/sh
set -eu

requested_platform="${RBOT_PLATFORM:-auto}"
machine="${RBOT_MACHINE:-$(uname -m)}"
cpuinfo="${RBOT_CPUINFO:-/proc/cpuinfo}"

arm64_has_lse() {
  [ -r "${cpuinfo}" ] || return 1
  awk '
    /^Features[[:space:]]*:/ {
      for (i = 2; i <= NF; i++) {
        if ($i == "atomics") found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  ' "${cpuinfo}"
}

case "${requested_platform}" in
  auto)
    case "${machine}" in
      x86_64|amd64)
        platform="linux/amd64"
        reason="native x86_64 host"
        ;;
      aarch64|arm64)
        if arm64_has_lse; then
          platform="linux/arm64"
          reason="ARM64 host with LSE atomics"
        else
          platform="linux/amd64"
          reason="ARM64 host without LSE; AMD64 compatibility mode is required"
        fi
        ;;
      *)
        printf 'Unsupported host architecture: %s\n' "${machine}" >&2
        exit 65
        ;;
    esac
    ;;
  linux/amd64|linux/arm64)
    platform="${requested_platform}"
    reason="explicit RBOT_PLATFORM override"
    ;;
  *)
    printf 'RBOT_PLATFORM must be auto, linux/amd64, or linux/arm64\n' >&2
    exit 64
    ;;
esac

printf 'platform=%s\n' "${platform}"
printf 'machine=%s\n' "${machine}"
printf 'reason=%s\n' "${reason}"
