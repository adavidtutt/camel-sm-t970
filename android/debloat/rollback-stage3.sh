#!/system/bin/sh
cmd appops set com.google.android.gms RUN_IN_BACKGROUND default
cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND default
cmd appops set com.google.android.gms WAKE_LOCK default
am set-standby-bucket com.google.android.gms active

pm enable --user 0 com.samsung.android.app.galaxyfinder
pm enable --user 0 com.samsung.android.dsms
settings put global app_process_limit -1
settings delete global cached_apps_freezer
