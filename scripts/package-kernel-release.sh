#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: package-kernel-release.sh KERNEL_ARTIFACT_DIR [OUTPUT_DIR]" >&2
  exit 2
fi

root_dir=$(cd "$(dirname "$0")/.." && pwd)
source_dir=$(realpath "$1")
out_dir=${2:-"$root_dir/out/kernel-release"}

for file in Image.gz dtb dtbo.img SHA256SUMS; do
  [ -s "$source_dir/$file" ] || {
    echo "kernel artifact is missing $file" >&2
    exit 3
  }
done
[ -d "$source_dir/modules/lib/modules" ] || {
  echo "kernel artifact has no versioned module tree" >&2
  exit 4
}

(
  cd "$source_dir"
  sha256sum -c SHA256SUMS
)

mkdir -p "$out_dir"
install -m 0644 "$source_dir/Image.gz" "$out_dir/Image.gz"
install -m 0644 "$source_dir/dtb" "$out_dir/dtb"
install -m 0644 "$source_dir/dtbo.img" "$out_dir/dtbo.img"
tar --zstd -C "$source_dir/modules" -cf \
  "$out_dir/camel-kernel-modules.tar.zst" lib

(
  cd "$out_dir"
  sha256sum Image.gz dtb dtbo.img camel-kernel-modules.tar.zst \
    >SHA256SUMS
)
"$root_dir/scripts/sign-manifest.sh" "$out_dir/SHA256SUMS"
chmod 0644 "$out_dir/SHA256SUMS" "$out_dir/SHA256SUMS.sig" \
  "$out_dir/camel-kernel-modules.tar.zst"

echo "Packaged signed kernel release in $out_dir"
