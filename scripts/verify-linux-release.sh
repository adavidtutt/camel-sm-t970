#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: verify-linux-release.sh RELEASE_DIR VERSION" >&2
  exit 2
fi

root_dir=$(cd "$(dirname "$0")/.." && pwd)
release_dir=$(realpath "$1")
version=$2
public_key=${CAMEL_PUBLIC_KEY:-"$root_dir/keys/release-ed25519.pub.pem"}
manifest=camel-$version.manifest
recovery=camel-recovery-$version.img

case "$version" in
  *[!A-Za-z0-9._-]*|'') echo "invalid release version" >&2; exit 3 ;;
esac

for file in rootfs-a.ext4.zst rootfs-a.ext4.sha256 \
  "$recovery" "$recovery.sha256" \
  "camel-recovery-$version-installer.zip" \
  "$manifest" "$manifest.sig" SHA256SUMS SHA256SUMS.sig; do
  [ -s "$release_dir/$file" ] || {
    echo "Linux release is missing $file" >&2
    exit 4
  }
done

(
  cd "$release_dir"
  openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in SHA256SUMS -sigfile SHA256SUMS.sig
  sha256sum -c SHA256SUMS
  openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in "$manifest" -sigfile "$manifest.sig"
  zstd -t rootfs-a.ext4.zst
  sha256sum -c "$recovery.sha256"
  unzip -tq "camel-recovery-$version-installer.zip"
)

field() {
  local key=$1
  local value
  value=$(sed -n "s/^$key=//p" "$release_dir/$manifest")
  [ "$(printf '%s\n' "$value" | wc -l)" -eq 1 ] && [ -n "$value" ] || {
    echo "manifest field $key is missing or duplicated" >&2
    exit 5
  }
  printf '%s' "$value"
}

[ "$(field format)" = 1 ]
[ "$(field release)" = "$version" ]
[ "$(field rootfs_file)" = rootfs-a.ext4 ]
[ "$(field recovery_file)" = "$recovery" ]
[ "$(field recovery_size)" -eq 86888448 ]
[ "$(field rootfs_sha256)" = \
  "$(awk 'NR == 1 {print $1}' "$release_dir/rootfs-a.ext4.sha256")" ]
[ "$(field recovery_sha256)" = \
  "$(awk 'NR == 1 {print $1}' "$release_dir/$recovery.sha256")" ]
[ "$(field recovery_sha256)" = \
  "$(sha256sum "$release_dir/$recovery" | awk '{print $1}')" ]

echo "VERIFIED: signed CAMEL Linux $version release"
