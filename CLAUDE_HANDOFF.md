# Claude handoff — SM-T970 CAMEL dual environment

## Current tablet connection

- Device: Samsung SM-T970
- Android is booted and rooted with Magisk 30700.
- Last working wireless ADB endpoint: `10.115.239.94:40967`
- microSD Android mount: `/mnt/media_rw/3963-3639`
- Native root image: `/mnt/media_rw/3963-3639/camel-linux/images/rootfs-A.ext4`
- Boot state says slot A, release `camel-kernel-sm-t970-v2`.

## Completed in this session

1. Restored the signed Android launcher:
   `dev.transmutation.launcher/.HomeActivity`
2. Selected its IME:
   `dev.transmutation.launcher/.TransmutationIme`
3. Captured the pre-debloat state at:
   `/storage/3963-3639/camel-linux/android-state/probe-20260728-084340`
4. Applied the repository's reversible Android debloat stages 1, 2, and 3.
   There are currently 44 disabled packages. Multiwindow/SystemUI were not
   disabled.
5. Added native CAMEL rootfs integration to this repository and committed it:
   `1d6455e Integrate native CAMEL runtime and CLI tools`
6. Injected the actual CAMEL math + Sterile Mouth live harness into slot A:
   `/opt/camel`
7. Installed the native launchers in slot A:
   `/usr/local/bin/camel`
   `/usr/local/bin/camel-codex`
   `/usr/local/bin/camel-claude`
   `/usr/local/bin/camel-register-tools`

## Clean stopping state

- No rootfs loop mounts remain active.
- No tablet partition was flashed in this session.
- Kernel and recovery partitions were untouched.
- Android is usable with the restored launcher and keyboard.
- `rootfs.ext4` remains untouched as the prior fallback image.

## Only immediate blocker

The old slot-A Debian image lacks `python3`, `foot`, `sway`, and `seatd`.
CAMEL itself is correctly present, but `/usr/local/bin/camel` cannot start
until Python is installed.

Trying `apt` inside an Android-hosted chroot failed because Android denied
network sockets/DNS, even with GID 3003. Do not repeat that loop.

## Recommended continuation

Boot the native Linux path first. Once Debian owns the kernel networking,
install exactly:

```sh
apt-get update
apt-get install -y --no-install-recommends \
  python3-minimal foot sway seatd dbus-user-session nodejs npm
```

Then verify:

```sh
/usr/local/bin/camel /status
command -v foot sway python3 node npm
```

Register real Codex and Claude binaries only after their Linux clients are
installed:

```sh
camel-register-tools
camel tool codex --version
camel tool claude --version
```

Codex and Claude are intentionally on-demand with preserved TTY passthrough;
there are no idle background daemons.

If native networking cannot be reached, download the Debian ARM64 packages
outside Android and inject them into the inactive/rootfs image. Do not alter
the boot or recovery partitions merely to install userland packages.
