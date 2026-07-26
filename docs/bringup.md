# Bring-up gates

Each gate must pass before proceeding.

## Gate 0: artifact integrity

- recovery AVB verifies
- recovery SHA-256 verifies on phone and SD
- rootfs passes `e2fsck -fn`
- rootfs SHA-256 verifies
- stock recovery Odin package exists on phone and SD

Initialize slot A only after its published hash verifies:

```sh
scripts/stage-first-rootfs.sh rootfs-a.ext4 SHA256 /storage/3963-3639
```

The staging command is idempotent for the same image, refuses to overwrite a
different slot A, hashes the SD copy after writing, and atomically creates the
initial A/B boot state.

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

`boot-v3.success` must exist during the diagnostic phase. For the A/B image,
the per-boot report and slot success marker must show the
multi-user target with no critical failed units.

## Gate 3: phone recovery link

The phone must receive a USB network interface and reach:

```sh
ping 172.31.0.1
ssh -i camel-bringup-ed25519 camel@172.31.0.1
```

The primary recovery identity lives on the phone at:

```text
~/.ssh/camel-phone-recovery-ed25519
```

Its public fingerprint is:

```text
SHA256:VUl+IQULsC36hhVLbFe5T+uILIos3yYGco9RQKeEFSg
```

Only the public key is stored in this repository and the rootfs. From phone
Termux, `scripts/camel-connect.sh` detects the USB interface, applies the
static fallback address when phone root is available, verifies reachability,
and opens key-only SSH. The private key must be backed up encrypted, but
never placed on the tablet as its only copy.

## Gate 4: Android return

A normal reboot must return to rooted Android without a wipe, boot loop,
or recovery dependency.
