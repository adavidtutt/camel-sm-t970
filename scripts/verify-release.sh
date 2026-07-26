#!/usr/bin/env bash
set -euo pipefail

release_dir=${1:-out}
avbtool=${AVBTOOL:-avbtool}

cd "$release_dir"
sha256sum -c camel-recovery.img.sha256
"$avbtool" verify_image --image camel-recovery.img
sha256sum -c AP_CAMEL_RECOVERY.tar.md5.sha256

if [ -f rootfs-a.ext4 ]; then
  e2fsck -fn rootfs-a.ext4
  sha256sum -c rootfs-a.ext4.sha256
fi
