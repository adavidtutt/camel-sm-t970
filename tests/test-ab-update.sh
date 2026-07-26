#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/sd/camel-linux/images" "$test_dir/keys"
openssl genpkey -algorithm ED25519 -out "$test_dir/keys/private.pem"
openssl pkey -in "$test_dir/keys/private.pem" -pubout \
  -out "$test_dir/keys/public.pem"

truncate -s 524288 "$test_dir/sd/camel-linux/images/rootfs-A.ext4"
truncate -s 1048576 "$test_dir/rootfs.ext4"
truncate -s 131072 "$test_dir/recovery.img"

CAMEL_SIGNING_KEY="$test_dir/keys/private.pem" \
CAMEL_PUBLIC_KEY="$test_dir/keys/public.pem" \
  "$root_dir/scripts/create-release-manifest.sh" test-ab \
  "$test_dir/rootfs.ext4" "$test_dir/recovery.img" "$test_dir/release"

manifest="$test_dir/release/camel-test-ab.manifest"
signature="$manifest.sig"
common_env=(
  CAMEL_PUBLIC_KEY="$test_dir/keys/public.pem"
  CAMEL_SLOT_FILE="$test_dir/no-slot-file"
  CAMEL_SD_ROOT="$test_dir/sd/camel-linux"
)

env "${common_env[@]}" \
  CAMEL_CMDLINE_FILE="$root_dir/tests/fixtures/cmdline-slot-a" \
  "$root_dir/rootfs-overlay/usr/local/sbin/camel-stage-update" \
  "$manifest" "$signature" "$test_dir/rootfs.ext4"

expected=$(sha256sum "$test_dir/rootfs.ext4" | awk '{print $1}')
staged=$(sha256sum \
  "$test_dir/sd/camel-linux/images/rootfs-B.ext4" | awk '{print $1}')
[ "$staged" = "$expected" ]
grep -qx pending_slot=B "$test_dir/sd/camel-linux/state/boot-state"
grep -qx tries_remaining=3 "$test_dir/sd/camel-linux/state/boot-state"

env "${common_env[@]}" \
  CAMEL_CMDLINE_FILE="$root_dir/tests/fixtures/cmdline-slot-b" \
  "$root_dir/rootfs-overlay/usr/local/sbin/camel-commit-boot"

grep -qx active_slot=B "$test_dir/sd/camel-linux/state/boot-state"
grep -qx active_sha256="$expected" \
  "$test_dir/sd/camel-linux/state/boot-state"
test -f "$test_dir/sd/camel-linux/state/slot-B.success"

cp "$manifest" "$test_dir/tampered.manifest"
sed -i 's/release=test-ab/release=tampered/' "$test_dir/tampered.manifest"
if env "${common_env[@]}" \
  CAMEL_CMDLINE_FILE="$root_dir/tests/fixtures/cmdline-slot-b" \
  "$root_dir/rootfs-overlay/usr/local/sbin/camel-stage-update" \
  "$test_dir/tampered.manifest" "$signature" "$test_dir/rootfs.ext4"; then
  echo "Tampered manifest was incorrectly accepted" >&2
  exit 30
fi

echo "A/B signed update lifecycle passed"
