# CAMEL execution roadmap

The target is a Linux-first SM-T970 with a minimal native terminal UI,
phone-based recovery, and Android applications available only when requested.
Each phase leaves a bootable, versioned checkpoint. A later phase never
replaces the rollback path created by an earlier phase.

## Phase 0: preserve and inventory — complete

- preserve stock recovery, rooted Android boot, CAMEL images, and hashes
- recover exact kernel and recovery-device source revisions
- archive the recovered kernel configuration and initramfs
- keep recovery material on both phone and microSD

Exit gate: every image has a SHA-256 and at least two independent copies.

## Phase 1: diagnostic recovery — built, hardware gate pending

- build the AVB-valid v3 recovery image
- mount the microSD read-write with `sdfat` and fallbacks
- attach the Debian ext4 image through loop
- persist stage and failure codes to microSD
- verify the installed recovery partition by read-back hash
- boot recovery once, then prove an ordinary reboot returns to Android

Exit gate: `boot-v3.log`, `systemd-v3.log`, and `boot-v3.success` exist;
Android still boots without recovery or a data wipe.

## Phase 2: unattended access and diagnostics

- bring up ConfigFS USB NCM before relying on Wi-Fi
- assign the tablet `172.31.0.1/24`
- enable key-only SSH for `camel`
- add serial/console, pstore, ramoops, journal, and previous-boot collection
- add Wi-Fi firmware and a minimal network profile fallback
- produce a phone-side `camel-connect` command for discovery and SSH

Exit gate: a phone with no special desktop software can diagnose the tablet
over USB after every successful kernel boot.

## Phase 3: reproducible kernel

- reconstruct the pinned Samsung/Lineage kernel source tree
- reproduce the recovered recovery kernel before changing its configuration
- publish toolchain, config fragment, DTB/DTBO, and image hashes
- enable required Linux facilities: devtmpfs, namespaces, cgroups v2,
  overlayfs, DRM/KMS, input, audio, Wi-Fi, Bluetooth, USB gadget, loop,
  ext4, sdfat, pstore, and ramoops
- change one hardware domain per signed test image

Exit gate: CI and the phone build path produce the same bootable kernel from
pinned inputs.

## Phase 4: hardware enablement

- display panel, backlight, touch, orientation, and S Pen input
- UFS and microSD reliability under sustained I/O
- USB-C host/device mode and charging
- Wi-Fi, Bluetooth, audio, buttons, sensors, and GNSS
- GPU acceleration after a stable software-rendered baseline
- suspend/resume, thermal control, battery reporting, and charging limits

Exit gate: a 24-hour test completes without filesystem damage, thermal
runaway, unrecoverable suspend, or loss of the phone recovery link.

## Phase 5: native CAMEL interface

- boot to a minimal Wayland compositor without a desktop environment
- launch a terminal as the home surface
- provide a small searchable app/command launcher
- apply OLED black, DOS typography, green status elements, and the CAMEL
  identity
- integrate the atomic/quasar clock as a native lock surface
- add an on-screen keyboard with black keys, green legends, autocorrection,
  visible shift state, and long-press backspace
- retain floating and tiled windows

Exit gate: terminal, launcher, keyboard, lock screen, rotation, suspend, and
resume work without Android SystemUI.

## Phase 6: data workflow and Google removal

- configure rclone/Drive OAuth with tokens outside the public repository
- implement mount, sync, conflict, offline queue, and token backup behavior
- replace Google-dependent workflows with API or browser paths
- remove Play Store and Play Services only after workflow parity is proven

Exit gate: the user's Drive workflow survives a reboot, an offline edit, and
token restoration without Google services running.

## Phase 7: on-demand Android applications

- preserve the known-good Android installation as a separate bootable system
- first support explicit reboot-to-Android and return-to-CAMEL commands
- evaluate a container only after binder, namespaces, GPU, audio, and input
  are stable
- start Android services only when an Android application is requested
- keep multiwindow and floating-window behavior where the chosen runtime
  supports it

Exit gate: selected APKs launch deliberately and leave no Android services
resident after shutdown.

## Phase 8: A/B rootfs and self-recovery

- introduce immutable `rootfs-a` and `rootfs-b` images
- keep mutable data in a separately backed-up filesystem
- sign a release manifest containing image hashes and minimum versions
- stage updates only into the inactive slot
- require a boot-success marker before committing a slot
- automatically fall back after repeated failed boots
- retain a rescue initramfs that can verify, repair, select, and boot slots

Exit gate: power loss during every update stage still leaves one verified
bootable system.

## Phase 9: memory, power, and release qualification

- record boot time, idle RSS/PSS, wakeups, CPU residency, thermals, and drain
- remove or mask services only when measurements show they are unnecessary
- establish performance and battery regression limits in CI
- run cold-boot, suspend, charging, low-battery, full-storage, and corrupt-slot
  tests
- publish signed recovery, kernel, rootfs, manifest, hashes, and exact
  restoration instructions

Exit gate: CAMEL meets the measured memory and battery targets and can be
restored using only the phone, microSD, and published artifacts.

## Immediate critical path

1. Read and verify `recovery-v3-install.log`.
2. Perform one isolated CAMEL recovery boot.
3. Read persistent initramfs/systemd logs from microSD.
4. Fix only the failed gate, rebuild, and repeat.
5. Prove normal Android return.
6. Establish USB NCM SSH.
7. Begin the reproducible kernel build.
