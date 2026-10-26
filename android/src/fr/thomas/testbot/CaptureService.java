package fr.thomas.testbot;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.PixelFormat;
import android.graphics.Point;
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
import java.nio.ByteOrder;
import java.nio.IntBuffer;

/** Regarde l'écran : copie réduite de l'écran (≈640 px) mise à jour plusieurs fois par seconde. */
public class CaptureService extends Service {
    static final String EX_CODE = "code", EX_DATA = "data";
    static volatile CaptureService inst;
    static volatile int[] frame;
    static volatile int fw, fh;
    static volatile long frameTime;
    /** Images analysées par seconde (pour l'affichage). */
    static volatile int fps;
    private static int fpsN; private static long fpsT;

    private MediaProjection mp;
    private VirtualDisplay vd;
    private ImageReader ir;
    private HandlerThread ht;
    private Handler h;
    private int curW, curH;
    private volatile boolean resizing;
    private int[] tmp;

    @Override public IBinder onBind(Intent intent) { return null; }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Notification n = buildNotification();
        if (Build.VERSION.SDK_INT >= 29) startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION);
        else startForeground(1, n);
        if (intent == null || mp != null) return START_NOT_STICKY;
        int code = intent.getIntExtra(EX_CODE, 0);
        Intent data = intent.getParcelableExtra(EX_DATA);
        MediaProjectionManager m = (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE);
        try { mp = m.getMediaProjection(code, data); } catch (Exception e) { mp = null; }
        if (mp == null) { stopSelf(); return START_NOT_STICKY; }
        ht = new HandlerThread("testbot-capture");
        ht.start();
        h = new Handler(ht.getLooper());
        mp.registerCallback(new MediaProjection.Callback() {
            @Override public void onStop() { shutdown(); }
        }, h);
        h.post(this::setup);
        inst = this;
        return START_NOT_STICKY;
    }

    private Notification buildNotification() {
        String ch = "testbot";
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(ch) == null) {
            NotificationChannel c = new NotificationChannel(ch, "TestBot", NotificationManager.IMPORTANCE_LOW);
            c.setDescription("Indique que TestBot regarde l'écran pendant un test");
            nm.createNotificationChannel(c);
        }
        PendingIntent pi = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class), PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, ch) : new Notification.Builder(this);
        return b.setContentTitle("TestBot regarde l'écran")
                .setContentText("Vue active pour tester tes jeux. Touche pour ouvrir TestBot.")
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentIntent(pi)
                .setOngoing(true)
                .build();
    }

    private Point screen() {
        DisplayManager dm = (DisplayManager) getSystemService(DISPLAY_SERVICE);
        Display d = dm.getDisplay(Display.DEFAULT_DISPLAY);
        Point p = new Point();
        d.getRealSize(p);
        return p;
    }

    private int dpi() {
        DisplayManager dm = (DisplayManager) getSystemService(DISPLAY_SERVICE);
        DisplayMetrics m = new DisplayMetrics();
        dm.getDisplay(Display.DEFAULT_DISPLAY).getRealMetrics(m);
        return m.densityDpi;
    }

    private void setup() {
        if (mp == null) return;
        Point s = screen();
        curW = s.x; curH = s.y;
        float k = 640f / Math.max(s.x, s.y);
        final int w = Math.max(2, Math.round(s.x * k)), hh = Math.max(2, Math.round(s.y * k));
        ImageReader old = ir;
        ir = ImageReader.newInstance(w, hh, PixelFormat.RGBA_8888, 3);
        ir.setOnImageAvailableListener(r -> {
            Image img = null;
            try {
                img = r.acquireLatestImage();
                if (img == null) return;
                long t = SystemClock.uptimeMillis();
                if (t - frameTime < 30) return; // jusqu'à ~30 images/s
                Image.Plane pl = img.getPlanes()[0];
                ByteBuffer buf = pl.getBuffer();
                int ps = pl.getPixelStride(), rs = pl.getRowStride(), iw = img.getWidth(), ih = img.getHeight();
                int[] out = new int[iw * ih];
                if (ps == 4 && rs % 4 == 0) {
                    // Rapide : lecture directe en entiers (RGBA en mémoire = 0xAABBGGRR), puis R et B échangés
                    buf.rewind();
                    IntBuffer ib = buf.order(ByteOrder.LITTLE_ENDIAN).asIntBuffer();
                    int rowInts = rs / 4, n = Math.min(ib.remaining(), rowInts * ih);
                    if (tmp == null || tmp.length < n) tmp = new int[n];
                    ib.get(tmp, 0, n);
                    for (int y = 0; y < ih; y++) {
                        int base = y * rowInts, o = y * iw;
                        if (base + iw > n) break;
                        for (int x = 0; x < iw; x++) {
                            int c = tmp[base + x];
                            out[o + x] = 0xFF000000 | ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF);
                        }
                    }
                } else {
                byte[] row = new byte[rs];
                for (int y = 0; y < ih; y++) {
                    buf.position(y * rs);
                    int len = Math.min(rs, buf.remaining());
                    buf.get(row, 0, len);
                    int o = y * iw;
                    for (int x = 0; x < iw; x++) {
                        int i = x * ps;
                        if (i + 2 >= len) break;
                        out[o + x] = 0xFF000000 | ((row[i] & 255) << 16) | ((row[i + 1] & 255) << 8) | (row[i + 2] & 255);
                    }
                }
                }
                fw = iw; fh = ih; frame = out; frameTime = t;
                fpsN++;
                if (t - fpsT >= 1000) { fps = fpsN; fpsN = 0; fpsT = t; }
            } catch (Exception ignored) {
            } finally {
                if (img != null) img.close();
            }
        }, h);
        try {
            if (vd == null) {
                vd = mp.createVirtualDisplay("testbot", w, hh, dpi(), DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, ir.getSurface(), null, h);
            } else {
                vd.resize(w, hh, dpi());
                vd.setSurface(ir.getSurface());
            }
        } catch (Exception e) {
            shutdown();
            return;
        }
        if (old != null) old.close();
        resizing = false;
    }

    /** Appelé par le bot : si l'écran a tourné, on adapte la vue. */
    static void checkSize() {
        CaptureService c = inst;
        if (c == null || c.h == null || c.resizing) return;
        Point s = c.screen();
        if (s.x != c.curW || s.y != c.curH) { c.resizing = true; c.h.post(c::setup); }
    }

    static boolean running() { return inst != null; }

    private void shutdown() {
        try { if (vd != null) vd.release(); } catch (Exception ignored) {}
        try { if (ir != null) ir.close(); } catch (Exception ignored) {}
        try { if (mp != null) mp.stop(); } catch (Exception ignored) {}
        vd = null; ir = null; mp = null; inst = null; frame = null;
        stopForeground(true);
        stopSelf();
    }

    @Override
    public void onDestroy() {
        if (mp != null) shutdown();
        if (ht != null) ht.quitSafely();
        inst = null;
        super.onDestroy();
    }
}
