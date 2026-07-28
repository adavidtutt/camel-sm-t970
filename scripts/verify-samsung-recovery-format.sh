#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
image=${1:?usage: verify-samsung-recovery-format.sh IMAGE [STOCK_IMAGE]}
stock=${2:-}
partition_size=86888448
unpack_tool="$root_dir/build/verify-tools/mkbootimg/unpack_bootimg.py"

[ -f "$image" ] || {
  echo "Recovery image not found: $image" >&2
  exit 2
}
[ "$(stat -c %s "$image")" -eq "$partition_size" ] || {
  echo "Recovery image has the wrong partition size" >&2
  exit 3
}
command -v avbtool >/dev/null
[ -f "$unpack_tool" ] || {
  echo "Pinned unpack_bootimg.py is unavailable" >&2
  exit 4
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
python3 "$unpack_tool" --boot_img "$image" --out "$work/candidate" \
  --format=mkbootimg >"$work/candidate.mkbootimg"
avbtool info_image --image "$image" >"$work/candidate.avb"

require_line() {
  file=$1
  line=$2
  grep -F -- "$line" "$file" >/dev/null || {
    echo "Samsung recovery compatibility check failed: $line" >&2
    exit 5
  }
}

require_line "$work/candidate.mkbootimg" "--header_version 2"
require_line "$work/candidate.mkbootimg" "--os_version 11.0.0"
require_line "$work/candidate.mkbootimg" "--os_patch_level 2024-08"
require_line "$work/candidate.mkbootimg" "--pagesize 0x00001000"
require_line "$work/candidate.mkbootimg" "--board SRPTD21A007"
require_line "$work/candidate.mkbootimg" "--kernel_offset 0x00008000"
require_line "$work/candidate.mkbootimg" "--ramdisk_offset 0x02000000"
require_line "$work/candidate.mkbootimg" "--tags_offset 0x01e00000"
require_line "$work/candidate.mkbootimg" \
  "--dtb_offset 0x0000000001f00000"
for token in \
  androidboot.hardware=qcom \
  androidboot.memcg=1 \
  lpm_levels.sleep_disabled=1 \
  msm_rtb.filter=0x237 \
  service_locator.enable=1 \
  androidboot.usbcontroller=a600000.dwc3 \
  swiotlb=2048 \
  firmware_class.path=/vendor/firmware_mnt/image \
  loop.max_part=7 \
  rdinit=/init \
  camel.sd_uuid=3963-3639
do
  require_line "$work/candidate.mkbootimg" "$token"
done

require_line "$work/candidate.avb" "Footer version:           1.0"
require_line "$work/candidate.avb" "Minimum libavb version:   1.0"
require_line "$work/candidate.avb" "Algorithm:                SHA256_RSA4096"
require_line "$work/candidate.avb" "Rollback Index:           0"
require_line "$work/candidate.avb" "Rollback Index Location:  0"
require_line "$work/candidate.avb" "Partition Name:        recovery"

for component in kernel ramdisk recovery_dtbo dtb; do
  [ -s "$work/candidate/$component" ] || {
    echo "Candidate recovery is missing $component" >&2
    exit 6
  }
done

if [ -n "$stock" ]; then
  [ -f "$stock" ] || {
    echo "Stock recovery image not found: $stock" >&2
    exit 7
  }
  [ "$(stat -c %s "$stock")" -eq "$partition_size" ] || {
    echo "Stock recovery reference has the wrong size" >&2
    exit 8
  }
  python3 "$unpack_tool" --boot_img "$stock" --out "$work/stock" \
    --format=mkbootimg >"$work/stock.mkbootimg"
  avbtool info_image --image "$stock" >"$work/stock.avb"

  for field in \
    "--header_version 2" \
    "--os_version 11.0.0" \
    "--os_patch_level 2024-08" \
    "--pagesize 0x00001000" \
    "--board SRPTD21A007" \
    "--kernel_offset 0x00008000" \
    "--ramdisk_offset 0x02000000" \
    "--tags_offset 0x01e00000" \
    "--dtb_offset 0x0000000001f00000"
  do
    require_line "$work/stock.mkbootimg" "$field"
    require_line "$work/candidate.mkbootimg" "$field"
  done
  require_line "$work/stock.avb" "Minimum libavb version:   1.0"
  require_line "$work/stock.avb" "Rollback Index:           0"
  require_line "$work/stock.avb" "Rollback Index Location:  0"
fi

echo "VERIFIED: Samsung-compatible SM-T970 recovery structure"
