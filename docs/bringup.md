# Bring-up gates

Each gate must pass before proceeding.

## Gate 0: artifact integrity

- recovery AVB verifies
- recovery SHA-256 verifies on phone and SD
- rootfs passes `e2fsck -fn`
- rootfs SHA-256 verifies
- stock recovery Odin package exists on phone and SD

## Gate 1: initramfs

Expected SD log stages:

```text
CAMEL_STAGE=SD_READY
CAMEL_STAGE=LOOP_READY
CAMEL_STAGE=ROOT_READY
CAMEL_STAGE=SWITCH_ROOT
```

Failure codes:

- `E01-E03`: kernel pseudo-filesystem mount
- `E10`: SD or root image discovery
- `E20-E21`: loop device
- `E30`: ext4 root
- `E40-E44`: mount migration
- `E50`: switch-root return

## Gate 2: systemd

`boot-v3.success` must exist and `systemd-v3.log` must show the
multi-user target with no critical failed units.

## Gate 3: phone recovery link

The phone must receive a USB network interface and reach:

```sh
ping 172.31.0.1
ssh -i camel-bringup-ed25519 camel@172.31.0.1
```

## Gate 4: Android return

A normal reboot must return to rooted Android without a wipe, boot loop,
or recovery dependency.
