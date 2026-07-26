# CAMEL Linux for Samsung Galaxy Tab S7+ Wi-Fi

CAMEL turns the Samsung SM-T970 (`gts7xlwifi`) into a Linux-first,
phone-recoverable tablet. Debian boots directly from a microSD-backed ext4
image through a dedicated recovery image. Android remains an independent
fallback and, later, an on-demand application subsystem.

This is not proot. The recovery kernel starts a BusyBox initramfs, attaches
the SD root image to a loop device, and uses `switch_root` to launch Debian
systemd as PID 1.

## Current state

- Debian 13 rootfs recovered and filesystem-verified
- direct SD/loop/ext4/switch-root boot path reconstructed
- CAMEL v3 diagnostic recovery built and AVB-verified
- persistent initramfs and systemd boot diagnostics
- USB NCM networking at `172.31.0.1/24`
- SSH key authentication for the `camel` user
- stock and CAMEL Odin recovery packages preserved
- first hardware recovery boot pending

See [docs/architecture.md](docs/architecture.md),
[docs/bringup.md](docs/bringup.md), and
[docs/recovery.md](docs/recovery.md). The complete phased execution plan is
in [docs/roadmap.md](docs/roadmap.md).

## Pinned upstreams

- Kernel: `LineageOS/android_kernel_samsung_sm8250`
  at `be2e1ed031226cd08d4d0b3e51acdfb71ccbf521`
- Recovery device tree: `JeyKul/android_device_samsung_gts7xlwifi-twrp`
  at `0de0716a3478b16b0a5ec45c910d6787d61d352c`

Exact inputs are recorded in [sources.lock](sources.lock).

## Safety model

CAMEL development never uses the Android boot partition for experimental
Linux images. Linux is isolated to the recovery partition and separately
versioned SD root images. Every write must have:

1. a hash-verified source,
2. a current recovery backup,
3. a stock Odin recovery package,
4. a readback hash,
5. a tested route back to Android.

Do not flash an unverified build.
