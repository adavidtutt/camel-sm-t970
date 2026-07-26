#!/system/bin/sh
# Retain Google APK compatibility while preventing idle residency.
cmd appops set com.google.android.gms RUN_IN_BACKGROUND ignore
cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND ignore
cmd appops set com.google.android.gms WAKE_LOCK ignore
am set-standby-bucket com.google.android.gms restricted
am force-stop com.google.android.gms

for package in \
  com.samsung.android.app.galaxyfinder \
  com.samsung.android.dsms; do
  pm path "$package" >/dev/null 2>&1 || continue
  pm disable-user --user 0 "$package"
  am force-stop "$package"
done

am force-stop com.sec.android.diagmonagent
settings put global app_process_limit 4
settings put global cached_apps_freezer enabled
settings put global always_finish_activities 0
