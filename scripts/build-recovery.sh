#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
out_dir=${OUT_DIR:-"$root_dir/out"}
work_dir=${WORK_DIR:-"$root_dir/build/recovery"}
rootfs_dir=${ROOTFS_DIR:-"$root_dir/build/rootfs-mounted"}
init_file=${INIT_FILE:-"$root_dir/initramfs/init-ab"}
device_repo=https://github.com/JeyKul/android_device_samsung_gts7xlwifi-twrp.git
device_commit=0de0716a3478b16b0a5ec45c910d6787d61d352c
partition_size=86888448

mkdir -p "$out_dir" "$work_dir"

if [ ! -d "$work_dir/device/.git" ]; then
  git clone --filter=blob:none "$device_repo" "$work_dir/device"
fi
git -C "$work_dir/device" fetch origin "$device_commit"
git -C "$work_dir/device" checkout --detach "$device_commit"

if [ ! -x "$rootfs_dir/bin/busybox" ]; then
  echo "ROOTFS_DIR must point to a mounted CAMEL rootfs containing busybox" >&2
  exit 2
fi

rm -rf "$work_dir/ramdisk"
mkdir -p "$work_dir/ramdisk/bin" "$work_dir/ramdisk/dev" \
  "$work_dir/ramdisk/proc" "$work_dir/ramdisk/sys" "$work_dir/ramdisk/run" \
  "$work_dir/ramdisk/mnt/sd" "$work_dir/ramdisk/newroot"
cp "$rootfs_dir/bin/busybox" "$work_dir/ramdisk/bin/busybox"
ln -s busybox "$work_dir/ramdisk/bin/sh"
install -m 0750 "$init_file" "$work_dir/ramdisk/init"

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
device="$work_dir/device/prebuilt"
image="$out_dir/camel-recovery.img"

python3 "$mkbootimg" \
  --kernel "$device/Image.gz" \
  --ramdisk "$work_dir/ramdisk.cpio.gz" \
  --recovery_dtbo "$device/dtbo.img" \
  --dtb "$device/dtb" \
  --base 0x00000000 \
  --pagesize 4096 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x02000000 \
  --tags_offset 0x01e00000 \
  --dtb_offset 0x01f00000 \
  --header_version 2 \
  --cmdline "console=tty0 androidboot.hardware=qcom androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 rdinit=/init camel.sd_uuid=3963-3639 printk.devkmsg=on" \
  --output "$image"

printf SEANDROIDENFORCE >>"$image"
python3 "$avbtool" add_hash_footer \
  --image "$image" \
  --partition_size "$partition_size" \
  --partition_name recovery \
  --algorithm SHA256_RSA4096 \
  --key "$key" \
  --rollback_index 1 \
  --rollback_index_location 1

# avbtool resolves a hash descriptor by its partition name, so provide the
# canonical recovery.img name beside our descriptive artifact during verify.
verify_link="$out_dir/recovery.img"
ln -sfn "$(basename "$image")" "$verify_link"
verify_status=0
python3 "$avbtool" verify_image --image "$image" || verify_status=$?
rm -f "$verify_link"
[ "$verify_status" -eq 0 ] || exit "$verify_status"
python3 "$avbtool" info_image --image "$image" >"$image.avb.txt"
sha256sum "$image" >"$image.sha256"

lz4 -l -12 -f "$image" "$work_dir/recovery.img.lz4"
tar -C "$work_dir" -H ustar -cf "$out_dir/AP_CAMEL_RECOVERY.tar" recovery.img.lz4
cp "$out_dir/AP_CAMEL_RECOVERY.tar" "$out_dir/AP_CAMEL_RECOVERY.tar.md5"
(
  cd "$out_dir"
  md5sum -t AP_CAMEL_RECOVERY.tar >>AP_CAMEL_RECOVERY.tar.md5
)
sha256sum "$out_dir/AP_CAMEL_RECOVERY.tar.md5" \
  >"$out_dir/AP_CAMEL_RECOVERY.tar.md5.sha256"

echo "Built $image"
