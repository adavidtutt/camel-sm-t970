# Minimal native service set

CAMEL keeps only the services required for recovery, connectivity, and
diagnostics resident after a normal native boot:

- systemd core services, udev, journald, networkd, resolved, and time sync;
- OpenSSH with key-only login;
- USB NCM gadget setup;
- iwd for the independent Wi-Fi recovery path;
- the one-shot boot report, diagnostics, and A/B health gate.

The image masks cron, automatic APT timers, and ext4 scrub timers. Package
updates are deliberate operator actions, and the rootfs image itself is
versioned A/B, so background package maintenance adds wakeups without adding
a useful rollback boundary.

Seatd is installed but not enabled globally. The dormant `camel-ui.service`
requires and starts it only when `/etc/camel/enable-ui` exists. The Drive
mount likewise starts only when its marker and private rclone configuration
both exist. No Android container service is enabled by default.

To inspect the actual hardware result:

```sh
systemctl --type=service --state=running
systemd-cgtop --iterations=1
ps -eo pid,rss,comm --sort=-rss
```

The persistent boot diagnostics save the running state and failures on
microSD before tuning proceeds.
