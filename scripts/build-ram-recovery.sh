#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
kernel_dir=${KERNEL_DIR:-"$root_dir/out/kernel-release-30344768775-029a986"}
busybox_root=${ROOTFS_DIR:-"$root_dir/build/rootfs-busybox-v3"}
out_dir=${OUT_DIR:-"$root_dir/out/recovery-ram-v5"}
work_dir=${WORK_DIR:-"$root_dir/build/recovery-ram-v5"}

export KERNEL_DIR="$kernel_dir"
export ROOTFS_DIR="$busybox_root"
export OUT_DIR="$out_dir"
export WORK_DIR="$work_dir"
export INIT_FILE="$root_dir/initramfs/init-ram"
export RECOVERY_CMDLINE="console=tty0 androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 selinux=0 rdinit=/init camel.mode=ram"

exec "$root_dir/scripts/build-recovery.sh"
