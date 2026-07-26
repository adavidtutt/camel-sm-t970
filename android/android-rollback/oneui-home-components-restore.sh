#!/system/bin/sh
set -eu

pm enable --user 0 \
    com.sec.android.app.launcher/.activities.LauncherActivity
pm enable --user 0 \
    com.sec.android.app.launcher/com.android.launcher3.uioverrides.QuickstepLauncher
cmd package set-home-activity --user 0 \
    com.vincent_falzon.discreetlauncher/.ActivityMain
