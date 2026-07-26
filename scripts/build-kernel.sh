#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
kernel_src=${KERNEL_SRC:-"$root_dir/build/kernel/source"}
kernel_out=${KERNEL_OUT:-"$root_dir/build/kernel/out"}
artifact_dir=${KERNEL_ARTIFACT_DIR:-"$root_dir/out/kernel"}
jobs=${JOBS:-$(nproc)}
repository=https://github.com/LineageOS/android_kernel_samsung_sm8250.git
commit=be2e1ed031226cd08d4d0b3e51acdfb71ccbf521
libufdt_repository=https://android.googlesource.com/platform/system/libufdt
libufdt_commit=131ee2db53ad7d9d4756555567894b01107cb26e

if [ ! -d "$kernel_src/.git" ]; then
  mkdir -p "$(dirname "$kernel_src")"
  git clone --filter=blob:none --no-checkout "$repository" "$kernel_src"
fi
git -C "$kernel_src" fetch --depth=1 origin "$commit"
git -C "$kernel_src" checkout --detach "$commit"
[ "$(git -C "$kernel_src" rev-parse HEAD)" = "$commit" ]

KERNEL_SRC="$kernel_src" KERNEL_OUT="$kernel_out" \
  "$root_dir/scripts/configure-kernel.sh"

make_args=(
  -C "$kernel_src"
  O="$kernel_out"
  ARCH=arm64
  CC=clang
  LD=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  STRIP=llvm-strip
  CROSS_COMPILE=aarch64-linux-gnu-
  CLANG_TRIPLE=aarch64-linux-gnu-
)

make -j"$jobs" "${make_args[@]}" Image.gz dtbs modules

mkdir -p "$artifact_dir"
install -m 0644 "$kernel_out/arch/arm64/boot/Image.gz" \
  "$artifact_dir/Image.gz"
install -m 0644 "$kernel_out/.config" "$artifact_dir/camel-kernel.config"
(
  cd "$kernel_out"
  find arch/arm64/boot/dts -type f \
    \( -name '*.dtb' -o -name '*.dtbo' \) -exec \
    cp --parents '{}' "$artifact_dir" ';'
)

rm -rf "$artifact_dir/modules"
make "${make_args[@]}" \
  INSTALL_MOD_PATH="$artifact_dir/modules" \
  INSTALL_MOD_STRIP=1 \
  modules_install
find "$artifact_dir/modules/lib/modules" -type l \
  \( -name build -o -name source \) -delete
test -n "$(find "$artifact_dir/modules/lib/modules" -type f -name '*.ko' \
  -print -quit)"
test -s "$(find "$artifact_dir/modules/lib/modules" -name modules.dep \
  -print -quit)"

base_dtb_dir="$kernel_out/arch/arm64/boot/dts/vendor/qcom"
cat "$base_dtb_dir/kona.dtb" \
  "$base_dtb_dir/kona-v2.dtb" \
  "$base_dtb_dir/kona-v2.1.dtb" >"$artifact_dir/dtb"

overlays=()
for revision in 02 03 04 05 06; do
  overlay="$kernel_out/arch/arm64/boot/dts/samsung/gts7xl/kona-sec-"\
"gts7xlwifi-eur-overlay-r${revision}.dtbo"
  test -s "$overlay"
  overlays+=("$overlay")
done

libufdt_src="$root_dir/build/kernel/libufdt"
if [ ! -d "$libufdt_src/.git" ]; then
  git clone --filter=blob:none --no-checkout "$libufdt_repository" \
    "$libufdt_src"
fi
git -C "$libufdt_src" fetch --depth=1 origin "$libufdt_commit"
git -C "$libufdt_src" checkout --detach "$libufdt_commit"
[ "$(git -C "$libufdt_src" rev-parse HEAD)" = "$libufdt_commit" ]
python3 "$libufdt_src/utils/src/mkdtboimg.py" create \
  "$artifact_dir/dtbo.img" --page_size=4096 "${overlays[@]}"
python3 "$libufdt_src/utils/src/mkdtboimg.py" dump \
  "$artifact_dir/dtbo.img" >"$artifact_dir/dtbo.img.txt"

(
  cd "$artifact_dir"
  find . -type f ! -name SHA256SUMS -print0 |
    sort -z | xargs -0 sha256sum >SHA256SUMS
)
echo "Built CAMEL kernel artifacts in $artifact_dir"
