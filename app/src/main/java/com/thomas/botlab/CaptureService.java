package com.thomas.botlab;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.PixelFormat;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.Image;
import android.media.ImageReader;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.SystemClock;
import android.util.DisplayMetrics;
import android.view.Display;
import java.nio.ByteBuffer;

/** Capture d'écran continue (MediaProjection), réduite à ~960 px de large pour la vision. */
public class CaptureService extends Service {
    public static volatile CaptureService instance;
    public volatile Frame latest;

    private MediaProjection projection;
    private VirtualDisplay vd;
    private ImageReader reader;
    private HandlerThread thread;
    private Handler handler;
    private int screenW, screenH, capW, capH, dpi;
    private long lastCopy;

    @Override public IBinder onBind(Intent i) { return null; }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        startAsForeground();
        if (projection != null || intent == null) return START_NOT_STICKY;
        int code = intent.getIntExtra("code", 0);
        Intent data = intent.getParcelableExtra("data");
        if (data == null) { stopSelf(); return START_NOT_STICKY; }
        thread = new HandlerThread("capture");
        thread.start();
        handler = new Handler(thread.getLooper());
        MediaProjectionManager mpm = (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE);
        try {
            projection = mpm.getMediaProjection(code, data);
        } catch (Exception e) {
            BotLog.log("Capture refusée : " + e);
            stopSelf(); return START_NOT_STICKY;
        }
        if (projection == null) { stopSelf(); return START_NOT_STICKY; }
        projection.registerCallback(new MediaProjection.Callback() {
            @Override public void onStop() { handler.post(() -> stopSelf()); }
        }, handler);
        setupDisplay();
        instance = this;
        BotLog.log("Capture d'écran démarrée (" + screenW + "x" + screenH + " → " + capW + "x" + capH + ")");
        handler.postDelayed(rotationCheck, 800);
        return START_NOT_STICKY;
    }

    private void startAsForeground() {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel("bot", "Albion Bot Lab", NotificationManager.IMPORTANCE_LOW));
        PendingIntent pi = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        Notification n = new Notification.Builder(this, "bot")
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("Albion Bot Lab — capture active")
                .setContentText("Le bot voit l'écran. Touchez pour ouvrir.")
                .setContentIntent(pi).setOngoing(true).build();
        if (Build.VERSION.SDK_INT >= 29) startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION);
        else startForeground(1, n);
    }

    private void measure() {
        Display d = getSystemService(DisplayManager.class).getDisplay(Display.DEFAULT_DISPLAY);
        DisplayMetrics m = new DisplayMetrics();
        d.getRealMetrics(m);
        screenW = m.widthPixels; screenH = m.heightPixels; dpi = m.densityDpi;
    }

    private void setupDisplay() {
        measure();
        float s = Math.min(1f, 960f / Math.max(screenW, screenH));
        capW = Math.max(2, Math.round(screenW * s) & ~1);
        capH = Math.max(2, Math.round(screenH * s) & ~1);
        ImageReader old = reader;
        reader = ImageReader.newInstance(capW, capH, PixelFormat.RGBA_8888, 2);
        reader.setOnImageAvailableListener(this::onImage, handler);
        if (vd == null) {
            vd = projection.createVirtualDisplay("botlab", capW, capH, dpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, reader.getSurface(), null, handler);
        } else {
            vd.resize(capW, capH, dpi);
            vd.setSurface(reader.getSurface());
        }
        if (old != null) old.close();
    }

    private final Runnable rotationCheck = new Runnable() {
        @Override public void run() {
            if (projection == null) return;
            int ow = screenW, oh = screenH;
            measure();
            if (ow != screenW || oh != screenH) {
                setupDisplay();
                BotLog.log("Rotation détectée → capture " + capW + "x" + capH);
            }
            handler.postDelayed(this, 800);
        }
    };

    private void onImage(ImageReader r) {
        Image img = null;
        try {
            img = r.acquireLatestImage();
            if (img == null) return;
            long now = SystemClock.uptimeMillis();
            if (now - lastCopy < 90) return;
            lastCopy = now;
            if (img.getWidth() != capW || img.getHeight() != capH) return;
            Image.Plane p = img.getPlanes()[0];
            ByteBuffer buf = p.getBuffer();
            int rowStride = p.getRowStride();
            byte[] arr = new byte[buf.remaining()];
            buf.get(arr);
            latest = new Frame(arr, capW, capH, rowStride, screenW, screenH, now);
        } catch (Exception ignored) {
        } finally {
            if (img != null) img.close();
        }
    }

    public void stopAll() { stopSelf(); }

    @Override
    public void onDestroy() {
        instance = null;
        latest = null;
        try { if (vd != null) vd.release(); } catch (Exception ignored) { }
        try { if (reader != null) reader.close(); } catch (Exception ignored) { }
        try { if (projection != null) projection.stop(); } catch (Exception ignored) { }
        projection = null; vd = null;
        if (thread != null) thread.quitSafely();
        BotLog.log("Capture d'écran arrêtée");
        super.onDestroy();
    }
}
