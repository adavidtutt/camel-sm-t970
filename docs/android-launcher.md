# Android fallback launcher and keyboard

`android/launcher` preserves the exact native Android fallback surface built
on the tablet before Linux bring-up:

- a black command-oriented HOME activity that opens Termux by default;
- app launch by label or package name;
- explicit `!command` dispatch into Termux;
- the black/green DOS-style input method;
- the physical atomic lock clock and its lock-screen service;
- the CAMEL, Tutt Aerospace, Black Flag Discovery, and Black Flag Data Labs
  identity.

This APK is an Android fallback and application launcher, not the final
Linux home surface. It remains useful while Android is the recovery host and
later when the Android compatibility layer is started on demand.

The public repository contains source and visual assets. It deliberately
does not contain the private APK update-signing keystore, passwords, a copied
Android SDK `android.jar`, generated APKs, or build intermediates.

Build on a configured host:

```sh
ANDROID_JAR=/path/to/android.jar \
CAMEL_ANDROID_KEYSTORE=/private/path/camel-launcher.keystore \
CAMEL_ANDROID_KEY_ALIAS=transmutation \
CAMEL_ANDROID_STORE_PASS='...' \
CAMEL_ANDROID_KEY_PASS='...' \
android/launcher/build.sh
```

For continuity with the APK already installed on the tablet, use its
original private update key. A different key requires uninstalling the old
APK before installation. Keep at least two encrypted copies of that key
outside the tablet; never commit it.
