#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
verifier="$root_dir/scripts/verify-samsung-recovery-format.sh"
stock=${STOCK_RECOVERY_IMAGE:-}
rejected=${REJECTED_RECOVERY_IMAGE:-}

[ -n "$stock" ] && [ -f "$stock" ] || {
  echo "SKIP: STOCK_RECOVERY_IMAGE is unavailable"
  exit 0
}

stock_info=$(mktemp)
trap 'rm -f "$stock_info"' EXIT
avbtool info_image --image "$stock" >"$stock_info"
grep -F "Minimum libavb version:   1.0" "$stock_info" >/dev/null
grep -F "Rollback Index:           0" "$stock_info" >/dev/null
grep -F "Rollback Index Location:  0" "$stock_info" >/dev/null

if [ -n "$rejected" ] && [ -f "$rejected" ]; then
  if "$verifier" "$rejected" "$stock"; then
    echo "Rejected recovery incorrectly passed Samsung format checks" >&2
    exit 20
  fi
fi

echo "Samsung recovery format regression checks passed"
