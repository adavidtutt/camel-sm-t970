#!/usr/bin/env bash
set -euo pipefail

serial=${1:-}
expected=db257d5197eafe5e4c964d29494dac5734f7706e4881cecd742a53797986cafb
remote_log=/storage/3963-3639/camel-linux/logs/recovery-v3-install.log

adb_args=()
[ -n "$serial" ] && adb_args=(-s "$serial")

state=$(adb "${adb_args[@]}" get-state 2>/dev/null || true)
[ "$state" = device ] || {
  echo "ADB device is not reachable. Pass its current IP:port as argument 1." >&2
  exit 2
}

log=$(adb "${adb_args[@]}" shell "cat '$remote_log'" | tr -d '\r')
printf '%s\n' "$log"

printf '%s\n' "$log" | grep -qx 'CAMEL_RECOVERY_V3_INSTALLED=1' || {
  echo "Recovery installer did not report success; do not boot recovery." >&2
  exit 10
}

readback=$(printf '%s\n' "$log" |
  sed -n 's/^readback_sha256=//p' | tail -1)
[ "$readback" = "$expected" ] || {
  echo "Recovery read-back hash is absent or wrong; do not boot recovery." >&2
  exit 11
}

printf '%s\n' "$log" | grep -qx 'backup complete' || {
  echo "Pre-v3 recovery backup was not confirmed; do not boot recovery." >&2
  exit 12
}

echo "VERIFIED: installed recovery matches CAMEL v3 ($expected)"
