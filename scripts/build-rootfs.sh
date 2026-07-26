#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
out_dir=${OUT_DIR:-"$root_dir/out"}
work_dir=${WORK_DIR:-"$root_dir/build/rootfs"}
image=${ROOTFS_IMAGE:-"$out_dir/rootfs-a.ext4"}
size=${ROOTFS_SIZE:-8G}
release=${DEBIAN_RELEASE:-trixie}
include_ui=${CAMEL_INCLUDE_UI:-0}

mkdir -p "$out_dir" "$work_dir"
truncate -s "$size" "$image"
mkfs.ext4 -F -L CAMELROOT "$image"

mount_dir=$(mktemp -d)
cleanup() {
  mountpoint -q "$mount_dir" && sudo umount "$mount_dir"
  rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT

sudo mount -o loop "$image" "$mount_dir"
host_arch=$(dpkg --print-architecture)
if [ "$host_arch" = arm64 ]; then
  sudo debootstrap --arch=arm64 "$release" "$mount_dir" \
    https://deb.debian.org/debian
else
  command -v qemu-aarch64-static >/dev/null || {
    echo "qemu-aarch64-static is required for a non-ARM64 build host" >&2
    exit 3
  }
  sudo debootstrap --arch=arm64 --foreign "$release" "$mount_dir" \
    https://deb.debian.org/debian
  sudo cp "$(command -v qemu-aarch64-static)" "$mount_dir/usr/bin/"
  sudo chroot "$mount_dir" /debootstrap/debootstrap --second-stage
fi

sudo chroot "$mount_dir" /usr/bin/env CAMEL_INCLUDE_UI="$include_ui" \
  /bin/bash -eux <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
printf '#!/bin/sh\nexit 101\n' >/usr/sbin/policy-rc.d
chmod 0755 /usr/sbin/policy-rc.d
sed -i 's/ main$/ main non-free-firmware/' /etc/apt/sources.list
apt-get update
apt-get install -y --no-install-recommends \
  systemd-sysv systemd-resolved openssh-server iproute2 iputils-ping \
  busybox-static ca-certificates curl openssl nftables wireguard-tools \
  sudo git tmux rsync zstd jq bash-completion rclone fuse3 \
  vim-tiny less kmod procps iwd rfkill firmware-atheros
if [ "$CAMEL_INCLUDE_UI" = 1 ]; then
  apt-get install -y --no-install-recommends \
    sway foot fuzzel seatd dbus-user-session fonts-dejavu-core
fi
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -f /usr/sbin/policy-rc.d
useradd -m -s /bin/bash -u 1000 camel
if [ "$CAMEL_INCLUDE_UI" = 1 ]; then
  for group in video render input seat; do
    getent group "$group" >/dev/null && usermod -aG "$group" camel
  done
fi
passwd -l root
passwd -l camel
echo camel-tab >/etc/hostname
mkdir -p /home/camel/.ssh /var/log/journal
chmod 0700 /home/camel/.ssh
chown -R camel:camel /home/camel
CHROOT

sudo cp -a "$root_dir/rootfs-overlay/." "$mount_dir/"
sudo install -m 0600 -o 1000 -g 1000 \
  "$root_dir/keys/authorized_keys" \
  "$mount_dir/home/camel/.ssh/authorized_keys"
sudo chmod 0440 "$mount_dir/etc/sudoers.d/camel"

sudo mkdir -p \
  "$mount_dir/etc/systemd/system/multi-user.target.wants" \
  "$mount_dir/etc/systemd/system/graphical.target.wants"
sudo ln -sfn /etc/systemd/system/camel-usb-gadget.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-usb-gadget.service"
sudo ln -sfn /etc/systemd/system/camel-boot-report.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-boot-report.service"
sudo ln -sfn /etc/systemd/system/camel-diagnostics.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-diagnostics.service"
sudo ln -sfn /etc/systemd/system/camel-boot-commit.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-boot-commit.service"
sudo ln -sfn /etc/systemd/system/camel-drive.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-drive.service"
sudo ln -sfn /lib/systemd/system/systemd-networkd.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
sudo ln -sfn /lib/systemd/system/systemd-resolved.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/systemd-resolved.service"
sudo ln -sfn /lib/systemd/system/iwd.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/iwd.service"
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf "$mount_dir/etc/resolv.conf"
if [ "$include_ui" = 1 ]; then
  # Sway 1.10 initializes a DRM/seat backend even with --validate, which cannot
  # succeed in an unprivileged image-build chroot.  Check the packaged inputs
  # here; the boot report performs the real compositor check on tablet hardware.
  test -x "$mount_dir/usr/bin/sway"
  test -s "$mount_dir/etc/camel/sway/config"
  sudo ln -sfn /etc/systemd/system/camel-ui.service \
    "$mount_dir/etc/systemd/system/graphical.target.wants/camel-ui.service"
  if [ -f "$mount_dir/lib/systemd/system/seatd.service" ]; then
    sudo ln -sfn /lib/systemd/system/seatd.service \
      "$mount_dir/etc/systemd/system/multi-user.target.wants/seatd.service"
  fi
fi

sudo rm -f "$mount_dir/usr/bin/qemu-aarch64-static"
sudo sync
sudo umount "$mount_dir"

e2fsck -fy "$image"
(
  cd "$(dirname "$image")"
  sha256sum "$(basename "$image")" >"$(basename "$image").sha256"
)
echo "Built $image"
