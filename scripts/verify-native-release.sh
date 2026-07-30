#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
boot=${1:-"$root_dir/out/native-v5/camel-native-v5.img"}
rootfs=${2:-"$root_dir/out/native-v5/rootfs-B.ext4"}
magiskboot=${MAGISKBOOT:-"$HOME/camel-recovery-inspect/magiskboot"}
avbtool=${AVBTOOL:-"$root_dir/build/recovery-v2-final/android-tools/avb/avbtool.py"}

for file in "$boot" "$rootfs" "$magiskboot" "$avbtool"; do
  [ -s "$file" ] || {
    echo "missing release input: $file" >&2
    exit 2
  }
done

[ "$(stat -c %s "$boot")" -eq 71303168 ]
[ "$(stat -c %s "$rootfs")" -le 3221225472 ]
[ "$(tune2fs -l "$rootfs" 2>/dev/null |
  sed -n 's/^Filesystem state:[[:space:]]*//p')" = clean ]

expect_path() {
  debugfs -R "stat $1" "$rootfs" 2>/dev/null | grep -q '^Inode:'
}

for path in \
  /sbin/init \
  /usr/lib/systemd/systemd \
  /etc/os-release \
  /etc/camel/rootfs-release \
  /etc/camel/enable-ui \
  /usr/bin/sway \
  /usr/bin/foot \
  /usr/bin/python3.13 \
  /opt/camel/systems/harness/live/camel_live.py \
  /opt/codex/bin/codex \
  /usr/local/bin/claude \
  /etc/systemd/system/graphical.target.wants/camel-ui.service; do
  expect_path "$path" || {
    echo "rootfs path missing: $path" >&2
    exit 3
  }
done

debugfs -R 'cat /usr/lib/os-release' "$rootfs" 2>/dev/null |
  grep -qx 'ID=debian'
debugfs -R 'cat /etc/camel/rootfs-release' "$rootfs" 2>/dev/null |
  grep -qx 'CAMEL_NATIVE_ROOTFS=5'
debugfs -R 'stat /opt/camel/systems/harness/live/camel_live.py' \
  "$rootfs" 2>/dev/null | grep -q 'User:[[:space:]]*1000'

audit=$(mktemp -d "$root_dir/build/verify-native-v5.XXXXXX")
cleanup() {
  rm -r "$audit"
}
trap cleanup EXIT
(
  cd "$audit"
  "$magiskboot" unpack "$boot" >unpack.txt
)

known_boot="$root_dir/out/boot-hybrid-magisk-v3/camel-hybrid-magisk-v3.img"
known=$(mktemp -d "$root_dir/build/verify-known-v5.XXXXXX")
trap 'rm -r "$audit" "$known"' EXIT
(
  cd "$known"
  "$magiskboot" unpack "$known_boot" >/dev/null
)
[ "$(sha256sum "$audit/kernel" | awk '{print $1}')" = \
  "$(sha256sum "$known/kernel" | awk '{print $1}')" ]
[ "$(sha256sum "$audit/dtb" | awk '{print $1}')" = \
  "$(sha256sum "$known/dtb" | awk '{print $1}')" ]
"$magiskboot" cpio "$audit/ramdisk.cpio" 'exists init' >/dev/null
"$magiskboot" cpio "$audit/ramdisk.cpio" \
  'exists bin/camel-early-recovery' >/dev/null

ln -sfn "$(basename "$boot")" "$(dirname "$boot")/boot.img"
python3 "$avbtool" verify_image --image "$(dirname "$boot")/boot.img"

sha256sum "$boot" "$rootfs"
echo "PASS: native CAMEL release is internally consistent"
