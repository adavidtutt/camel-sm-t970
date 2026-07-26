# Pre-boot hardware audit

This audit records what v5 contains before hardware qualification. It is
evidence that the required code and device descriptions are present, not a
claim that each device has probed successfully.

## Display and GPU

The Qualcomm display options are not all visible in the final `.config`.
For Kona, the pinned vendor tree's `techpack/display/config/konadisp.conf`
exports `DRM_MSM`, `DRM_MSM_SDE`, `DRM_MSM_DSI`, and the related KMS options
at build time. Inspection of the signed v1 `Image.gz` confirms the resulting
binary contains:

- `msm_drm_init` and `sde_kms_init`;
- SDE CRTC, plane, connector, and commit paths;
- DSI display power and bitrate paths;
- Samsung panel handling for `S6TUUM0_AMSA24VU01`;
- Qualcomm KGSL for the Adreno GPU.

All five signed DTBO revisions contain the SM-T970 OLED panel, ST
touchscreen, Wacom digitizer, QCA6390 Bluetooth/WLAN power wiring, USB-C,
four CS35L41 speaker amplifiers, battery, charging, and thermal nodes. The
rootfs contains Mesa's `msm_dri.so`, GBM/EGL, libdrm, Sway, and Foot.

The first boot must still prove that `/dev/dri/card0` exists, exposes a
connected mode, and can perform an atomic modeset. If it does not, retain
headless SSH and collect the DRM/SDE/DSI probe errors before changing a
kernel option.

## Input and connectivity

The kernel has the exact tablet project, `FTS1BA90A` touch, Wacom W9021,
QCA CLD WLAN, CNSS QCA6390, Bluetooth, USB ConfigFS NCM, ext4, sdfat, loop,
namespaces, cgroups, pstore, suspend, thermal, and Samsung battery paths
built in. There are no loadable `.ko` files; the release contains the
versioned built-in module metadata expected by kmod.

The rootfs includes iwd, rfkill, `firmware-atheros`, key-only SSH, and the
fixed USB recovery address `172.31.0.1/24`. Qualcomm subsystem firmware may
still depend on the tablet's preserved firmware partitions. Firmware-load
errors in `dmesg` are therefore a first-boot measurement, not a reason to
copy unverified blobs in advance.

## First-boot evidence

The initial isolated recovery boot must preserve at least:

```text
/mnt/sd/camel-linux/logs/boot-v4.log
/mnt/sd/camel-linux/logs/latest-boot-id
/mnt/sd/camel-linux/logs/boots/<boot-id>/dmesg.txt
/mnt/sd/camel-linux/logs/boots/<boot-id>/journal.txt
/mnt/sd/camel-linux/logs/boots/<boot-id>/failed-units.txt
```

Qualification order is headless initramfs, rootfs/systemd, USB NCM and SSH,
Wi-Fi fallback, ordinary Android return, display, touch, pen, audio, GPU,
then suspend and power. UI autostart remains disabled until the headless
recovery path survives that sequence.
