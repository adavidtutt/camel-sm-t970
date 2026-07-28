#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

source_dir=$test_dir/kernel
release_dir=$test_dir/release
modules=$source_dir/modules/lib/modules/camel-test
mkdir -p "$modules/kernel/drivers"

printf kernel >"$source_dir/Image.gz"
printf dtb >"$source_dir/dtb"
printf dtbo >"$source_dir/dtbo.img"
cat >"$source_dir/camel-kernel.config" <<'EOF'
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_BLK_DEV_LOOP=y
CONFIG_EXT4_FS=y
CONFIG_SDFAT_FS=y
CONFIG_CONFIGFS_FS=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_NCM=y
CONFIG_INET=y
EOF
printf module >"$modules/kernel/drivers/camel.ko"
printf 'kernel/drivers/camel.ko:\n' >"$modules/modules.dep"
(
  cd "$source_dir"
  find . -type f ! -name SHA256SUMS -print0 |
    sort -z | xargs -0 sha256sum >SHA256SUMS
)

"$root_dir/scripts/package-kernel-release.sh" \
  "$source_dir" "$release_dir"
"$root_dir/scripts/verify-kernel-release.sh" "$release_dir"

cp -a "$release_dir" "$test_dir/tampered-release"
printf tampered >>"$test_dir/tampered-release/Image.gz"
if "$root_dir/scripts/verify-kernel-release.sh" \
  "$test_dir/tampered-release"; then
  echo "tampered kernel release was incorrectly accepted" >&2
  exit 20
fi

(
  cd "$release_dir"
  sha256sum -c SHA256SUMS
  openssl pkeyutl -verify -rawin -pubin \
    -inkey "${CAMEL_PUBLIC_KEY:-$root_dir/keys/release-ed25519.pub.pem}" \
    -in SHA256SUMS -sigfile SHA256SUMS.sig
  tar --zstd -tf camel-kernel-modules.tar.zst >module-files.txt
  grep -qx 'lib/modules/camel-test/kernel/drivers/camel.ko' module-files.txt
)

merged_root=$test_dir/merged-root
mkdir -p "$merged_root/usr/lib"
ln -s usr/lib "$merged_root/lib"
tar --zstd --keep-directory-symlink -C "$merged_root" -xf \
  "$release_dir/camel-kernel-modules.tar.zst"
test -L "$merged_root/lib"
test -f "$merged_root/usr/lib/modules/camel-test/modules.dep"

echo "Signed kernel release packaging passed"
