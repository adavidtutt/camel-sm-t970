#!/system/bin/sh

OUT=${1:-/storage/3963-3639/camel-linux/android-state}
STAMP=$(date +%Y%m%d-%H%M%S)
DIR=$OUT/probe-$STAMP
mkdir -p "$DIR" || exit 1

getprop >"$DIR/getprop.txt"
pm list packages -f >"$DIR/packages-all.txt"
pm list packages -d >"$DIR/packages-disabled.txt"
pm list packages -e >"$DIR/packages-enabled.txt"
dumpsys meminfo >"$DIR/meminfo.txt"
dumpsys activity processes >"$DIR/processes.txt"
dumpsys activity services >"$DIR/services.txt"
dumpsys window >"$DIR/window.txt"
settings list global >"$DIR/settings-global.txt"
settings list secure >"$DIR/settings-secure.txt"
settings list system >"$DIR/settings-system.txt"
cmd appops get com.google.android.gms >"$DIR/appops-gms.txt" 2>&1

echo "$DIR" >"$OUT/latest-probe.txt"
echo "CAMEL Android state captured at $DIR"
