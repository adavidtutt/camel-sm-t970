# CAMEL Linux for Samsung Galaxy Tab S7+ Wi-Fi

CAMEL turns the Samsung SM-T970 (`gts7xlwifi`) into a Linux-first,
phone-recoverable tablet. Debian boots directly from a microSD-backed ext4
image through a dedicated recovery image. Android remains an independent
fallback and, later, an on-demand application subsystem.

This is not proot. The recovery kernel starts a BusyBox initramfs, attaches
the SD root image to a loop device, and uses `switch_root` to launch Debian
systemd as PID 1.

## Current state

- Debian 13 ARM64 rootfs built natively and filesystem-verified in public CI
- direct SD/loop/ext4/switch-root boot path with signed A/B rollback
- CAMEL v5 native-kernel recovery built, AVB-verified, and packaged for Odin
- persistent initramfs and systemd boot diagnostics
- USB NCM networking at `172.31.0.1/24`
- SSH key authentication for the `camel` user
- stock and CAMEL Odin recovery packages preserved
- signed native SM-T970 kernel, rootfs, recovery, and A/B manifests published
- original Android command launcher, keyboard, and atomic clock preserved
- first hardware recovery boot pending

See [docs/architecture.md](docs/architecture.md),
[docs/bringup.md](docs/bringup.md), and
[docs/recovery.md](docs/recovery.md). Signed A/B release design is documented
in [docs/updates.md](docs/updates.md), published artifacts in
[docs/releases.md](docs/releases.md), and the native device kernel in
[docs/kernel.md](docs/kernel.md). The native terminal interface is described
in [docs/ui.md](docs/ui.md), and the Google-free Drive workflow in
[docs/drive.md](docs/drive.md). Native Wi-Fi recovery is covered in
[docs/wifi.md](docs/wifi.md), and the minimal resident service set in
[docs/services.md](docs/services.md). Android reduction is recorded in
[docs/android-debloat.md](docs/android-debloat.md), its boot rollback in
[docs/android-rollback.md](docs/android-rollback.md), and the Android
fallback surface in [docs/android-launcher.md](docs/android-launcher.md).
The complete phased execution plan is in [docs/roadmap.md](docs/roadmap.md).

## Pinned upstreams

- Kernel: `LineageOS/android_kernel_samsung_sm8250`
  at `be2e1ed031226cd08d4d0b3e51acdfb71ccbf521`
- Recovery device tree: `JeyKul/android_device_samsung_gts7xlwifi-twrp`
  at `0de0716a3478b16b0a5ec45c910d6787d61d352c`
- Android DT table packer: AOSP `platform/system/libufdt`
  at `131ee2db53ad7d9d4756555567894b01107cb26e`

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
