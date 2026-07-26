#!/system/bin/sh
# Secondary UI, diagnostics, DeX, and device-care residents.
PACKAGES="
com.samsung.android.fmm
com.samsung.android.vtcamerasettings
com.sec.android.diagmonagent
com.android.settings.intelligence
com.samsung.android.privacydashboard
com.samsung.android.app.smartcapture
com.samsung.android.scpm
com.samsung.android.lool
com.samsung.android.sm.provider
com.sec.android.desktopmode.uiservice
com.sec.android.dexsystemui
com.sec.android.app.desktoplauncher
com.samsung.android.dqagent
com.samsung.android.knox.analytics.uploader
com.samsung.android.beaconmanager
com.samsung.android.easysetup
com.samsung.android.mobileservice
com.samsung.android.rubin.app
com.samsung.android.svcagent
com.sec.android.soagent
"

for package in $PACKAGES; do
  pm path "$package" >/dev/null 2>&1 || continue
  pm disable-user --user 0 "$package"
  am force-stop "$package"
done
