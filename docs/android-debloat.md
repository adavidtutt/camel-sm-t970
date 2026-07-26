# Reversible Android reduction

Android remains the rollback and application-compatibility system while
native Linux is brought up. Its reduction is therefore staged, measured, and
reversible rather than expressed as destructive partition edits.

The exact scripts already exercised on the SM-T970 are preserved under
`android/debloat/`:

1. `probe.sh` captures packages, processes, services, memory, settings,
   Google app-ops, properties, and window state to microSD.
2. `stage1.sh` disables optional Google discovery/store and Samsung sharing,
   continuity, suggestion, diagnostics, and ornamental residents.
3. `stage2.sh` disables DeX, device-care, analytics, setup, and secondary
   Samsung service layers.
4. `stage3.sh` restricts Play Services background execution while retaining
   foreground APK compatibility and constrains the unused process cache.

Every stage has a matching rollback script. Package removal is intentionally
not used: disabled system packages remain available for recovery without a
factory reset. Multiwindow and floating-window functionality are retained by
not disabling the core framework, WindowManager, or SystemUI components that
implement them.

The earlier boot-completion guard and exact One UI/Quickstep escape hatches
are preserved separately in `android/android-rollback`; see
[android-rollback.md](android-rollback.md).

Before and after each stage:

```sh
su -c /path/to/probe.sh
```

Compare the resulting microSD snapshots and reboot before advancing. Google
Play Services and Store can be disabled permanently only after the Drive API
workflow and the required application set pass without them.
