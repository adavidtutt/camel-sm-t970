package dev.transmutation.launcher;

import android.app.Activity;
import android.app.WallpaperManager;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.ColorDrawable;
import android.graphics.Rect;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.content.Context;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.io.InputStream;

public final class HomeActivity extends Activity {
    private static final int BLACK = Color.rgb(0, 0, 0);
    private static final int TEXT = Color.rgb(205, 255, 210);
    private static final int DIM = Color.rgb(90, 145, 96);

    private TextView output;
    private EditText command;
    private Typeface dos;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        dos = Typeface.createFromAsset(getAssets(), "PxPlus_IBM_VGA8.ttf");
        Window window = getWindow();
        window.setBackgroundDrawable(new ColorDrawable(BLACK));
        window.getDecorView().setBackgroundColor(BLACK);
        setBarColor(window, "setStatusBarColor");
        setBarColor(window, "setNavigationBarColor");
        window.setSoftInputMode(
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE |
                WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE);
        buildUi();
        if ("atomic".equals(getIntent().getStringExtra("command"))) {
            setAtomicLockWallpaper();
        } else if ("black".equals(getIntent().getStringExtra("command"))) {
            setBlackWallpapers();
        }
    }

    private void setBarColor(Window window, String method) {
        try {
            Window.class.getMethod(method, int.class).invoke(window, BLACK);
        } catch (Exception ignored) {
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        command.requestFocus();
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.BOTTOM);
        root.setPadding(dp(22), dp(22), dp(22), dp(18));
        root.setBackgroundColor(BLACK);

        output = new TextView(this);
        output.setText(
                "Tutt Aerospace\n" +
                "Black Flag Discovery\n" +
                "Black Flag Data Labs\n" +
                "CAMEL\n\n" +
                "!command  ·  app name");
        output.setTextColor(DIM);
        output.setTextSize(14);
        output.setTypeface(dos);
        output.setGravity(Gravity.BOTTOM);
        output.setBackgroundColor(BLACK);
        output.setPadding(0, 0, 0, dp(12));
        root.addView(output, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        command = new EditText(this);
        command.setSingleLine(true);
        command.setHint("$");
        command.setHintTextColor(DIM);
        command.setTextColor(TEXT);
        command.setTextSize(22);
        command.setTypeface(dos);
        command.setBackgroundColor(BLACK);
        command.setPadding(0, dp(10), 0, dp(10));
        command.setInputType(
                InputType.TYPE_CLASS_TEXT |
                InputType.TYPE_TEXT_FLAG_AUTO_CORRECT);
        command.setOnEditorActionListener(
                new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(TextView view, int actionId, KeyEvent event) {
                if (event == null || event.getAction() == KeyEvent.ACTION_DOWN) {
                    execute(command.getText().toString().trim());
                    return true;
                }
                return false;
            }
        });
        root.addView(command, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        setContentView(root);
    }

    private void execute(String input) {
        command.setText("");
        if (input.length() == 0 || input.equals("term") || input.equals("termux")) {
            launchPackage("com.termux");
            return;
        }
        if (input.startsWith("!")) {
            runInTermux(input.substring(1).trim());
            return;
        }
        if (input.equals("atomic")) {
            setAtomicLockWallpaper();
            return;
        }
        if (input.equals("black")) {
            setBlackWallpapers();
            return;
        }
        launchByName(input);
    }

    private void setBlackWallpapers() {
        try {
            WallpaperManager manager = WallpaperManager.getInstance(this);
            Bitmap black = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888);
            black.eraseColor(BLACK);
            WallpaperManager.class.getMethod(
                    "setBitmap", Bitmap.class, Rect.class, boolean.class, int.class)
                    .invoke(manager, black, null, true, 3);
            black.recycle();
            output.setText("black lock installed");
        } catch (Exception error) {
            output.setText("black lock failed: " + error.getClass().getSimpleName());
        }
    }

    private void setAtomicLockWallpaper() {
        try (InputStream stream = getAssets().open("atomic-clock.png")) {
            Bitmap bitmap = BitmapFactory.decodeStream(stream);
            WallpaperManager manager = WallpaperManager.getInstance(this);
            WallpaperManager.class.getMethod(
                    "setBitmap", Bitmap.class, Rect.class, boolean.class, int.class)
                    .invoke(manager, bitmap, null, true, 2);
            Bitmap black = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888);
            black.eraseColor(BLACK);
            WallpaperManager.class.getMethod(
                    "setBitmap", Bitmap.class, Rect.class, boolean.class, int.class)
                    .invoke(manager, black, null, true, 1);
            black.recycle();
            bitmap.recycle();
            output.setText("atomic lock installed");
        } catch (Exception error) {
            output.setText("atomic lock failed: " + error.getClass().getSimpleName());
        }
    }

    private void launchByName(String query) {
        PackageManager pm = getPackageManager();
        Intent exact = pm.getLaunchIntentForPackage(query);
        if (exact != null) {
            startActivity(exact);
            return;
        }

        String needle = query.toLowerCase(Locale.ROOT);
        ApplicationInfo prefix = null;
        for (ApplicationInfo app : pm.getInstalledApplications(0)) {
            Intent launch = pm.getLaunchIntentForPackage(app.packageName);
            if (launch == null || app.packageName.equals(getPackageName())) continue;
            String label = String.valueOf(app.loadLabel(pm));
            String lower = label.toLowerCase(Locale.ROOT);
            if (lower.equals(needle)) {
                startActivity(launch);
                return;
            }
            if (prefix == null && lower.startsWith(needle)) prefix = app;
        }
        if (prefix != null) {
            startActivity(pm.getLaunchIntentForPackage(prefix.packageName));
        } else {
            output.setText("not found: " + query);
        }
    }

    private void runInTermux(String shellCommand) {
        if (shellCommand.length() == 0) {
            launchPackage("com.termux");
            return;
        }
        Intent intent = new Intent();
        intent.setClassName("com.termux", "com.termux.app.RunCommandService");
        intent.setAction("com.termux.RUN_COMMAND");
        intent.putExtra("com.termux.RUN_COMMAND_PATH",
                "/data/data/com.termux/files/usr/bin/bash");
        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS",
                new String[] {"-lc", shellCommand});
        intent.putExtra("com.termux.RUN_COMMAND_WORKDIR",
                "/data/data/com.termux/files/home");
        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", false);
        intent.putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0");
        try {
            startService(intent);
            output.setText("termux: " + shellCommand);
        } catch (RuntimeException error) {
            output.setText("Termux command permission/setup required");
            launchPackage("com.termux");
        }
    }

    private void launchPackage(String packageName) {
        Intent intent = getPackageManager().getLaunchIntentForPackage(packageName);
        if (intent == null) {
            output.setText("not installed: " + packageName);
            return;
        }
        startActivity(intent);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
