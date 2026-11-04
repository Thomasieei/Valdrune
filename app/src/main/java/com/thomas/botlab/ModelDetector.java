package com.thomas.botlab;

import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtSession;
import android.content.Context;
import android.graphics.RectF;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Reconnaissance d'objets (YOLO11n entraîné sur le dataset Albion) — tourne dans son propre fil. */
public class ModelDetector implements Runnable {
    public static final int ENEMY = 0, RESOURCE = 1, PLAYER = 2;

    public static class Obj {
        public final RectF box; public final String name; public final float conf; public final int kind;
        Obj(RectF b, String n, float c, int k) { box = b; name = n; conf = c; kind = k; }
    }

    public volatile List<Obj> latest = new ArrayList<>();
    public volatile long latestTime;
    public volatile int inferMs;
    public final String[] names;
    private final int[] kinds;
    private final OrtEnvironment env;
    private final OrtSession sess;
    private final String inName;
    private static final int S = 416;
    private final float[] buf = new float[3 * S * S];
    private volatile boolean running = true;
    private long lastFrame;

    private ModelDetector(OrtEnvironment env, OrtSession sess, String[] names) {
        this.env = env; this.sess = sess; this.names = names;
        this.inName = sess.getInputNames().iterator().next();
        kinds = new int[names.length];
        for (int i = 0; i < names.length; i++) kinds[i] = kindOf(names[i]);
    }

    static int kindOf(String n) {
        String s = n.toLowerCase();
        String[] res = {"tree", "wood", "log", "ore", "rock", "stone", "fiber", "fibre", "cotton", "flax", "hemp", "hide",
                "plant", "resource", "gather", "farm", "node", "bush", "herb", "skin"};
        for (String r : res) if (s.contains(r)) return RESOURCE;
        if (s.contains("player") || s.contains("self")) return PLAYER;
        return ENEMY;
    }

    public static ModelDetector load(Context c) {
        try {
            byte[] model = readAll(c.getAssets().open("model.onnx"));
            ArrayList<String> n = new ArrayList<>();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(c.getAssets().open("classes.txt"), "UTF-8"))) {
                String l; while ((l = r.readLine()) != null) if (!l.trim().isEmpty()) n.add(l.trim());
            }
            OrtEnvironment env = OrtEnvironment.getEnvironment();
            OrtSession.SessionOptions o = new OrtSession.SessionOptions();
            o.setIntraOpNumThreads(4);
            OrtSession s = env.createSession(model, o);
            ModelDetector d = new ModelDetector(env, s, n.toArray(new String[0]));
            BotLog.log("Modèle de reconnaissance chargé : " + n.size() + " classes " + n);
            return d;
        } catch (java.io.FileNotFoundException e) {
            return null;
        } catch (Throwable e) {
            BotLog.log("Modèle illisible : " + e);
            return null;
        }
    }

    private static byte[] readAll(InputStream in) throws java.io.IOException {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        byte[] b = new byte[1 << 16]; int k;
        while ((k = in.read(b)) > 0) o.write(b, 0, k);
        in.close();
        return o.toByteArray();
    }

    public void start() { new Thread(this, "model").start(); }
    public void stop() { running = false; }

    @Override public void run() {
        while (running) {
            CaptureService cs = CaptureService.instance;
            Frame f = cs == null ? null : cs.latest;
            if (f == null || f.time == lastFrame) { sleep(40); continue; }
            lastFrame = f.time;
            try {
                long t = System.currentTimeMillis();
                latest = detect(f);
                latestTime = f.time;
                inferMs = (int) (System.currentTimeMillis() - t);
            } catch (Throwable e) {
                BotLog.log("Erreur modèle : " + e);
                sleep(1000);
            }
        }
    }

    private static void sleep(long ms) { try { Thread.sleep(ms); } catch (InterruptedException ignored) { } }

    private List<Obj> detect(Frame f) throws Exception {
        float s = Math.min(S / (float) f.w, S / (float) f.h);
        int nw = Math.round(f.w * s), nh = Math.round(f.h * s), px = (S - nw) / 2, py = (S - nh) / 2;
        float pad = 114 / 255f; int plane = S * S;
        java.util.Arrays.fill(buf, pad);
        for (int y = 0; y < nh; y++) {
            int sy = Math.min(f.h - 1, (int) (y / s));
            for (int x = 0; x < nw; x++) {
                int c = f.rgb(Math.min(f.w - 1, (int) (x / s)), sy);
                int i = (y + py) * S + x + px;
                buf[i] = ((c >> 16) & 255) / 255f;
                buf[plane + i] = ((c >> 8) & 255) / 255f;
                buf[2 * plane + i] = (c & 255) / 255f;
            }
        }
        List<Obj> out = new ArrayList<>();
        try (OnnxTensor t = OnnxTensor.createTensor(env, FloatBuffer.wrap(buf), new long[]{1, 3, S, S});
             OrtSession.Result r = sess.run(Collections.singletonMap(inName, t))) {
            float[][] o = ((float[][][]) r.get(0).getValue())[0];   // [4+nc][N]
            int nc = o.length - 4, n = o[0].length;
            ArrayList<float[]> cand = new ArrayList<>();
            for (int a = 0; a < n; a++) {
                int bc = -1; float bs = 0.35f;
                for (int k = 0; k < nc; k++) if (o[4 + k][a] > bs) { bs = o[4 + k][a]; bc = k; }
                if (bc < 0) continue;
                float cx = (o[0][a] - px) / s, cy = (o[1][a] - py) / s, w = o[2][a] / s, h = o[3][a] / s;
                cand.add(new float[]{cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, bs, bc});
            }
            cand.sort((p, q) -> Float.compare(q[4], p[4]));
            ArrayList<float[]> keep = new ArrayList<>();
            for (float[] c : cand) {
                boolean ok = true;
                for (float[] k : keep) if (k[5] == c[5] && iou(k, c) > 0.45f) { ok = false; break; }
                if (ok) keep.add(c);
                if (keep.size() >= 40) break;
            }
            for (float[] k : keep) {
                int cls = (int) k[5];
                String name = cls < names.length ? names[cls] : ("classe " + cls);
                out.add(new Obj(new RectF(k[0], k[1], k[2], k[3]), name, k[4], cls < kinds.length ? kinds[cls] : ENEMY));
            }
        }
        return out;
    }

    private static float iou(float[] a, float[] b) {
        float ix = Math.max(0, Math.min(a[2], b[2]) - Math.max(a[0], b[0]));
        float iy = Math.max(0, Math.min(a[3], b[3]) - Math.max(a[1], b[1]));
        float in = ix * iy, u = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - in;
        return u <= 0 ? 0 : in / u;
    }
}
