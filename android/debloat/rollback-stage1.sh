#!/system/bin/sh
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
  pm enable --user 0 "$package"
done
settings put system edge_lighting 1
