#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

truncate -s 86888448 "$test_dir/recovery.img"
expected=$(sha256sum "$test_dir/recovery.img" | awk '{print $1}')
output=$test_dir/installer.zip

(
  cd "$test_dir"
  "$root_dir/scripts/package-embedded-recovery-installer.sh" \
    test-v5 recovery.img installer.zip
)

(
  cd "$test_dir"
  sha256sum -c installer.zip.sha256
)
unzip -p "$output" module.prop |
  grep -qx 'id=camel_recovery_test_v5_installer'
unzip -p "$output" service.sh |
  grep -qx "EXPECTED=$expected"
unzip -p "$output" service.sh |
  grep -qx 'IMAGE_SIZE=86888448'
[ "$(unzip -p "$output" camel-recovery.img | wc -c)" -eq 86888448 ]

echo "Embedded recovery installer packaging passed"
