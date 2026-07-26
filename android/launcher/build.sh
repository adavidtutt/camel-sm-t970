#!/data/data/com.termux/files/usr/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD=$ROOT/build
ANDROID_JAR=${ANDROID_JAR:-${ANDROID_HOME:-}/platforms/android-35/android.jar}
KEYSTORE=${CAMEL_ANDROID_KEYSTORE:-}
KEY_ALIAS=${CAMEL_ANDROID_KEY_ALIAS:-transmutation}
STORE_PASS=${CAMEL_ANDROID_STORE_PASS:-}
KEY_PASS=${CAMEL_ANDROID_KEY_PASS:-$STORE_PASS}

if [ ! -f "$ANDROID_JAR" ]; then
    echo "Set ANDROID_JAR to an installed Android platform android.jar" >&2
    exit 2
fi

rm -rf "$BUILD"
mkdir -p "$BUILD/classes" "$BUILD/dex"

javac \
    -source 8 -target 8 \
    -classpath "$ANDROID_JAR" \
    -d "$BUILD/classes" \
    "$ROOT/src/dev/transmutation/launcher/HomeActivity.java" \
    "$ROOT/src/dev/transmutation/launcher/InstrumentClockView.java" \
    "$ROOT/src/dev/transmutation/launcher/LockClockService.java" \
    "$ROOT/src/dev/transmutation/launcher/TransmutationIme.java"

jar cf "$BUILD/classes.jar" -C "$BUILD/classes" .
d8 --no-desugaring --lib "$ANDROID_JAR" --min-api 23 \
    --output "$BUILD/dex" "$BUILD/classes.jar"

aapt2 compile --dir "$ROOT/res" -o "$BUILD/resources.zip"

aapt2 link \
    -I "$ANDROID_JAR" \
    --manifest "$ROOT/AndroidManifest.xml" \
    -A "$ROOT/assets" \
    -R "$BUILD/resources.zip" \
    -o "$BUILD/unsigned.apk"

cd "$BUILD/dex"
zip -q "$BUILD/unsigned.apk" classes.dex

if [ -n "$KEYSTORE" ]; then
    [ -f "$KEYSTORE" ] || {
        echo "CAMEL_ANDROID_KEYSTORE does not exist: $KEYSTORE" >&2
        exit 3
    }
    [ -n "$STORE_PASS" ] || {
        echo "CAMEL_ANDROID_STORE_PASS is required for a signed build" >&2
        exit 4
    }
    CAMEL_ANDROID_KEY_PASS=$KEY_PASS
    export CAMEL_ANDROID_STORE_PASS CAMEL_ANDROID_KEY_PASS
    apksigner sign \
        --ks "$KEYSTORE" \
        --ks-key-alias "$KEY_ALIAS" \
        --ks-pass env:CAMEL_ANDROID_STORE_PASS \
        --key-pass env:CAMEL_ANDROID_KEY_PASS \
        --out "$BUILD/camel-launcher.apk" \
        "$BUILD/unsigned.apk"
    apksigner verify --verbose "$BUILD/camel-launcher.apk"
    sha256sum "$BUILD/camel-launcher.apk"
else
    echo "Built unsigned APK at $BUILD/unsigned.apk"
    echo "Set CAMEL_ANDROID_KEYSTORE and password variables to sign it."
fi
