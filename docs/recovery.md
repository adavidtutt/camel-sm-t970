# Recovery and rollback

## Preserved artifacts

Keep all of these on both the phone and microSD:

- stock `recovery.img.lz4`
- `AP_STOCK_RECOVERY_T970XXS7DXH1_ROLLBACK.tar.md5`
- `AP_CAMEL_RECOVERY_V3.tar.md5`
- current pre-v3 recovery block backup and SHA-256
- rooted Android boot rollback
- CAMEL rootfs A/B images and checksums

## Recovery isolation

Experimental CAMEL images target only `/dev/block/by-name/recovery`.
Never write `boot`, `vbmeta`, `super`, `userdata`, or dynamic partitions
as part of a Linux bring-up.

## Failed CAMEL boot

From the initramfs rescue shell:

```sh
reboot -f
```

A power-cycle without the recovery key chord returns to Android because
Android remains on the separate boot partition.

If recovery itself must be restored, enter Samsung Download Mode and flash
the stock recovery Odin tar in the AP slot.

## One-shot rooted-Android installer

The exact Magisk module used for the first v3 installation is preserved in
`android/recovery-installer-v3`. It is intentionally version-specific:

- it disables itself before accessing the recovery partition;
- it accepts only the pinned v3 source hash;
- it backs up the complete existing recovery partition;
- it writes only `/dev/block/by-name/recovery`;
- it reads the written bytes back and hashes them;
- it records success or a stable failure code on microSD.

Build the module with:

```sh
scripts/package-recovery-installer.sh
```

After Android reboots, verify the installer result from the phone:

```sh
scripts/verify-installed-recovery.sh TABLET_IP:ADB_PORT
```

The verifier is read-only. Do not enter recovery unless it prints
`VERIFIED: installed recovery matches CAMEL v3`.

## Embedded one-shot installer for later recoveries

After v3 hardware qualification, package an exact full-partition recovery
image with:

```sh
scripts/package-embedded-recovery-installer.sh v5 \
  camel-recovery.img
```

Unlike the historical v3 module, the resulting Magisk module embeds the
recovery image. At its single boot it:

1. disables itself before any block access;
2. verifies the embedded image size and SHA-256;
3. refuses to write unless microSD backup/log storage is available;
4. creates or verifies a complete pre-write recovery backup;
5. writes only `/dev/block/by-name/recovery`;
6. hashes the complete partition readback;
7. records the exact version and result persistently on microSD.

Packaging does not install or flash anything. The module is not used until
the v3 diagnostic boot, Android return, USB recovery link, and final artifact
hashes have all passed.
