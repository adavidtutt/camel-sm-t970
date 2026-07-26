#!/system/bin/sh
set -eu

cmd package install-existing --user 0 com.sec.android.app.launcher >/dev/null
pm enable --user 0 com.sec.android.app.launcher >/dev/null
cmd package set-home-activity --user 0 \
    com.sec.android.app.launcher/.activities.LauncherActivity
am start -a android.intent.action.MAIN -c android.intent.category.HOME
