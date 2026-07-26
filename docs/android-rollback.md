# Android package and launcher rollback

`android/android-rollback` preserves the exact rollback source created during
the rooted Android reduction phase. It is intentionally separate from the
debloat stages.

The `transmutation-guard` Magisk module:

- captures the complete enabled-package set before a risky disable pass;
- creates a boot-in-progress marker;
- waits for Android's real `sys.boot_completed=1` signal;
- restores the captured packages and One UI launcher/Quickstep components
  only when the preceding Android boot did not complete;
- supports an explicit `force-restore` marker and manual restore command.

The standalone scripts restore the stock HOME activity, Quickstep components,
Edge/sidebar packages, and wallpaper services. They are escape hatches for
the Android bring-up phase. Their presence does not imply that One UI remains
part of the final Linux-first runtime.

Before another Android disable stage, install the guard, run:

```sh
su -c /data/adb/modules/transmutation-guard/capture-snapshot.sh
```

and verify that `/data/adb/transmutation-guard/enabled-packages.txt` is
nonempty. Keep a copy of that snapshot on microSD and the phone. The guard is
not a substitute for the stock recovery/Odin rollback or the native Linux
phone-recovery path.
