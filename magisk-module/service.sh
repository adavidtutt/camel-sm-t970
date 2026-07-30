#!/system/bin/sh
MODDIR=${0%/*}
exec "$MODDIR/busybox" nsenter -t 1 -m -- \
  "$MODDIR/busybox" sh "$MODDIR/camel-service"
