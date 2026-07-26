package dev.transmutation.launcher;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.LinearGradient;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.graphics.RectF;
import android.graphics.Rect;
import android.os.SystemClock;
import android.view.View;

import java.lang.reflect.Method;
import java.io.InputStream;
import java.util.Calendar;
import java.util.TimeZone;

public final class InstrumentClockView extends View {
    private static final double B1937_HZ = 641.928;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Calendar utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
    private Bitmap physicalFace;
    private final boolean lockOverlay;
    private final Runnable tick = new Runnable() {
        @Override public void run() {
            invalidate();
            postDelayed(this, 1000L - (SystemClock.uptimeMillis() % 1000L));
        }
    };
    private boolean gnssDisciplined;

    public InstrumentClockView(Context context) {
        this(context, false);
    }

    public InstrumentClockView(Context context, boolean lockOverlay) {
        super(context);
        this.lockOverlay = lockOverlay;
        paint.setTypeface(android.graphics.Typeface.createFromAsset(
                context.getAssets(), "PxPlus_IBM_VGA8.ttf"));
        setBackgroundColor(lockOverlay ? Color.TRANSPARENT : Color.BLACK);
        try (InputStream input = context.getAssets().open("achs1-face.png")) {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inSampleSize = 2;
            physicalFace = BitmapFactory.decodeStream(input, null, options);
        } catch (Exception ignored) {
        }
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        tick.run();
    }

    @Override protected void onDetachedFromWindow() {
        removeCallbacks(tick);
        super.onDetachedFromWindow();
    }

    private long disciplinedMillis() {
        try {
            Method source = SystemClock.class.getMethod("currentGnssTimeClock");
            Object clock = source.invoke(null);
            Method millis = clock.getClass().getMethod("millis");
            gnssDisciplined = true;
            return ((Long) millis.invoke(clock)).longValue();
        } catch (Exception ignored) {
            gnssDisciplined = false;
            return System.currentTimeMillis();
        }
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        long now = disciplinedMillis();
        utc.setTimeInMillis(now);
        float w = getWidth(), h = getHeight();
        float r = Math.min(w, h) * (lockOverlay ? .27f : .31f);
        float cx = w / 2f, cy = h * (lockOverlay ? .39f : .41f);
        paint.setStyle(Paint.Style.FILL);
        paint.setShader(null);
        if (physicalFace != null) {
            int crop = Math.min(physicalFace.getWidth(),
                    Math.round(physicalFace.getHeight() * .82f));
            int left = (physicalFace.getWidth() - crop) / 2;
            int top = (physicalFace.getHeight() - crop) / 2;
            canvas.save();
            Path circularCase = new Path();
            circularCase.addCircle(cx, cy, r*1.205f, Path.Direction.CW);
            canvas.clipPath(circularCase);
            canvas.drawBitmap(physicalFace,
                    new Rect(left, top, left + crop, top + crop),
                    new RectF(cx-r*1.27f, cy-r*1.27f,
                            cx+r*1.27f, cy+r*1.27f), paint);
            canvas.restore();
        }
        paint.setTextAlign(Paint.Align.CENTER);

        float sec = utc.get(Calendar.SECOND);
        float min = utc.get(Calendar.MINUTE) + sec / 60f;
        float hour = utc.get(Calendar.HOUR) + min / 60f;
        hand(canvas, cx, cy, r * .48f, hour * 30 - 90, r * .045f,
                Color.rgb(202, 212, 169));
        hand(canvas, cx, cy, r * .72f, min * 6 - 90, r * .032f,
                Color.rgb(202, 212, 169));
        hand(canvas, cx, cy, r * .82f, sec * 6 - 90, r * .010f,
                Color.rgb(140, 210, 145));
        paint.setStyle(Paint.Style.FILL);
        canvas.drawCircle(cx, cy, r * .055f, paint);

        long pulseCount = (long) Math.floor((now / 1000.0) * B1937_HZ);
        double phase = ((now / 1000.0) * B1937_HZ) % 1.0;
        float pulseAngle = (float)(phase * 360.0 - 90.0);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(r * .009f);
        paint.setColor(Color.rgb(18, 48, 25));
        float ringCy = cy - r*.062f;
        RectF ring = new RectF(cx-r*1.205f, ringCy-r*1.205f,
                cx+r*1.205f, ringCy+r*1.205f);
        canvas.drawArc(ring, 0, 360, false, paint);
        paint.setStrokeWidth(r * .015f);
        paint.setColor(Color.rgb(82, 190, 103));
        paint.setShadowLayer(r*.026f, 0, 0, Color.rgb(70, 255, 105));
        canvas.drawArc(ring, -90,
                (utc.get(Calendar.SECOND) + 1) * 6f, false, paint);
        paint.clearShadowLayer();

        // Separate telemetry plate: never compete with the dial or hands.
        paint.setStyle(Paint.Style.FILL);
        float plateTop = cy + r * 1.34f;
        paint.setColor(Color.rgb(3, 8, 4));
        canvas.drawRoundRect(new RectF(cx-r*1.22f, plateTop,
                cx+r*1.22f, plateTop+r*.54f), r*.035f, r*.035f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(r*.008f);
        paint.setColor(Color.rgb(50, 108, 59));
        canvas.drawRoundRect(new RectF(cx-r*1.22f, plateTop,
                cx+r*1.22f, plateTop+r*.54f), r*.035f, r*.035f, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setTextSize(r * .105f);
        paint.setColor(Color.rgb(167, 255, 177));
        canvas.drawText(gnssDisciplined ? "GNSS DISCIPLINED" : "GNSS ACQUIRING",
                cx, plateTop + r*.15f, paint);
        paint.setTextSize(r * .086f);
        canvas.drawText("PSR B1937+21  ·  641.928 Hz", cx,
                plateTop + r*.32f, paint);
        canvas.drawText("PULSE " + Long.toUnsignedString(pulseCount), cx,
                plateTop + r*.47f, paint);
    }

    private void hand(Canvas canvas, float cx, float cy, float length,
                      float degrees, float width, int color) {
        double a = Math.toRadians(degrees);
        float ux = (float)Math.cos(a), uy = (float)Math.sin(a);
        float px = -uy, py = ux;
        float tail = width * 1.2f;
        Path shape = new Path();
        shape.moveTo(cx - ux*tail + px*width*.44f,
                cy - uy*tail + py*width*.44f);
        shape.lineTo(cx + ux*length*.78f + px*width*.32f,
                cy + uy*length*.78f + py*width*.32f);
        shape.lineTo(cx + ux*length, cy + uy*length);
        shape.lineTo(cx + ux*length*.78f - px*width*.32f,
                cy + uy*length*.78f - py*width*.32f);
        shape.lineTo(cx - ux*tail - px*width*.44f,
                cy - uy*tail - py*width*.44f);
        shape.close();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(170, 0, 0, 0));
        canvas.save();
        canvas.translate(width*.35f, width*.55f);
        canvas.drawPath(shape, paint);
        canvas.restore();
        paint.setShader(new LinearGradient(cx- px*width, cy-py*width,
                cx+px*width, cy+py*width,
                Color.rgb(238, 235, 194), color, Shader.TileMode.CLAMP));
        paint.setShadowLayer(width*1.8f, 0, 0, Color.rgb(151, 255, 151));
        canvas.drawPath(shape, paint);
        paint.clearShadowLayer();
        paint.setShader(null);
    }
}
