#!/system/bin/sh

MODDIR=${0%/*}
LOGDIR=/storage/3963-3639/camel-linux/logs
BACKUPDIR=/storage/3963-3639/camel-linux/backups
IMAGE=/storage/3963-3639/camel-linux/artifacts/camel-recovery-v3.img
BLOCK=/dev/block/by-name/recovery
EXPECTED=db257d5197eafe5e4c964d29494dac5734f7706e4881cecd742a53797986cafb
IMAGE_BLOCKS=21213

# Disable before touching a block device. A reboot can never repeat this write.
touch "$MODDIR/disable"

for _ in $(seq 1 120); do
  [ -f "$IMAGE" ] && break
  sleep 1
done

mkdir -p "$LOGDIR" "$BACKUPDIR"
LOG="$LOGDIR/recovery-v3-install.log"
exec >"$LOG" 2>&1

echo "CAMEL recovery v3 installer"
date -Is

[ -f "$IMAGE" ] || {
  echo "FAIL: v3 image not available"
  exit 10
}

actual=$(sha256sum "$IMAGE" | awk '{print $1}')
[ "$actual" = "$EXPECTED" ] || {
  echo "FAIL: source hash mismatch: $actual"
  exit 11
}

[ -b "$BLOCK" ] || {
  echo "FAIL: recovery block missing"
  exit 12
}

size=$(blockdev --getsize64 "$BLOCK") || exit 13
blocks=$((size / 4096))
echo "recovery_size=$size blocks=$blocks"
[ "$size" -ge 86888448 ] || {
  echo "FAIL: recovery partition smaller than image"
  exit 14
}

backup="$BACKUPDIR/current-recovery-pre-v3.img"
dd if="$BLOCK" of="$backup" bs=4096 count="$blocks" conv=fsync || exit 20
sha256sum "$backup" >"$backup.sha256" || exit 21
echo "backup complete"

dd if="$IMAGE" of="$BLOCK" bs=4096 count="$IMAGE_BLOCKS" conv=fsync || exit 30
sync

readback=$(dd if="$BLOCK" bs=4096 count="$IMAGE_BLOCKS" 2>/dev/null |
  sha256sum | awk '{print $1}')
[ "$readback" = "$EXPECTED" ] || {
  echo "FAIL: recovery readback mismatch: $readback"
  exit 31
}

echo "CAMEL_RECOVERY_V3_INSTALLED=1"
echo "readback_sha256=$readback"
date -Is
