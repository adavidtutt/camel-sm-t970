#!/usr/bin/env bash
set -euo pipefail

release_dir=${1:-out}
avbtool=${AVBTOOL:-avbtool}

cd "$release_dir"
sha256sum -c camel-recovery.img.sha256
if [ -e recovery.img ] || [ -L recovery.img ]; then
  echo "release directory unexpectedly contains recovery.img" >&2
  exit 3
fi
ln -s camel-recovery.img recovery.img
trap 'rm -f recovery.img' EXIT
"$avbtool" verify_image --image camel-recovery.img
sha256sum -c AP_CAMEL_RECOVERY.tar.md5.sha256

if [ -f rootfs-a.ext4 ]; then
  e2fsck -fn rootfs-a.ext4
  sha256sum -c rootfs-a.ext4.sha256
fi
