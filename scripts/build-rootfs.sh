#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
out_dir=${OUT_DIR:-"$root_dir/out"}
work_dir=${WORK_DIR:-"$root_dir/build/rootfs"}
image=${ROOTFS_IMAGE:-"$out_dir/rootfs-a.ext4"}
size=${ROOTFS_SIZE:-8G}
release=${DEBIAN_RELEASE:-trixie}

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
sudo debootstrap --arch=arm64 --foreign "$release" "$mount_dir" \
  https://deb.debian.org/debian
sudo cp /usr/bin/qemu-aarch64-static "$mount_dir/usr/bin/"
sudo chroot "$mount_dir" /debootstrap/debootstrap --second-stage

sudo chroot "$mount_dir" /bin/bash -eux <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
printf '#!/bin/sh\nexit 101\n' >/usr/sbin/policy-rc.d
chmod 0755 /usr/sbin/policy-rc.d
apt-get update
apt-get install -y --no-install-recommends \
  systemd-sysv systemd-resolved openssh-server iproute2 iputils-ping \
  busybox-static ca-certificates curl openssl nftables wireguard-tools \
  sudo git tmux rsync zstd jq bash-completion \
  vim-tiny less kmod procps
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -f /usr/sbin/policy-rc.d
useradd -m -s /bin/bash -u 1000 camel
passwd -l root
passwd -l camel
echo camel-tab >/etc/hostname
mkdir -p /home/camel/.ssh /var/log/journal
chmod 0700 /home/camel/.ssh
chown -R camel:camel /home/camel
CHROOT

sudo cp -a "$root_dir/rootfs-overlay/." "$mount_dir/"
sudo install -m 0600 -o 1000 -g 1000 \
  "$root_dir/keys/camel-bringup-ed25519.pub" \
  "$mount_dir/home/camel/.ssh/authorized_keys"
sudo chmod 0440 "$mount_dir/etc/sudoers.d/camel"

sudo ln -sfn /etc/systemd/system/camel-usb-gadget.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-usb-gadget.service"
sudo ln -sfn /etc/systemd/system/camel-boot-report.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-boot-report.service"
sudo ln -sfn /etc/systemd/system/camel-boot-commit.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/camel-boot-commit.service"
sudo ln -sfn /lib/systemd/system/systemd-networkd.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
sudo ln -sfn /lib/systemd/system/systemd-resolved.service \
  "$mount_dir/etc/systemd/system/multi-user.target.wants/systemd-resolved.service"
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf "$mount_dir/etc/resolv.conf"

sudo rm -f "$mount_dir/usr/bin/qemu-aarch64-static"
sudo sync
sudo umount "$mount_dir"

e2fsck -fy "$image"
sha256sum "$image" >"$image.sha256"
echo "Built $image"
