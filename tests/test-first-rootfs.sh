#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/sd"
truncate -s 1048576 "$test_dir/rootfs.ext4"
hash=$(sha256sum "$test_dir/rootfs.ext4" | awk '{print $1}')

"$root_dir/scripts/stage-first-rootfs.sh" \
  "$test_dir/rootfs.ext4" "$hash" "$test_dir/sd"
"$root_dir/scripts/stage-first-rootfs.sh" \
  "$test_dir/rootfs.ext4" "$hash" "$test_dir/sd"

installed=$test_dir/sd/camel-linux/images/rootfs-A.ext4
[ "$(sha256sum "$installed" | awk '{print $1}')" = "$hash" ]
grep -qx active_slot=A "$test_dir/sd/camel-linux/state/boot-state"
grep -qx active_sha256="$hash" \
  "$test_dir/sd/camel-linux/state/boot-state"

printf changed >"$test_dir/different.ext4"
different_hash=$(sha256sum "$test_dir/different.ext4" | awk '{print $1}')
if "$root_dir/scripts/stage-first-rootfs.sh" \
  "$test_dir/different.ext4" "$different_hash" "$test_dir/sd"; then
  echo "different slot A was incorrectly accepted" >&2
  exit 20
fi

echo "Initial rootfs staging passed"
