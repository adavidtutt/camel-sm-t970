#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "usage: $0 RELEASE ROOTFS_IMAGE RECOVERY_IMAGE [OUTPUT_DIR]" >&2
  exit 2
fi

release=$1
rootfs=$(realpath "$2")
recovery=$(realpath "$3")
out_dir=${4:-"$(pwd)/out/release-$release"}
private_key=${CAMEL_SIGNING_KEY:-"$HOME/.camel-signing/release-ed25519.pem"}
public_key=${CAMEL_PUBLIC_KEY:-"$(dirname "$0")/../keys/release-ed25519.pub.pem"}

case "$release" in
  *[!A-Za-z0-9._-]*|'')
    echo "Release may contain only letters, digits, dot, underscore, and dash" >&2
    exit 3
    ;;
esac

[ -f "$rootfs" ] && [ -f "$recovery" ] || {
  echo "Rootfs and recovery images must both exist" >&2
  exit 4
}
[ -s "$private_key" ] || {
  echo "Signing key not found: $private_key" >&2
  exit 5
}

mkdir -p "$out_dir"
manifest="$out_dir/camel-$release.manifest"
signature="$manifest.sig"

rootfs_hash=$(sha256sum "$rootfs" | awk '{print $1}')
recovery_hash=$(sha256sum "$recovery" | awk '{print $1}')
rootfs_size=$(stat -c %s "$rootfs")
recovery_size=$(stat -c %s "$recovery")

{
  printf 'format=1\n'
  printf 'release=%s\n' "$release"
  printf 'rootfs_file=%s\n' "$(basename "$rootfs")"
  printf 'rootfs_size=%s\n' "$rootfs_size"
  printf 'rootfs_sha256=%s\n' "$rootfs_hash"
  printf 'recovery_file=%s\n' "$(basename "$recovery")"
  printf 'recovery_size=%s\n' "$recovery_size"
  printf 'recovery_sha256=%s\n' "$recovery_hash"
} >"$manifest"

openssl pkeyutl -sign -rawin -inkey "$private_key" \
  -in "$manifest" -out "$signature"
openssl pkeyutl -verify -rawin -pubin \
  -inkey "$public_key" \
  -in "$manifest" -sigfile "$signature"

sha256sum "$manifest" "$signature" >"$out_dir/SHA256SUMS"
echo "Signed $manifest"
