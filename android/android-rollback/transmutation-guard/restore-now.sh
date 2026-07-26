#!/system/bin/sh

STATE=/data/adb/transmutation-guard
SNAPSHOT=$STATE/enabled-packages.txt

if [ ! -s "$SNAPSHOT" ]; then
    echo "Snapshot missing: $SNAPSHOT" >&2
    exit 1
fi

restored=0
failed=0
while IFS= read -r package; do
    [ -n "$package" ] || continue
    cmd package install-existing --user 0 "$package" >/dev/null 2>&1 || true
    if pm enable --user 0 "$package" >/dev/null 2>&1; then
        restored=$((restored + 1))
    else
        failed=$((failed + 1))
    fi
done < "$SNAPSHOT"

for component in \
    com.sec.android.app.launcher/.activities.LauncherActivity \
    com.sec.android.app.launcher/com.android.launcher3.uioverrides.QuickstepLauncher \
    com.sec.android.app.launcher/com.android.quickstep.RecentsActivity \
    com.sec.android.app.launcher/com.android.quickstep.TouchInteractionService
do
    pm enable --user 0 "$component" >/dev/null 2>&1 || true
done

rm -f "$STATE/boot-in-progress" "$STATE/force-restore"
echo "Restored: $restored; failed: $failed"
