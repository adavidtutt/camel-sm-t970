#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: stage-first-rootfs.sh ROOTFS_IMAGE SHA256 SD_MOUNT" >&2
  exit 2
fi

image=$1
expected=$2
sd_mount=${3%/}
camel_dir=$sd_mount/camel-linux
images=$camel_dir/images
state_dir=$camel_dir/state
target=$images/rootfs-A.ext4
partial=$target.partial

case "$expected" in
  *[!0-9a-f]*|'') echo "invalid SHA-256" >&2; exit 3 ;;
esac
[ "${#expected}" -eq 64 ] || {
  echo "invalid SHA-256 length" >&2
  exit 3
}
[ -f "$image" ] || {
  echo "rootfs image not found: $image" >&2
  exit 4
}
[ -d "$sd_mount" ] || {
  echo "SD mount not found: $sd_mount" >&2
  exit 5
}

actual=$(sha256sum "$image" | awk '{print $1}')
[ "$actual" = "$expected" ] || {
  echo "source rootfs SHA-256 mismatch" >&2
  exit 6
}

mkdir -p "$images" "$state_dir" "$camel_dir/logs"
if [ -f "$target" ]; then
  installed=$(sha256sum "$target" | awk '{print $1}')
  if [ "$installed" = "$expected" ]; then
    echo "Slot A already contains the verified rootfs"
  else
    echo "refusing to overwrite a different slot A image: $target" >&2
    exit 7
  fi
else
  trap 'rm -f "$partial"' EXIT
  echo "Writing initial rootfs to slot A"
  dd if="$image" of="$partial" bs=4M conv=fsync status=progress
  readback=$(sha256sum "$partial" | awk '{print $1}')
  [ "$readback" = "$expected" ] || {
    echo "SD read-back SHA-256 mismatch" >&2
    exit 8
  }
  mv -f "$partial" "$target"
  sync
  trap - EXIT
fi

state_tmp=$state_dir/boot-state.new
{
  printf 'format=1\n'
  printf 'active_slot=A\n'
  printf 'active_release=bootstrap\n'
  printf 'active_sha256=%s\n' "$expected"
  printf 'tries_remaining=0\n'
} >"$state_tmp"
sync "$state_tmp"
mv -f "$state_tmp" "$state_dir/boot-state"
sync

echo "READY: verified slot A and initialized A/B boot state"
