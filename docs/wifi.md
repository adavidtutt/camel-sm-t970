# Native Wi-Fi recovery path

The rootfs includes the QCA firmware package, `iwd`, `rfkill`, and a
systemd-networkd DHCP profile for wireless interfaces. USB NCM remains the
deterministic recovery path at `172.31.0.1`; Wi-Fi is the independent
fallback.

No SSID or password is stored in Git. From a CAMEL shell, configure a network
once with:

```sh
sudo iwctl station wlan0 scan
sudo iwctl station wlan0 get-networks
sudo iwctl station wlan0 connect YOUR_SSID
```

`iwd` stores the resulting protected profile under `/var/lib/iwd`. Preserve
that directory in encrypted private backup material, not in a public rootfs
overlay. On later boots iwd reconnects and systemd-networkd obtains an
address automatically.

Bring-up diagnostics record interface addresses, routes, kernel messages,
and failed services on microSD. If the interface name differs from `wlan0`,
the `wl*` network match still applies; use `iwctl device list` to identify it.
