package fr.thomas.artemis;

import android.accessibilityservice.AccessibilityService;
import android.graphics.Bitmap;
import android.graphics.ColorSpace;
import android.hardware.HardwareBuffer;
import android.util.Base64;
import android.view.Display;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Ce que l'agent « voit » : l'arbre d'accessibilité lu par le HierarchyDumper d'Artemis,
 * réduit à une liste numérotée et compacte (peu de tokens), plus une capture optionnelle.
 */
final class Screen {
    static final class El {
        int idx;
        String label = "";
        int l, t, r, b;
        boolean clickable, editable, scrollable;
        float cx() { return (l + r) / 2f; }
        float cy() { return (t + b) / 2f; }
    }

    final List<El> els = new ArrayList<>();
    String pkg = "";
    String text = "";
    String sig = "";
    int w, h;
    boolean keyboard;

    private static final ExecutorService SHOT = Executors.newSingleThreadExecutor();

    static Screen read(AgentService s) {
        Screen sc = new Screen();
        HierarchyDumper.DumpOptions o = new HierarchyDumper.DumpOptions();
        o.wantXml = false;
        o.wantElements = true;
        JSONObject d = HierarchyDumper.dump(s, o);
        sc.w = Math.max(1, d.optInt("width", 1080));
        sc.h = Math.max(1, d.optInt("height", 2400));
        sc.pkg = s.getCurrentPackageName();
        JSONArray a = d.optJSONArray("elements");
        StringBuilder sb = new StringBuilder();
        StringBuilder sig = new StringBuilder(sc.pkg);
        Set<String> seen = new HashSet<>();
        String me = s.getPackageName();
        int n = 0, skipped = 0;
        for (int i = 0; a != null && i < a.length(); i++) {
            JSONObject e = a.optJSONObject(i);
            if (e == null) continue;
            String wt = e.optString("window_type");
            if ("accessibility_overlay".equals(wt) || me.equals(e.optString("package"))) continue;
            if ("input_method".equals(wt)) { sc.keyboard = true; continue; }
            JSONObject pb = e.optJSONObject("parsed_bounds");
            if (pb == null) continue;
            El el = new El();
            el.l = pb.optInt("left"); el.t = pb.optInt("top"); el.r = pb.optInt("right"); el.b = pb.optInt("bottom");
            if (el.r - el.l < 4 || el.b - el.t < 4) continue;
            el.clickable = e.optBoolean("clickable") || e.optBoolean("long-clickable") || e.optBoolean("checkable");
            el.editable = e.optBoolean("editable");
            el.scrollable = e.optBoolean("scrollable");
            String txt = clean(e.optString("text")), desc = clean(e.optString("content-desc")),
                    hint = clean(e.optString("hint")), state = clean(e.optString("state_description"));
            String rid = e.optString("resource-id");
            if (rid.contains("/")) rid = rid.substring(rid.indexOf('/') + 1);
            el.label = !txt.isEmpty() ? txt : !desc.isEmpty() ? desc : !hint.isEmpty() ? hint : "";
            boolean interactive = el.clickable || el.editable || el.scrollable;
            if (el.label.isEmpty() && !interactive) continue;
            if (el.label.isEmpty()) el.label = rid.isEmpty() ? "" : "#" + rid;
            String key = el.label + "|" + (int) (el.cx() / 12) + "|" + (int) (el.cy() / 12);
            if (!seen.add(key)) continue;
            if (n >= 140) { skipped++; continue; }

            el.idx = n++;
            sc.els.add(el);
            String cls = e.optString("class");
            if (cls.contains(".")) cls = cls.substring(cls.lastIndexOf('.') + 1);
            sb.append('[').append(el.idx).append("] ").append(kind(cls, el));
            if (!el.label.isEmpty()) sb.append(" \"").append(cut(el.label, 90)).append('"');
            if (!desc.isEmpty() && !desc.equals(el.label)) sb.append(" (").append(cut(desc, 50)).append(')');
            sb.append(" @").append(norm(el.cx(), sc.w)).append(',').append(norm(el.cy(), sc.h));
            List<String> f = new ArrayList<>();
            if (el.editable) f.add(txt.isEmpty() ? "champ vide" : "champ");
            else if (el.clickable) f.add("clic");
            if (el.scrollable) f.add("défilable");
            if (e.optBoolean("checkable")) f.add(e.optBoolean("checked") ? "coché" : "non coché");
            if (e.optBoolean("selected")) f.add("sélectionné");
            if (e.optBoolean("focused") && el.editable) f.add("curseur ici");
            if (!e.optBoolean("enabled", true)) f.add("désactivé");
            if (!state.isEmpty()) f.add(cut(state, 30));
            if (e.optBoolean("password")) f.add("mot de passe");
            if (!f.isEmpty()) sb.append(" [").append(String.join(", ", f)).append(']');
            sb.append('\n');
            sig.append(el.label).append(el.l / 20).append(el.t / 20).append(';');
        }
        if (skipped > 0) sb.append("(… ").append(skipped).append(" autres éléments non listés, défile ou regarde la capture)\n");
        if (sc.keyboard) sb.append("(le clavier est ouvert)\n");
        if (n == 0) sb.append("(aucun élément lisible : écran de jeu, vidéo ou page dessinée — utilise la capture et toucher_xy)\n");
        sc.text = sb.toString();
        sc.sig = Integer.toHexString(sig.toString().hashCode());
        return sc;
    }

