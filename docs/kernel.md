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

Build locally with:

```sh
scripts/build-kernel.sh
```

The source checkout and compilation output remain under ignored `build/`;
hashed images, DTBs, modules, and resolved configuration enter `out/kernel`.
The manual `Build CAMEL kernel` GitHub workflow performs the same build
without consuming phone storage or hotspot bandwidth.
