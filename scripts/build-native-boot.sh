#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
base_boot=${BASE_BOOT_IMAGE:-"$root_dir/out/boot-hybrid-magisk-v3/camel-hybrid-magisk-v3.img"}
busybox=${BUSYBOX:-"$root_dir/build/rootfs-busybox-v3/bin/busybox"}
magiskboot=${MAGISKBOOT:-"$HOME/camel-recovery-inspect/magiskboot"}
avbtool=${AVBTOOL:-"$root_dir/build/recovery-v2-final/android-tools/avb/avbtool.py"}
avbkey=${AVBKEY:-"$root_dir/build/recovery-v2-final/android-tools/avb/test/data/testkey_rsa4096.pem"}
out_dir=${OUT_DIR:-"$root_dir/out/native-v5"}
output=${OUTPUT_IMAGE:-"$out_dir/camel-native-v5.img"}
partition_size=71303168

for file in "$base_boot" "$busybox" "$magiskboot" \
  "$avbtool" "$avbkey" \
  "$root_dir/initramfs/init-ab" \
  "$root_dir/initramfs/camel-early-recovery"; do
  [ -s "$file" ] || {
    echo "missing build input: $file" >&2
    exit 2
  }
done

mkdir -p "$out_dir"
work=$(mktemp -d "$root_dir/build/native-boot-v5.XXXXXX")
audit=$(mktemp -d "$root_dir/build/native-boot-v5-audit.XXXXXX")
cleanup() {
  rm -r "$work" "$audit"
}
trap cleanup EXIT

(
  cd "$work"
  "$magiskboot" unpack "$base_boot"
)

base_kernel_hash=$(sha256sum "$work/kernel" | awk '{print $1}')
base_dtb_hash=$(sha256sum "$work/dtb" | awk '{print $1}')

ramdisk=$work/native-ramdisk
mkdir -p "$ramdisk/bin" "$ramdisk/dev" "$ramdisk/proc" "$ramdisk/sys" \
  "$ramdisk/run" "$ramdisk/mnt/sd" "$ramdisk/newroot"
install -m 0755 "$busybox" "$ramdisk/bin/busybox"
install -m 0755 "$root_dir/initramfs/init-ab" "$ramdisk/init"
install -m 0755 "$root_dir/initramfs/camel-early-recovery" \
  "$ramdisk/bin/camel-early-recovery"
(
  cd "$ramdisk"
  find . -print0 | sort -z |
    cpio --null -o -H newc --owner=0:0 >"$work/ramdisk.cpio.new"
)
mv "$work/ramdisk.cpio.new" "$work/ramdisk.cpio"

(
  cd "$work"
  "$magiskboot" repack "$base_boot" "$output"
)

# magiskboot preserves the Samsung/AVB container but intentionally leaves the
# original boot hash descriptor in place. Re-sign the modified BOOT payload
# with the same unlocked-device AVB key used by the proven hybrid image.
python3 "$avbtool" erase_footer --image "$output"
python3 "$avbtool" add_hash_footer \
  --image "$output" \
  --partition_size "$partition_size" \
  --partition_name boot \
  --algorithm SHA256_RSA4096 \
  --key "$avbkey" \
  --rollback_index 0 \
  --rollback_index_location 0

(
  cd "$audit"
  "$magiskboot" unpack "$output" >unpack.txt
)

[ "$(sha256sum "$audit/kernel" | awk '{print $1}')" = "$base_kernel_hash" ]
[ "$(sha256sum "$audit/dtb" | awk '{print $1}')" = "$base_dtb_hash" ]
"$magiskboot" cpio "$audit/ramdisk.cpio" 'exists init' >/dev/null
"$magiskboot" cpio "$audit/ramdisk.cpio" \
  'exists bin/camel-early-recovery' >/dev/null

ln -sfn "$(basename "$output")" "$out_dir/boot.img"
python3 "$avbtool" verify_image --image "$out_dir/boot.img"
sha256sum "$output" >"$output.sha256"
cp "$audit/unpack.txt" "$output.unpack.txt"
echo "Built native CAMEL boot image: $output"
