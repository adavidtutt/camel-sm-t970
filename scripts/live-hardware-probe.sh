#!/bin/sh
set -u

sd=/mnt/sd/camel-linux
stamp=$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%s)
out=$sd/logs/manual-probes/$stamp
mkdir -p "$out" || {
  echo "microSD log path is unavailable: $out" >&2
  exit 2
}

capture() {
  name=$1
  shift
  "$@" >"$out/$name" 2>&1 || true
}

capture uname.txt uname -a
capture cmdline.txt cat /proc/cmdline
capture mounts.txt mount
capture memory.txt free -h
capture processes-rss.txt ps -eo pid,ppid,comm,rss,vsz,stat
capture failed-units.txt systemctl --failed --no-pager
capture services.txt systemctl --type=service --all --no-pager
capture ip-address.txt ip address
capture ip-route.txt ip route
capture rfkill.txt rfkill list
capture input-devices.txt cat /proc/bus/input/devices
capture dev-input.txt ls -la /dev/input
capture dev-dri.txt ls -la /dev/dri
capture dev-snd.txt ls -la /dev/snd
capture asound-cards.txt cat /proc/asound/cards
capture asound-pcms.txt cat /proc/asound/pcm
capture dmesg.txt dmesg -T
capture journal.txt journalctl -b --no-pager

{
  find /sys/class/drm -maxdepth 3 -type f \
    \( -name status -o -name modes -o -name enabled -o \
       -name dpms -o -name edid \) -print 2>/dev/null |
  while IFS= read -r file; do
    echo "--- $file"
    if [ "${file##*/}" = edid ]; then
      wc -c <"$file" 2>/dev/null || true
    else
      cat "$file" 2>/dev/null || true
    fi
  done
} >"$out/drm-sysfs.txt" 2>&1

{
  for zone in /sys/class/thermal/thermal_zone*; do
    [ -d "$zone" ] || continue
    echo "--- ${zone##*/}"
    cat "$zone/type" 2>/dev/null || true
    cat "$zone/temp" 2>/dev/null || true
  done
} >"$out/thermal.txt" 2>&1

{
  for supply in /sys/class/power_supply/*; do
    [ -d "$supply" ] || continue
    echo "--- ${supply##*/}"
    for key in status capacity voltage_now current_now temp \
      charge_now charge_full health online usb_type; do
      [ -f "$supply/$key" ] || continue
      printf '%s=' "$key"
      cat "$supply/$key" 2>/dev/null || true
    done
  done
} >"$out/power.txt" 2>&1

{
  for gadget in /sys/kernel/config/usb_gadget/*; do
    [ -d "$gadget" ] || continue
    echo "--- ${gadget##*/}"
    find "$gadget" -maxdepth 3 -type l -o -type f 2>/dev/null |
      sort
  done
} >"$out/usb-gadget.txt" 2>&1

if [ -d /sys/fs/pstore ]; then
  mkdir -p "$out/pstore"
  cp -a /sys/fs/pstore/. "$out/pstore/" 2>/dev/null || true
fi

sha256sum "$out"/*.txt >"$out/SHA256SUMS" 2>/dev/null || true
printf '%s\n' "$out" >"$sd/logs/latest-manual-probe"
sync
echo "CAMEL hardware probe saved to $out"
