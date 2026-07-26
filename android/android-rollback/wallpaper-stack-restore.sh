#!/system/bin/sh
for package in \
  com.android.wallpapercropper \
  com.android.wallpaperbackup \
  com.samsung.android.wallpaper.res \
  com.android.wallpaper.livepicker \
  com.samsung.android.dynamiclock \
  com.samsung.android.themecenter
do
  cmd package install-existing --user 0 "$package"
done