    El get(int idx) { return idx >= 0 && idx < els.size() ? els.get(idx) : null; }

    private static String kind(String cls, El el) {
        String c = cls.toLowerCase(Locale.ROOT);
        if (el.editable || c.contains("edittext")) return "Champ";
        if (c.contains("switch")) return "Interrupteur";
        if (c.contains("checkbox")) return "Case";
        if (c.contains("button")) return "Bouton";
        if (c.contains("image")) return el.clickable ? "Icône" : "Image";
        if (c.contains("tab")) return "Onglet";
        if (c.contains("recycler") || c.contains("listview") || c.contains("scroll")) return "Liste";
        if (c.contains("webview")) return "PageWeb";
        if (el.clickable) return "Zone";
        return "Texte";
    }

    static int norm(float v, int max) { return Math.round(Math.max(0, Math.min(1000, v * 1000f / max))); }

    private static String clean(String s) {
        if (s == null) return "";
        return s.replace('\n', ' ').replace('"', '\'').trim();
    }

    private static String cut(String s, int n) { return s.length() <= n ? s : s.substring(0, n) + "…"; }

    // ------------------------------------------------------------------ capture

    /** Capture d'écran (Android 11+), réduite à 720 px de large, en JPEG base64. Null si impossible. */
    static String shot(AccessibilityService s) {
        final AtomicReference<Bitmap> ref = new AtomicReference<>();
        for (int attempt = 0; attempt < 2 && ref.get() == null; attempt++) {
            final CountDownLatch latch = new CountDownLatch(1);
            try {
                s.takeScreenshot(Display.DEFAULT_DISPLAY, SHOT, new AccessibilityService.TakeScreenshotCallback() {
                    @Override public void onSuccess(AccessibilityService.ScreenshotResult r) {
                        HardwareBuffer hb = r.getHardwareBuffer();
                        try {
                            ColorSpace cs = r.getColorSpace();
                            Bitmap hw = Bitmap.wrapHardwareBuffer(hb, cs != null ? cs : ColorSpace.get(ColorSpace.Named.SRGB));
                            if (hw != null) { ref.set(hw.copy(Bitmap.Config.ARGB_8888, false)); hw.recycle(); }
                        } catch (Throwable ignored) {
                        } finally { hb.close(); latch.countDown(); }
                    }
                    @Override public void onFailure(int code) { latch.countDown(); }
                });
                latch.await(2500, TimeUnit.MILLISECONDS);
            } catch (Throwable ignored) {}
            if (ref.get() == null) try { Thread.sleep(400); } catch (InterruptedException ignored) {}
        }
        Bitmap b = ref.get();
        if (b == null) return null;
        try {
            int tw = Math.min(720, b.getWidth());
            int th = Math.round(b.getHeight() * (tw / (float) b.getWidth()));
            Bitmap sm = Bitmap.createScaledBitmap(b, tw, th, true);
            ByteArrayOutputStream os = new ByteArrayOutputStream();
            sm.compress(Bitmap.CompressFormat.JPEG, 70, os);
            if (sm != b) sm.recycle();
            return Base64.encodeToString(os.toByteArray(), Base64.NO_WRAP);
        } finally { b.recycle(); }
    }
}
