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
printf module >"$modules/kernel/drivers/camel.ko"
printf 'kernel/drivers/camel.ko:\n' >"$modules/modules.dep"
(
  cd "$source_dir"
  find . -type f ! -name SHA256SUMS -print0 |
    sort -z | xargs -0 sha256sum >SHA256SUMS
)

"$root_dir/scripts/package-kernel-release.sh" \
  "$source_dir" "$release_dir"

(
  cd "$release_dir"
  sha256sum -c SHA256SUMS
  openssl pkeyutl -verify -rawin -pubin \
    -inkey "${CAMEL_PUBLIC_KEY:-$root_dir/keys/release-ed25519.pub.pem}" \
    -in SHA256SUMS -sigfile SHA256SUMS.sig
  tar --zstd -tf camel-kernel-modules.tar.zst >module-files.txt
  grep -qx 'lib/modules/camel-test/kernel/drivers/camel.ko' module-files.txt
)

echo "Signed kernel release packaging passed"
