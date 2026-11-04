package com.thomas.botlab;

import android.graphics.RectF;
import java.util.ArrayList;
import java.util.List;

/** Vision du bot : barres de vie ennemies, vie du joueur, état des sorts. Tout en coordonnées image. */
public class Detector {

    public static class Det {
        public int x0, y0, x1, y1;
        Det(int y, int a, int b) { y0 = y1 = y; x0 = a; x1 = b; }
        public float cx() { return (x0 + x1) / 2f; }
        public float cy() { return (y0 + y1) / 2f; }
        public int w() { return x1 - x0 + 1; }
        public int h() { return y1 - y0 + 1; }
    }

    public static int dist(int c, int t) {
        return Math.abs(((c >> 16) & 255) - ((t >> 16) & 255))
             + Math.abs(((c >> 8) & 255) - ((t >> 8) & 255))
             + Math.abs((c & 255) - (t & 255));
    }

    static int chroma(int c) {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return Math.max(r, Math.max(g, b)) - Math.min(r, Math.min(g, b));
    }

    public static volatile int lastMatchCount;

    /** Rouge « au sens large » : teinte autour de 0°, saturée, assez lumineuse (marche sans calibrage). */
    static boolean redHue(int c, int tol) {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        int max = Math.max(r, Math.max(g, b)), min = Math.min(r, Math.min(g, b));
        if (max != r || max < 90) return false;
        int ch = max - min;
        if (ch < max * 0.45f) return false;
        float hue = 60f * (g - b) / ch;
        return Math.abs(hue) < 16 + tol / 7f;
    }

    public static boolean matchEnemy(int px, Config c) {
        if (c.enemyColorSampled) return chroma(px) > 50 && dist(px, c.enemyColor) < c.colorTol * 2;
        return redHue(px, c.colorTol);
    }

    /** Barres horizontales fines de la couleur ennemie = un monstre ou un joueur hostile. */
    public static List<Det> findEnemies(Frame f, Config c, List<RectF> excl) {
        int w = f.w, h = f.h;
        int minRun = Math.max(6, (int) (w * 0.010f));
        int maxW = (int) (w * 0.22f);
        int maxH = Math.max(4, (int) (h * 0.035f));
        int yStart = (int) (h * c.topExcludePct / 100f), yEnd = (int) (h * 0.97f);
        ArrayList<int[]> runs = new ArrayList<>();
        int matched = 0;
        outer:
        for (int y = yStart; y < yEnd; y++) {
            int start = -1, last = -1, miss = 0;
            for (int x = 0; x <= w; x++) {
                boolean m = false;
                if (x < w) { m = matchEnemy(f.rgb(x, y), c); if (m) matched++; }
                if (m) { if (start < 0) start = x; last = x; miss = 0; }
                else if (start >= 0) {
                    miss++;
                    if (miss > 2 || x == w) {
                        if (last - start + 1 >= minRun) {
                            runs.add(new int[]{y, start, last});
                            if (runs.size() > 4000) break outer;
                        }
                        start = -1; miss = 0;
                    }
                }
            }
        }
        lastMatchCount = matched;
        ArrayList<Det> boxes = new ArrayList<>();
        for (int[] r : runs) {
            Det hit = null;
            for (int i = boxes.size() - 1; i >= 0; i--) {
                Det d = boxes.get(i);
                if (r[0] - d.y1 > 2) continue;
                int ov = Math.min(r[2], d.x1) - Math.max(r[1], d.x0);
                if (ov > 0.5f * Math.min(r[2] - r[1], d.x1 - d.x0)) { hit = d; break; }
            }
            if (hit == null) boxes.add(new Det(r[0], r[1], r[2]));
            else { hit.y1 = r[0]; hit.x0 = Math.min(hit.x0, r[1]); hit.x1 = Math.max(hit.x1, r[2]); }
        }
        ArrayList<Det> out = new ArrayList<>();
        for (Det d : boxes) {
            if (d.h() > maxH || d.w() > maxW || d.w() < d.h() * 3) continue;
            boolean bad = false;
            for (RectF e : excl) if (RectF.intersects(e, new RectF(d.x0, d.y0, d.x1, d.y1))) { bad = true; break; }
            if (bad) continue;
            boolean dup = false;
            for (Det o : out) if (Math.abs(o.cx() - d.cx()) < d.w() && Math.abs(o.cy() - d.cy()) < maxH * 2) { dup = true; break; }
            if (!dup) out.add(d);
        }
        return out;
    }

    /** % de vie du joueur, -1 si non calibré. */
    public static int readHp(Frame f, Config c) {
        if (c.hpLx < 0 || c.hpRx < 0 || c.hpColor == 0) return -1;
        float s = f.scale;
        float x0 = c.hpLx * s, y0 = c.hpLy * s, x1 = c.hpRx * s, y1 = c.hpRy * s;
        int n = 48, hits = 0;
        for (int i = 0; i < n; i++) {
            float t = (i + 0.5f) / n;
            int x = Math.round(x0 + (x1 - x0) * t), y = Math.round(y0 + (y1 - y0) * t);
            if (dist(f.rgb(x, y), c.hpColor) < 110 || dist(f.rgb(x, y - 1), c.hpColor) < 110
                    || dist(f.rgb(x, y + 1), c.hpColor) < 110) hits++;
        }
        return hits * 100 / n;
    }

