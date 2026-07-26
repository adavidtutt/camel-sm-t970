#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: fetch-linux-release.sh VERSION [OUTPUT_DIR]" >&2
  exit 2
fi

root_dir=$(cd "$(dirname "$0")/.." && pwd)
version=$1
out_dir=${2:-"$root_dir/build/linux-release-$version"}
tag=camel-linux-sm-t970-$version
base=https://github.com/adavidtutt/camel-sm-t970/releases/download/$tag

case "$version" in
  *[!A-Za-z0-9._-]*|'') echo "invalid release version" >&2; exit 3 ;;
esac

mkdir -p "$out_dir"
download() {
  local file=$1
  local partial=$out_dir/$file.partial
  curl --fail --location --retry 4 --retry-all-errors \
    --silent --show-error --output "$partial" "$base/$file"
  mv -f "$partial" "$out_dir/$file"
}

download SHA256SUMS
download SHA256SUMS.sig
openssl pkeyutl -verify -rawin -pubin \
  -inkey "$root_dir/keys/release-ed25519.pub.pem" \
  -in "$out_dir/SHA256SUMS" -sigfile "$out_dir/SHA256SUMS.sig"

for file in rootfs-a.ext4.zst rootfs-a.ext4.sha256 \
  "camel-recovery-$version.img" \
  "camel-recovery-$version.img.sha256" \
  "camel-recovery-$version-installer.zip" \
  "camel-$version.manifest" "camel-$version.manifest.sig"; do
  download "$file"
done

"$root_dir/scripts/verify-linux-release.sh" "$out_dir" "$version"
