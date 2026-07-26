package dev.transmutation.launcher;

import android.accessibilityservice.AccessibilityService;
import android.app.KeyguardManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.PixelFormat;
import android.view.Gravity;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;

public final class LockClockService extends AccessibilityService {
    private WindowManager windows;
    private InstrumentClockView clock;
    private boolean attached;

    private final BroadcastReceiver stateReceiver = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            updateOverlay();
        }
    };

    @Override protected void onServiceConnected() {
        windows = (WindowManager) getSystemService(WINDOW_SERVICE);
        IntentFilter states = new IntentFilter();
        states.addAction(Intent.ACTION_SCREEN_ON);
        states.addAction(Intent.ACTION_SCREEN_OFF);
        states.addAction(Intent.ACTION_USER_PRESENT);
        registerReceiver(stateReceiver, states);
        updateOverlay();
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {
        updateOverlay();
    }

    @Override public void onInterrupt() {
    }

    private void updateOverlay() {
        KeyguardManager keyguard =
                (KeyguardManager) getSystemService(KEYGUARD_SERVICE);
        boolean locked = keyguard != null && keyguard.isKeyguardLocked();
        if (locked && !attached) {
            clock = new InstrumentClockView(this, true);
            int screenHeight = getResources().getDisplayMetrics().heightPixels;
            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    Math.round(screenHeight * .72f),
                    2032,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE |
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
                    PixelFormat.TRANSLUCENT);
            params.gravity = Gravity.TOP;
            windows.addView(clock, params);
            attached = true;
        } else if (!locked && attached) {
            windows.removeView(clock);
            attached = false;
            clock = null;
        }
    }

    @Override public void onDestroy() {
        try {
            unregisterReceiver(stateReceiver);
        } catch (Exception ignored) {
        }
        if (attached && windows != null && clock != null) {
            windows.removeView(clock);
        }
        attached = false;
        super.onDestroy();
    }
}
