#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: fetch-kernel-release.sh RELEASE_TAG [OUTPUT_DIR]" >&2
  exit 2
fi

root_dir=$(cd "$(dirname "$0")/.." && pwd)
tag=$1
out_dir=${2:-"$root_dir/build/kernel-release"}
base=https://github.com/adavidtutt/camel-sm-t970/releases/download/$tag

case "$tag" in
  *[!A-Za-z0-9._-]*|'') echo "invalid kernel release tag" >&2; exit 3 ;;
esac

mkdir -p "$out_dir"
for file in Image.gz dtb dtbo.img camel-kernel-modules.tar.zst \
  SHA256SUMS SHA256SUMS.sig; do
  partial=$out_dir/$file.partial
  curl --fail --location --retry 4 --retry-all-errors \
    --output "$partial" "$base/$file"
  mv -f "$partial" "$out_dir/$file"
done

"$root_dir/scripts/verify-kernel-release.sh" "$out_dir"
