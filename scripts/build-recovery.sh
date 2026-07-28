#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
out_dir=${OUT_DIR:-"$root_dir/out"}
work_dir=${WORK_DIR:-"$root_dir/build/recovery"}
rootfs_dir=${ROOTFS_DIR:-"$root_dir/build/rootfs-mounted"}
init_file=${INIT_FILE:-"$root_dir/initramfs/init-ab"}
kernel_dir=${KERNEL_DIR:-}
device_repo=https://github.com/JeyKul/android_device_samsung_gts7xlwifi-twrp.git
device_commit=0de0716a3478b16b0a5ec45c910d6787d61d352c
partition_size=86888448
stock_board=SRPTD21A007
stock_os_version=11.0.0
stock_os_patch_level=2024-08
stock_cmdline="console=tty0 androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 rdinit=/init camel.sd_uuid=3963-3639"

mkdir -p "$out_dir" "$work_dir"
out_dir=$(realpath "$out_dir")
work_dir=$(realpath "$work_dir")
rootfs_dir=$(realpath "$rootfs_dir")

if [ ! -x "$rootfs_dir/bin/busybox" ]; then
  echo "ROOTFS_DIR must point to a mounted CAMEL rootfs containing busybox" >&2
  exit 2
fi
busybox_applets=
if busybox_applets=$("$rootfs_dir/bin/busybox" --list 2>/dev/null); then
  :
elif command -v qemu-aarch64 >/dev/null 2>&1; then
  busybox_applets=$(qemu-aarch64 "$rootfs_dir/bin/busybox" --list)
elif command -v qemu-aarch64-static >/dev/null 2>&1; then
  busybox_applets=$(qemu-aarch64-static \
    "$rootfs_dir/bin/busybox" --list)
else
  echo "Cannot execute ARM64 BusyBox to audit its initramfs applets" >&2
  exit 2
fi
for applet in awk grep ip ln mdev mkdir mount mv sed sha256sum sleep \
  switch_root sync telnetd udhcpd umount losetup
do
  if ! grep -qx "$applet" <<<"$busybox_applets"; then
    echo "CAMEL BusyBox is missing required applet: $applet" >&2
    exit 2
  fi
done

if [ -n "$kernel_dir" ]; then
  kernel_dir=$(realpath "$kernel_dir")
  "$root_dir/scripts/verify-kernel-release.sh" "$kernel_dir"
  for file in Image.gz dtb dtbo.img; do
    [ -s "$kernel_dir/$file" ] || {
      echo "KERNEL_DIR is missing $file" >&2
      exit 3
    }
  done
  kernel_image=$kernel_dir/Image.gz
  kernel_dtb=$kernel_dir/dtb
  kernel_dtbo=$kernel_dir/dtbo.img
else
  if [ ! -d "$work_dir/device/.git" ]; then
    git clone --filter=blob:none "$device_repo" "$work_dir/device"
  fi
  git -C "$work_dir/device" fetch origin "$device_commit"
  git -C "$work_dir/device" checkout --detach "$device_commit"
  device=$work_dir/device/prebuilt
  kernel_image=$device/Image.gz
  kernel_dtb=$device/dtb
  kernel_dtbo=$device/dtbo.img
fi

rm -rf "$work_dir/ramdisk"
mkdir -p "$work_dir/ramdisk/bin" "$work_dir/ramdisk/dev" \
  "$work_dir/ramdisk/proc" "$work_dir/ramdisk/sys" "$work_dir/ramdisk/run" \
  "$work_dir/ramdisk/mnt/sd" "$work_dir/ramdisk/newroot"
cp "$rootfs_dir/bin/busybox" "$work_dir/ramdisk/bin/busybox"
ln -s busybox "$work_dir/ramdisk/bin/sh"
install -m 0750 "$init_file" "$work_dir/ramdisk/init"
install -m 0750 "$root_dir/initramfs/camel-early-recovery" \
  "$work_dir/ramdisk/bin/camel-early-recovery"

(
  cd "$work_dir/ramdisk"
  find . -print0 | sort -z | cpio --null -o -H newc --owner=0:0 |
    gzip -9n >"$work_dir/ramdisk.cpio.gz"
)

tools_dir="$work_dir/android-tools"
if [ ! -d "$tools_dir/mkbootimg/.git" ]; then
  mkdir -p "$tools_dir"
  git clone --depth=1 https://android.googlesource.com/platform/system/tools/mkbootimg \
    "$tools_dir/mkbootimg"
  git clone --depth=1 https://android.googlesource.com/platform/external/avb \
    "$tools_dir/avb"
fi

mkbootimg="$tools_dir/mkbootimg/mkbootimg.py"
avbtool="$tools_dir/avb/avbtool.py"
key="$tools_dir/avb/test/data/testkey_rsa4096.pem"
image="$out_dir/camel-recovery.img"

python3 "$mkbootimg" \
  --kernel "$kernel_image" \
  --ramdisk "$work_dir/ramdisk.cpio.gz" \
  --recovery_dtbo "$kernel_dtbo" \
  --dtb "$kernel_dtb" \
  --base 0x00000000 \
  --pagesize 4096 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x02000000 \
  --tags_offset 0x01e00000 \
  --dtb_offset 0x01f00000 \
  --header_version 2 \
  --os_version "$stock_os_version" \
  --os_patch_level "$stock_os_patch_level" \
  --board "$stock_board" \
  --cmdline "$stock_cmdline" \
  --output "$image"

printf SEANDROIDENFORCE >>"$image"
python3 "$avbtool" add_hash_footer \
  --image "$image" \
  --partition_size "$partition_size" \
  --partition_name recovery \
  --algorithm SHA256_RSA4096 \
  --key "$key" \
  --rollback_index 0 \
  --rollback_index_location 0

# avbtool resolves a hash descriptor by its partition name, so provide the
# canonical recovery.img name beside our descriptive artifact during verify.
verify_link="$out_dir/recovery.img"
ln -sfn "$(basename "$image")" "$verify_link"
verify_status=0
python3 "$avbtool" verify_image --image "$image" || verify_status=$?
rm -f "$verify_link"
[ "$verify_status" -eq 0 ] || exit "$verify_status"
python3 "$avbtool" info_image --image "$image" >"$image.avb.txt"
"$root_dir/scripts/verify-samsung-recovery-format.sh" \
  "$image" "${STOCK_RECOVERY_IMAGE:-}"
(
  cd "$out_dir"
  sha256sum "$(basename "$image")" >"$(basename "$image").sha256"
)

lz4 -l -12 -f "$image" "$work_dir/recovery.img.lz4"
tar -C "$work_dir" -H ustar -cf "$out_dir/AP_CAMEL_RECOVERY.tar" recovery.img.lz4
cp "$out_dir/AP_CAMEL_RECOVERY.tar" "$out_dir/AP_CAMEL_RECOVERY.tar.md5"
(
  cd "$out_dir"
  md5sum -t AP_CAMEL_RECOVERY.tar >>AP_CAMEL_RECOVERY.tar.md5
)
(
  cd "$out_dir"
  sha256sum AP_CAMEL_RECOVERY.tar.md5 \
    >AP_CAMEL_RECOVERY.tar.md5.sha256
)

echo "Built $image"
