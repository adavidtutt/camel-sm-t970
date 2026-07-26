# Native terminal interface

CAMEL uses a native Wayland stack, not an Android launcher and not a desktop
environment. The selected compositor is Sway because the required interaction
model includes both tiled and floating windows. Foot is the terminal home
surface and Fuzzel is the command/application launcher.

The profile is installed when the rootfs is built with:

```sh
CAMEL_INCLUDE_UI=1 scripts/build-rootfs.sh
```

It remains dormant until hardware qualification succeeds and this marker is
created inside the rootfs:

```text
/etc/camel/enable-ui
```

Without that marker, `camel-ui.service` starts nothing and adds zero resident
UI processes. With it present, the service owns tty1, starts Sway through
seatd, launches a black/green Foot terminal as the first surface, and exposes
key bindings for the launcher, floating mode, fullscreen, focus, movement,
and workspaces.

This is the bootstrap interface. The custom touch keyboard, CAMEL status
surface, atomic/quasar lock clock, and Android-application bridge layer will
be native Wayland clients added after display, touch, suspend, and GPU gates
pass.
