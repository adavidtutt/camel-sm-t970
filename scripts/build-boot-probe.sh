#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
kernel_dir=${KERNEL_DIR:?set KERNEL_DIR to a verified CAMEL kernel release}
rootfs_dir=${ROOTFS_DIR:?set ROOTFS_DIR to a rootfs containing bin/busybox}
stock_boot=${STOCK_BOOT_IMAGE:?set STOCK_BOOT_IMAGE to the exact stock boot.img}
tools_dir=${TOOLS_DIR:-"$root_dir/build/recovery/android-tools"}
work_dir=${WORK_DIR:-"$root_dir/build/boot-probe"}
out_dir=${OUT_DIR:-"$root_dir/out/boot-probe"}
partition_size=71303168

kernel_dir=$(realpath "$kernel_dir")
rootfs_dir=$(realpath "$rootfs_dir")
stock_boot=$(realpath "$stock_boot")
mkdir -p "$work_dir" "$out_dir"
work_dir=$(realpath "$work_dir")
out_dir=$(realpath "$out_dir")

"$root_dir/scripts/verify-kernel-release.sh" "$kernel_dir"
[ "$(stat -c %s "$stock_boot")" = "$partition_size" ]
[ -x "$rootfs_dir/bin/busybox" ]

unpack_tool="$tools_dir/mkbootimg/unpack_bootimg.py"
avbtool="$tools_dir/avb/avbtool.py"
key="$tools_dir/avb/test/data/testkey_rsa4096.pem"
for file in "$unpack_tool" "$avbtool" "$key"; do
  [ -s "$file" ] || {
    echo "missing Android boot tool: $file" >&2
    exit 3
  }
done

stock_audit="$work_dir/stock-audit"
mkdir -p "$stock_audit"
python3 "$unpack_tool" --boot_img "$stock_boot" --out "$stock_audit" \
  >"$stock_audit/header.txt"
grep -qx 'boot image header version: 2' "$stock_audit/header.txt"
grep -qx 'product name: SRPTD21A007' "$stock_audit/header.txt"
grep -qx 'page size: 4096' "$stock_audit/header.txt"
grep -qx 'recovery dtbo size: 0' "$stock_audit/header.txt"

# Samsung's normal BOOT path expects an uncompressed ARM64 Image. Recovery can
# load Image.gz, which made the first direct-boot probe hang before /init.
gzip -t "$kernel_dir/Image.gz"
gzip -dc "$kernel_dir/Image.gz" >"$work_dir/Image"
magic=$(dd if="$work_dir/Image" bs=1 skip=56 count=4 2>/dev/null |
  od -An -tx1 | tr -d ' \n')
[ "$magic" = 41524d64 ] || {
  echo "decompressed kernel is not an ARM64 Image (magic=$magic)" >&2
  exit 4
}

ramdisk="$work_dir/ramdisk"
mkdir -p "$ramdisk/bin" "$ramdisk/dev" "$ramdisk/proc" "$ramdisk/sys" \
  "$ramdisk/run" "$ramdisk/mnt/sd" "$ramdisk/newroot"
install -m 0755 "$rootfs_dir/bin/busybox" "$ramdisk/bin/busybox"
ln -sfn busybox "$ramdisk/bin/sh"
install -m 0750 "$root_dir/initramfs/init-ab" "$ramdisk/init"
install -m 0750 "$root_dir/initramfs/camel-early-recovery" \
  "$ramdisk/bin/camel-early-recovery"
(
  cd "$ramdisk"
  find . -print0 | sort -z | cpio --null -o -H newc --owner=0:0 |
    gzip -9n >"$work_dir/ramdisk.cpio.gz"
)

image="$out_dir/camel-boot-probe.img"
python3 "$tools_dir/mkbootimg/mkbootimg.py" \
  --kernel "$work_dir/Image" \
  --ramdisk "$work_dir/ramdisk.cpio.gz" \
  --dtb "$kernel_dir/dtb" \
  --base 0x00000000 \
  --pagesize 4096 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x02000000 \
  --tags_offset 0x01e00000 \
  --dtb_offset 0x01f00000 \
  --header_version 2 \
  --os_version 11.0.0 \
  --os_patch_level 2024-08 \
  --board SRPTD21A007 \
  --cmdline "console=tty0 androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 selinux=0 rdinit=/init camel.sd_uuid=3963-3639" \
  --output "$image"
printf SEANDROIDENFORCE >>"$image"
python3 "$avbtool" add_hash_footer \
  --image "$image" \
  --partition_size "$partition_size" \
  --partition_name boot \
  --algorithm SHA256_RSA4096 \
  --key "$key" \
  --rollback_index 0 \
  --rollback_index_location 0

ln -s camel-boot-probe.img "$out_dir/boot.img"
trap 'rm -f "$out_dir/boot.img"' EXIT
python3 "$avbtool" verify_image --image "$image"
python3 "$avbtool" info_image --image "$image" >"$image.avb.txt"
sha256sum "$image" >"$image.sha256"
echo "Built verified CAMEL boot probe: $image"
