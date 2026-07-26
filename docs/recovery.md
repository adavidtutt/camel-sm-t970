# Recovery and rollback

## Preserved artifacts

Keep all of these on both the phone and microSD:

- stock `recovery.img.lz4`
- `AP_STOCK_RECOVERY_T970XXS7DXH1_ROLLBACK.tar.md5`
- `AP_CAMEL_RECOVERY_V3.tar.md5`
- current pre-v3 recovery block backup and SHA-256
- rooted Android boot rollback
- CAMEL rootfs A/B images and checksums

## Recovery isolation

Experimental CAMEL images target only `/dev/block/by-name/recovery`.
Never write `boot`, `vbmeta`, `super`, `userdata`, or dynamic partitions
as part of a Linux bring-up.

## Failed CAMEL boot

From the initramfs rescue shell:

```sh
reboot -f
```

A power-cycle without the recovery key chord returns to Android because
Android remains on the separate boot partition.

If recovery itself must be restored, enter Samsung Download Mode and flash
the stock recovery Odin tar in the AP slot.
