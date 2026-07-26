# Architecture

## Boot chain

```text
Samsung bootloader
  -> recovery partition
  -> Linux 4.19 kernel
  -> CAMEL BusyBox initramfs (`rdinit=/init`)
  -> writable microSD mount (`sdfat`, then exfat/vfat fallback)
  -> loop attach `/camel-linux/images/rootfs-v2.ext4`
  -> ext4 root mount
  -> move /dev, /proc, /sys, /run, and /mnt/sd
  -> switch_root
  -> Debian 13 systemd PID 1
```

Android uses the separate `boot` partition and remains independently
bootable.

## Networking

The kernel has USB ConfigFS NCM built in. Debian creates `ncm.usb0`; the
interface appears as `usb0`, receives `172.31.0.1/24`, and serves DHCP.
The recovery phone connects over USB and uses SSH to reach `camel@172.31.0.1`.

## Diagnostics

The initramfs emits stable `CAMEL_STAGE` and `CAMEL_FAIL` codes. After the
SD is mounted, output persists to:

```text
/camel-linux/logs/boot-v3.log
```

After systemd reaches multi-user/network targets, a second report records
the kernel, command line, mounts, routes, addresses, memory, and failed
units:

```text
/camel-linux/logs/systemd-v3.log
/camel-linux/logs/boot-v3.success
```

## Storage strategy

Large root images and release artifacts live on microSD. Active source
trees and Git metadata must use an ext4-capable filesystem, never exFAT.
Future releases use immutable A/B root images plus a small writable overlay.