    /** Un sort est prêt si son bouton est aussi lumineux qu'au calibrage (les recharges l'assombrissent). */
    public static boolean[] spellsReady(Frame f, Config c) {
        int n = c.spellX.length;
        boolean[] r = new boolean[n];
        int rad = Math.max(3, (int) (f.h * 0.012f));
        for (int i = 0; i < n; i++) {
            float ref = i < c.spellLum.length ? c.spellLum[i] : 0;
            if (ref <= 1) { r[i] = true; continue; }
            float l = f.lum(Math.round(c.spellX[i] * f.scale), Math.round(c.spellY[i] * f.scale), rad);
            r[i] = l >= ref * 0.78f;
        }
        return r;
    }

    public static int patchRadius(Frame f) { return Math.max(3, (int) (f.h * 0.012f)); }

    /** Moyenne 3x3 autour d'un point. */
    public static int avgColor(Frame f, int cx, int cy) {
        int r = 0, g = 0, b = 0, n = 0;
        for (int y = cy - 1; y <= cy + 1; y++) for (int x = cx - 1; x <= cx + 1; x++) {
            int p = f.rgb(x, y); r += (p >> 16) & 255; g += (p >> 8) & 255; b += p & 255; n++;
        }
        return ((r / n) << 16) | ((g / n) << 8) | (b / n);
    }

    /**
     * Cherche une barre de vie au-dessus d'un monstre touché : le plus long segment horizontal
     * de couleur vive et uniforme, dans une zone au-dessus du point. Renvoie {couleur, x0, x1, y} ou null.
     */
    public static int[] findBarNear(Frame f, int tx, int ty, List<RectF> excl) {
        int xa = Math.max(0, tx - (int) (f.w * 0.08f)), xb = Math.min(f.w - 1, tx + (int) (f.w * 0.08f));
        int ya = Math.max(0, ty - (int) (f.h * 0.25f)), yb = Math.min(f.h - 1, ty + (int) (f.h * 0.04f));
        int minRun = Math.max(5, (int) (f.w * 0.008f));
        int bestLen = 0, bestY = -1, bestX0 = 0, bestX1 = 0;
        for (int y = ya; y <= yb; y++) {
            int start = -1, ref = 0;
            for (int x = xa; x <= xb + 1; x++) {
                int p = x <= xb ? f.rgb(x, y) : 0;
                boolean ok = x <= xb && chroma(p) > 60 && Math.max((p >> 16) & 255, Math.max((p >> 8) & 255, p & 255)) > 80;
                if (ok && start >= 0 && dist(p, ref) > 70) ok = false;
                if (ok) { if (start < 0) { start = x; ref = p; } }
                else if (start >= 0) {
                    int len = x - start;
                    // une barre est fine : vérifier qu'elle ne continue pas sur 10 lignes (sinon c'est un objet coloré)
                    if (len >= minRun && len > bestLen && !inside(excl, (start + x - 1) / 2f, y) && thin(f, start, x - 1, y, ref)) { bestLen = len; bestY = y; bestX0 = start; bestX1 = x - 1; }
                    start = -1;
                    if (ok) { start = x; ref = p; }
                }
            }
        }
        if (bestY < 0) return null;
        int col = avgColor(f, (bestX0 + bestX1) / 2, bestY);
        return new int[]{col, bestX0, bestX1, bestY};
    }

    private static boolean inside(List<RectF> excl, float x, float y) {
        for (RectF e : excl) if (e.contains(x, y)) return true;
        return false;
    }

    private static boolean thin(Frame f, int x0, int x1, int y, int ref) {
        int mid = (x0 + x1) / 2, maxH = Math.max(4, (int) (f.h * 0.035f)), h = 1;
        for (int yy = y + 1; yy < f.h && dist(f.rgb(mid, yy), ref) < 70; yy++) h++;
        for (int yy = y - 1; yy >= 0 && dist(f.rgb(mid, yy), ref) < 70; yy--) h++;
        return h <= maxH && (x1 - x0 + 1) >= h * 3;
    }

    /** Pixel le plus saturé autour d'un point (pour mesurer la couleur d'une barre ennemie). */
    public static int mostSaturated(Frame f, int cx, int cy, int rad) {
        int best = 0, bestC = -1;
        for (int y = cy - rad; y <= cy + rad; y++) for (int x = cx - rad; x <= cx + rad; x++) {
            int p = f.rgb(x, y); int ch = chroma(p);
            if (ch > bestC) { bestC = ch; best = p; }
        }
        return bestC > 60 ? best : -1;
    }
}
