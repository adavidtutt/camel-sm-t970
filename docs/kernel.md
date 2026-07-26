# Native SM-T970 kernel

The kernel embedded in the recovered diagnostic recovery is not a suitable
final tablet kernel. Its embedded configuration enables:

```text
CONFIG_SEC_R8Q_PROJECT=y
CONFIG_MACH_R8Q_EUR_OPEN=y
```

and disables the SM-T970 panel, FocalTech touchscreen, and Wacom drivers.
It remains useful only as a known boot-chain probe.

The native CAMEL kernel is generated from the pinned Samsung SM8250 source
by merging, in order:

1. `vendor/kona-perf_defconfig`
2. `vendor/samsung/kona-sec-common.config`
3. `vendor/samsung/gts7xlwifi.config`
4. `configs/camel-linux.fragment`

`scripts/configure-kernel.sh` resolves dependencies with `olddefconfig` and
then refuses the build unless the SM-T970 project, panel, touchscreen,
Wacom, QCA6390, Linux namespace, storage, and USB recovery settings survive.
It also explicitly rejects an R8Q configuration.

The pinned tree contains a known internal mismerge: `scripts/as-version.sh`
calls `scripts/min-tool-version.sh`, but the latter is absent. CAMEL restores
the missing GPL-2.0 helper from upstream Linux v5.15 before configuration;
the compatibility file is preserved in `kernel-patches/` rather than hidden
inside CI.

Build locally with:

```sh
scripts/build-kernel.sh
```

The source checkout and compilation output remain under ignored `build/`;
hashed images, the concatenated Kona base `dtb`, all selected DTBs/DTBOs,
an Android DT table `dtbo.img`, a stripped and dependency-indexed
`modules/lib/modules/<release>` tree, and resolved configuration enter
`out/kernel`. The DT table packer is pinned in `sources.lock`, uses the
device's 4096-byte page size, and packages the five Wi-Fi European hardware
revisions in order. The build refuses to
publish unless all five SM-T970 Wi-Fi European hardware-revision overlays
(`r02` through `r06`) exist.
Binder, binderfs, ashmem, and the container cgroup controllers are built in
for a future Android compatibility container, but the rootfs starts no
Android runtime or container service by default.
The manual `Build CAMEL kernel` GitHub workflow performs the same build
without consuming phone storage or hotspot bandwidth.

After downloading a successful `camel-kernel` Actions artifact, create the
small, signed release set with:

```sh
scripts/package-kernel-release.sh path/to/camel-kernel
```

The result contains `Image.gz`, `dtb`, `dtbo.img`, the versioned module tree
as a zstd tar archive, a portable `SHA256SUMS`, and its detached Ed25519
signature. The private release key never enters CI or Git.
