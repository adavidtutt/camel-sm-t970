package dev.transmutation.launcher;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.inputmethodservice.InputMethodService;
import android.os.Bundle;
import android.os.Handler;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.inputmethod.InputConnection;
import android.view.textservice.SentenceSuggestionsInfo;
import android.view.textservice.SpellCheckerSession;
import android.view.textservice.SuggestionsInfo;
import android.view.textservice.TextInfo;
import android.view.textservice.TextServicesManager;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Locale;

public final class TransmutationIme extends InputMethodService
        implements SpellCheckerSession.SpellCheckerSessionListener {
    private static final int BLACK = Color.BLACK;
    private static final int KEY = Color.BLACK;
    private static final int EDGE = Color.rgb(39, 57, 42);
    private static final int TEXT = Color.rgb(208, 255, 210);
    private static final int ACTIVE = TEXT;

    private LinearLayout keyboard;
    private Typeface dos;
    private boolean shift;
    private boolean ctrl;
    private boolean autocorrect = false;
    private final StringBuilder word = new StringBuilder();
    private String suggestion;
    private String lastOriginal;
    private String lastCorrection;
    private SpellCheckerSession spelling;
    private SpeechRecognizer speech;
    private final Handler repeatHandler = new Handler();
    private boolean repeatingBackspace;
    private final Runnable backspaceRepeat = new Runnable() {
        @Override public void run() {
            repeatingBackspace = true;
            deleteBackward();
            repeatHandler.postDelayed(this, 48);
        }
    };

    @Override public void onCreate() {
        super.onCreate();
        dos = Typeface.createFromAsset(getAssets(), "PxPlus_IBM_VGA8.ttf");
        TextServicesManager manager =
                (TextServicesManager) getSystemService(TEXT_SERVICES_MANAGER_SERVICE);
        if (manager != null) {
            spelling = manager.newSpellCheckerSession(
                    null, Locale.getDefault(), this, true);
        }
    }

    @Override public View onCreateInputView() {
        keyboard = new LinearLayout(this);
        keyboard.setOrientation(LinearLayout.VERTICAL);
        keyboard.setPadding(dp(7), dp(5), dp(7), dp(7));
        keyboard.setBackgroundColor(BLACK);
        addRow("1","2","3","4","5","6","7","8","9","0","⌫");
        addRow("q","w","e","r","t","y","u","i","o","p","/");
        addRow("a","s","d","f","g","h","j","k","l","-","↵");
        addRow("⇧","z","x","c","v","b","n","m","_","|","←");
        addRow("ESC","CTRL","ALT","TAB","CORRECT","SPACE","MIC","←","↓","↑","→");
        return keyboard;
    }

    @Override public boolean onEvaluateFullscreenMode() {
        return false;
    }

    private void addRow(String... labels) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER);
        for (String label : labels) {
            TextView key = new TextView(this);
            key.setText(label);
            key.setTag(label);
            key.setGravity(Gravity.CENTER);
            key.setTextColor(TEXT);
            key.setTextSize(label.length() > 2 ? 12 : 18);
            key.setTypeface(dos);
            key.setBackgroundColor(KEY);
            key.setPadding(dp(2), dp(9), dp(2), dp(9));
            if ("⌫".equals(label)) {
                key.setOnTouchListener(new View.OnTouchListener() {
                    @Override public boolean onTouch(View view, MotionEvent event) {
                        if (event.getAction() == MotionEvent.ACTION_DOWN) {
                            showPressed((TextView) view, true);
                            repeatingBackspace = false;
                            repeatHandler.postDelayed(backspaceRepeat, 380);
                        } else if (event.getAction() == MotionEvent.ACTION_UP ||
                                event.getAction() == MotionEvent.ACTION_CANCEL) {
                            showPressed((TextView) view, false);
                            repeatHandler.removeCallbacks(backspaceRepeat);
                            if (!repeatingBackspace) deleteBackward();
                            repeatingBackspace = false;
                        }
                        return true;
                    }
                });
            } else {
                key.setOnTouchListener(new View.OnTouchListener() {
                    @Override public boolean onTouch(View view, MotionEvent event) {
                        if (event.getAction() == MotionEvent.ACTION_DOWN) {
                            showPressed((TextView) view, true);
                        } else if (event.getAction() == MotionEvent.ACTION_UP ||
                                event.getAction() == MotionEvent.ACTION_CANCEL) {
                            showPressed((TextView) view,
                                    isLatched((String) view.getTag()));
                        }
                        return false;
                    }
                });
                key.setOnClickListener(new View.OnClickListener() {
                    @Override public void onClick(View view) {
                        press((String) view.getTag(), (TextView) view);
                    }
                });
            }
            LinearLayout.LayoutParams params =
                    new LinearLayout.LayoutParams(0, dp(47), 1f);
            params.setMargins(dp(2), dp(2), dp(2), dp(2));
            row.addView(key, params);
        }
        keyboard.addView(row, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));
    }

    private void showPressed(TextView key, boolean pressed) {
        key.getPaint().setFakeBoldText(pressed);
        key.getPaint().setStyle(pressed
                ? Paint.Style.FILL_AND_STROKE : Paint.Style.FILL);
        key.getPaint().setStrokeWidth(pressed ? dp(1) : 0f);
        key.setTextColor(TEXT);
        key.invalidate();
    }

    private boolean isLatched(String key) {
        return ("⇧".equals(key) && shift) ||
                ("CTRL".equals(key) && ctrl) ||
                ("CORRECT".equals(key) && autocorrect);
    }

    private void press(String key, TextView view) {
        InputConnection input = getCurrentInputConnection();
        if (input == null) return;
        if ("⇧".equals(key)) {
            shift = !shift;
            showPressed(view, shift);
            refreshLetterCase();
        } else if ("CTRL".equals(key)) {
            ctrl = !ctrl;
            view.setTextColor(ctrl ? ACTIVE : TEXT);
        } else if ("CORRECT".equals(key)) {
            autocorrect = !autocorrect;
            view.setTextColor(autocorrect ? ACTIVE : TEXT);
        } else if ("MIC".equals(key)) {
            startVoice(view);
        } else if ("SPACE".equals(key)) {
            finishWord(input);
            input.commitText(" ", 1);
        } else if ("↵".equals(key)) {
            finishWord(input);
            input.sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN,
                    KeyEvent.KEYCODE_ENTER));
            input.sendKeyEvent(new KeyEvent(KeyEvent.ACTION_UP,
                    KeyEvent.KEYCODE_ENTER));
        } else if ("ESC".equals(key)) {
            send(input, KeyEvent.KEYCODE_ESCAPE, 0);
        } else if ("TAB".equals(key)) {
            send(input, KeyEvent.KEYCODE_TAB, 0);
        } else if ("ALT".equals(key)) {
            send(input, KeyEvent.KEYCODE_ALT_LEFT, 0);
        } else if ("←".equals(key)) {
            send(input, KeyEvent.KEYCODE_DPAD_LEFT, 0);
        } else if ("→".equals(key)) {
            send(input, KeyEvent.KEYCODE_DPAD_RIGHT, 0);
        } else if ("↑".equals(key)) {
            send(input, KeyEvent.KEYCODE_DPAD_UP, 0);
        } else if ("↓".equals(key)) {
            send(input, KeyEvent.KEYCODE_DPAD_DOWN, 0);
        } else {
            String text = shift ? key.toUpperCase(Locale.ROOT) : key;
            if (ctrl && text.length() == 1) {
                int code = KeyEvent.keyCodeFromString(
                        "KEYCODE_" + text.toUpperCase(Locale.ROOT));
                send(input, code, KeyEvent.META_CTRL_ON);
                ctrl = false;
                refreshModifier("CTRL", false);
            } else {
                input.commitText(text, 1);
                if (text.matches("[A-Za-z]")) {
                    word.append(text);
                    requestSuggestion();
                } else {
                    word.setLength(0);
                    suggestion = null;
                }
                if (shift) {
                    shift = false;
                    refreshModifier("⇧", false);
                    refreshLetterCase();
                }
            }
        }
    }

    private void refreshLetterCase() {
        if (keyboard == null) return;
        for (int rowIndex = 0; rowIndex < keyboard.getChildCount(); rowIndex++) {
            View rowView = keyboard.getChildAt(rowIndex);
            if (!(rowView instanceof LinearLayout)) continue;
            LinearLayout row = (LinearLayout) rowView;
            for (int keyIndex = 0; keyIndex < row.getChildCount(); keyIndex++) {
                View keyView = row.getChildAt(keyIndex);
                if (!(keyView instanceof TextView)) continue;
                TextView key = (TextView) keyView;
                String label = (String) key.getTag();
                if (label != null && label.length() == 1 &&
                        Character.isLetter(label.charAt(0))) {
                    key.setText(shift
                            ? label.toUpperCase(Locale.ROOT)
                            : label.toLowerCase(Locale.ROOT));
                }
            }
        }
    }

    private void deleteBackward() {
        InputConnection input = getCurrentInputConnection();
        if (input == null) return;
        if (lastCorrection != null) {
            input.deleteSurroundingText(lastCorrection.length() + 1, 0);
            input.commitText(lastOriginal, 1);
            lastCorrection = null;
            lastOriginal = null;
        } else {
            input.deleteSurroundingText(1, 0);
            if (word.length() > 0) word.setLength(word.length() - 1);
        }
    }

    private void finishWord(InputConnection input) {
        String original = word.toString();
        if (autocorrect && suggestion != null && original.length() > 1 &&
                !suggestion.equalsIgnoreCase(original)) {
            input.deleteSurroundingText(original.length(), 0);
            input.commitText(suggestion, 1);
            lastOriginal = original;
            lastCorrection = suggestion;
        } else {
            lastOriginal = null;
            lastCorrection = null;
        }
        word.setLength(0);
        suggestion = null;
    }

    private void requestSuggestion() {
        if (spelling == null || word.length() < 2) return;
        spelling.getSuggestions(new TextInfo(word.toString()), 5);
    }

    @Override public void onGetSuggestions(SuggestionsInfo[] results) {
        if (results == null || results.length == 0) return;
        SuggestionsInfo info = results[0];
        if (info.getSuggestionsCount() > 0) suggestion = info.getSuggestionAt(0);
    }

    @Override public void onGetSentenceSuggestions(
            SentenceSuggestionsInfo[] results) {
    }

    private void startVoice(final TextView mic) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return;
        if (speech == null) {
            speech = SpeechRecognizer.createSpeechRecognizer(this);
            speech.setRecognitionListener(new RecognitionListener() {
                @Override public void onReadyForSpeech(Bundle b) {
                    mic.setTextColor(ACTIVE);
                }
                @Override public void onBeginningOfSpeech() {}
                @Override public void onRmsChanged(float rms) {}
                @Override public void onBufferReceived(byte[] b) {}
                @Override public void onEndOfSpeech() {}
                @Override public void onError(int error) {
                    mic.setTextColor(TEXT);
                }
                @Override public void onResults(Bundle bundle) {
                    writeVoice(bundle, false);
                    mic.setTextColor(TEXT);
                }
                @Override public void onPartialResults(Bundle bundle) {
                    writeVoice(bundle, true);
                }
                @Override public void onEvent(int type, Bundle bundle) {}
            });
        }
        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault());
        speech.startListening(intent);
    }

    private void writeVoice(Bundle bundle, boolean partial) {
        ArrayList<String> text =
                bundle.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        InputConnection input = getCurrentInputConnection();
        if (input == null || text == null || text.isEmpty()) return;
        if (partial) input.setComposingText(text.get(0), 1);
        else {
            input.finishComposingText();
            input.commitText(text.get(0) + " ", 1);
        }
    }

    private void send(InputConnection input, int keyCode, int meta) {
        long now = android.os.SystemClock.uptimeMillis();
        input.sendKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_DOWN,
                keyCode, 0, meta));
        input.sendKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_UP,
                keyCode, 0, meta));
    }

    private void refreshModifier(String label, boolean active) {
        if (keyboard == null) return;
        for (int i = 0; i < keyboard.getChildCount(); i++) {
            LinearLayout row = (LinearLayout) keyboard.getChildAt(i);
            for (int j = 0; j < row.getChildCount(); j++) {
                TextView key = (TextView) row.getChildAt(j);
                if (label.equals(key.getTag())) {
                    key.setTextColor(active ? ACTIVE : TEXT);
                    key.getPaint().setFakeBoldText(active);
                    key.invalidate();
                }
            }
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override public void onDestroy() {
        repeatHandler.removeCallbacks(backspaceRepeat);
        if (spelling != null) spelling.close();
        if (speech != null) speech.destroy();
        super.onDestroy();
    }
}
