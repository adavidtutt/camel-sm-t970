#!/system/bin/sh
settings put secure edge_enable 1
for package in \
  com.samsung.android.app.appsedge \
  com.samsung.android.app.cocktailbarservice \
  com.samsung.android.app.clipboardedge \
  com.samsung.android.app.taskedge \
  com.samsung.android.service.peoplestripe
do
  cmd package install-existing --user 0 "$package"
done
