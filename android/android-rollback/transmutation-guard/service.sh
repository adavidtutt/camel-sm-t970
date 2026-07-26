#!/system/bin/sh

STATE=/data/adb/transmutation-guard
SNAPSHOT=$STATE/enabled-packages.txt
MARKER=$STATE/boot-in-progress
LOG=$STATE/guard.log

mkdir -p "$STATE"
chmod 700 "$STATE"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG"
}

wait_for_package_manager() {
    count=0
    while [ "$count" -lt 120 ]; do
        if cmd package list packages >/dev/null 2>&1; then
            return 0
        fi
        count=$((count + 1))
        sleep 1
    done
    return 1
}

restore_snapshot() {
    reason=$1
    log "RESTORE begin reason=$reason"

    if ! wait_for_package_manager; then
        log "RESTORE failed: package manager unavailable"
        return 1
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

    log "RESTORE end restored=$restored failed=$failed"
    rm -f "$MARKER"
    setprop ctl.restart zygote
}

if [ ! -s "$SNAPSHOT" ]; then
    log "Guard inactive: snapshot missing"
    exit 0
fi

if [ -f "$STATE/force-restore" ]; then
    rm -f "$STATE/force-restore"
    restore_snapshot manual
    exit $?
fi

if [ -f "$MARKER" ]; then
    restore_snapshot previous-boot-incomplete
    exit $?
fi

printf '%s\n' "$$" > "$MARKER"
log "Boot watch armed"

count=0
while [ "$count" -lt 180 ]; do
    if [ "$(getprop sys.boot_completed)" = "1" ]; then
        rm -f "$MARKER"
        log "Boot completed; guard disarmed"
        exit 0
    fi
    count=$((count + 1))
    sleep 1
done

restore_snapshot boot-timeout
