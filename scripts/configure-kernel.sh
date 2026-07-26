#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
kernel_src=${KERNEL_SRC:-"$root_dir/build/kernel/source"}
kernel_out=${KERNEL_OUT:-"$root_dir/build/kernel/out"}

[ -x "$kernel_src/scripts/kconfig/merge_config.sh" ] || {
  echo "KERNEL_SRC does not contain the pinned Samsung SM8250 source" >&2
  exit 2
}

base="$kernel_src/arch/arm64/configs/vendor/kona-perf_defconfig"
common="$kernel_src/arch/arm64/configs/vendor/samsung/kona-sec-common.config"
device="$kernel_src/arch/arm64/configs/vendor/samsung/gts7xlwifi.config"
camel="$root_dir/configs/camel-linux.fragment"

mkdir -p "$kernel_out"
"$kernel_src/scripts/kconfig/merge_config.sh" -m -r -O "$kernel_out" \
  "$base" "$common" "$device" "$camel"

make -C "$kernel_src" O="$kernel_out" ARCH=arm64 olddefconfig

required=(
  CONFIG_SEC_GTS7XL_PROJECT=y
  CONFIG_MACH_GTS7XLWIFI_EUR_OPEN=y
  CONFIG_PANEL_S6TUUM0_AMSA24VU01_WQXGA=y
  CONFIG_TOUCHSCREEN_FTS1BA90A=y
  CONFIG_EPEN_WACOM_W9021=y
  CONFIG_QCA_CLD_WLAN=y
  CONFIG_CNSS_QCA6390=y
  CONFIG_DEVTMPFS=y
  CONFIG_PID_NS=y
  CONFIG_USER_NS=y
  CONFIG_USB_CONFIGFS_NCM=y
  CONFIG_EXT4_FS=y
  CONFIG_SDFAT_FS=y
)

for setting in "${required[@]}"; do
  grep -qx "$setting" "$kernel_out/.config" || {
    echo "Required kernel setting missing after resolution: $setting" >&2
    exit 10
  }
done

if grep -qx 'CONFIG_SEC_R8Q_PROJECT=y' "$kernel_out/.config"; then
  echo "Wrong-device R8Q configuration leaked into the SM-T970 build" >&2
  exit 11
fi

echo "Configured native CAMEL kernel at $kernel_out/.config"
