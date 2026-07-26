#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$root_dir/android/recovery-installer-v3"
out_dir=${OUT_DIR:-"$root_dir/out"}
output="$out_dir/camel-recovery-v3-installer.zip"

mkdir -p "$out_dir"
(
  cd "$source_dir"
  zip -9 -r "$output" module.prop sepolicy.rule service.sh
)
sha256sum "$output" >"$output.sha256"
echo "Built $output"
