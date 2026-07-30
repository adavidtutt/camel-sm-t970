#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: verify-kernel-release.sh KERNEL_RELEASE_DIR" >&2
  exit 2
fi

root_dir=$(cd "$(dirname "$0")/.." && pwd)
release_dir=$(realpath "$1")
public_key=${CAMEL_PUBLIC_KEY:-"$root_dir/keys/release-ed25519.pub.pem"}
module_files=$(mktemp)
trap 'rm -f "$module_files"' EXIT

for file in Image.gz dtb dtbo.img camel-kernel.config \
  camel-kernel-modules.tar.zst \
  SHA256SUMS SHA256SUMS.sig; do
  [ -s "$release_dir/$file" ] || {
    echo "kernel release is missing $file" >&2
    exit 3
  }
done

for setting in \
  CONFIG_DEVTMPFS=y \
  CONFIG_DEVTMPFS_MOUNT=y \
  CONFIG_BLK_DEV_LOOP=y \
  CONFIG_EXT4_FS=y \
  CONFIG_SDFAT_FS=y \
  CONFIG_CONFIGFS_FS=y \
  CONFIG_USB_GADGET=y \
  CONFIG_USB_CONFIGFS=y \
  CONFIG_USB_CONFIGFS_NCM=y \
  CONFIG_SECURITY_SELINUX_BOOTPARAM=y \
  CONFIG_INET=y
do
  grep -qx "$setting" "$release_dir/camel-kernel.config" || {
    echo "kernel release is missing required setting: $setting" >&2
    exit 5
  }
done

(
  cd "$release_dir"
  sha256sum -c SHA256SUMS
  openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in SHA256SUMS -sigfile SHA256SUMS.sig
  tar --zstd -tf camel-kernel-modules.tar.zst >"$module_files"
  if grep -Eq '(^/|(^|/)\.\.(/|$))' "$module_files"; then
    echo "kernel module archive contains an unsafe path" >&2
    exit 4
  fi
  grep -Eq '^lib/modules/[^/]+/modules\.dep$' "$module_files"
)

echo "VERIFIED: signed CAMEL kernel release"
