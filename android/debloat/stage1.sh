#!/system/bin/sh
# High-memory optional services. Reversible with rollback-stage1.sh.
PACKAGES="
com.google.android.googlequicksearchbox
com.android.vending
com.google.android.apps.turbo
com.google.android.as
com.samsung.android.honeyboard
com.samsung.android.service.aircommand
com.sec.android.app.samsungapps
com.samsung.android.app.sharelive
com.samsung.android.smartsuggestions
com.samsung.android.inputshare
com.wssyncmldm
com.sec.android.diagmonagent
com.samsung.android.mapsagent
com.samsung.android.mcfserver
com.samsung.android.mcfds
com.samsung.android.mdx
com.samsung.android.mdecservice
com.samsung.android.smartmirroring
com.samsung.android.net.wifi.wifiguider
com.samsung.android.server.wifi.mobilewips
com.samsung.android.scs
com.samsung.cmh
"

for package in $PACKAGES; do
  pm path "$package" >/dev/null 2>&1 || continue
  pm disable-user --user 0 "$package"
  am force-stop "$package"
done

settings put system edge_lighting 0
settings put system edge_lighting_show_condition 1
pkill -f 'com.android.systemui:edgelighting' 2>/dev/null || true
