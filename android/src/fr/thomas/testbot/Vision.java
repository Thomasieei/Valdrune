package fr.thomas.testbot;

import java.util.ArrayList;
import java.util.List;

/** Vision par couleur sur l'image réduite de l'écran (ARGB). */
final class Vision {
    static final class Blob {
        final float x, y; final int n;
        Blob(float x, float y, int n) { this.x = x; this.y = y; this.n = n; }
    }

    private Vision() {}

    /** Taches de couleur proches de l'une des couleurs, en coordonnées écran. */
    static List<Blob> blobs(int[] px, int w, int h, List<int[]> colors, int tol, int minPx, float sx, float sy) {
        List<Blob> out = new ArrayList<>();
        if (px == null || colors == null || colors.isEmpty() || px.length < w * h) return out;
        int n = w * h, t2 = tol * tol;
        byte[] mask = new byte[n];
        for (int p = 0; p < n; p++) {
            int c = px[p], r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
            for (int[] k : colors) {
                int dr = r - k[0], dg = g - k[1], db = b - k[2];
                if (dr * dr + dg * dg + db * db < t2) { mask[p] = 1; break; }
            }
        }
        int[] st = new int[n];
        for (int p = 0; p < n; p++) {
            if (mask[p] != 1) continue;
            int top = 0, cnt = 0; long sxs = 0, sys = 0;
            st[top++] = p; mask[p] = 2;
            while (top > 0) {
                int q = st[--top], x = q % w, y = q / w;
                cnt++; sxs += x; sys += y;
                if (x > 0 && mask[q - 1] == 1) { mask[q - 1] = 2; st[top++] = q - 1; }
                if (x < w - 1 && mask[q + 1] == 1) { mask[q + 1] = 2; st[top++] = q + 1; }
                if (y > 0 && mask[q - w] == 1) { mask[q - w] = 2; st[top++] = q - w; }
                if (y < h - 1 && mask[q + w] == 1) { mask[q + w] = 2; st[top++] = q + w; }
            }
            if (cnt >= minPx) out.add(new Blob(((float) sxs / cnt + 0.5f) * sx, ((float) sys / cnt + 0.5f) * sy, cnt));
        }
        return out;
    }

    /** Couleur moyenne 3x3 autour d'un point de l'image réduite. */
    static int[] sample(int[] px, int w, int h, float fx, float fy) {
        if (px == null) return null;
        int cx = Math.round(fx), cy = Math.round(fy), r = 0, g = 0, b = 0, n = 0;
        for (int y = cy - 1; y <= cy + 1; y++) for (int x = cx - 1; x <= cx + 1; x++) {
            if (x < 0 || y < 0 || x >= w || y >= h) continue;
            int c = px[y * w + x];
            r += (c >> 16) & 255; g += (c >> 8) & 255; b += c & 255; n++;
        }
        return n == 0 ? null : new int[]{r / n, g / n, b / n};
    }

    /** Luminosité moyenne d'une zone carrée (sert à savoir si un sort est rechargé). */
    static float luma(int[] px, int w, int h, float fx, float fy, int rad) {
        if (px == null) return -1;
        int cx = Math.round(fx), cy = Math.round(fy), n = 0; long s = 0;
        for (int y = cy - rad; y <= cy + rad; y++) for (int x = cx - rad; x <= cx + rad; x++) {
            if (x < 0 || y < 0 || x >= w || y >= h) continue;
            int c = px[y * w + x];
            s += ((c >> 16) & 255) * 3 + ((c >> 8) & 255) * 6 + (c & 255);
            n++;
        }
        return n == 0 ? -1 : s / (10f * n);
    }

    static int lum(int c) { return (((c >> 16) & 255) * 3 + ((c >> 8) & 255) * 6 + (c & 255)) / 10; }

    /** Différence moyenne de luminosité entre deux images, sur une zone (fractions 0..1). */
    static float diff(int[] a, int[] b, int w, int h, float x0, float y0, float x1, float y1) {
        if (a == null || b == null || a.length != b.length || a.length < w * h) return -1;
        int ax = Math.max(0, (int) (x0 * w)), ay = Math.max(0, (int) (y0 * h));
        int bx = Math.min(w, (int) (x1 * w)), by = Math.min(h, (int) (y1 * h));
        long s = 0; int n = 0;
        for (int y = ay; y < by; y += 2) for (int x = ax; x < bx; x += 2) {
            int i = y * w + x;
            s += Math.abs(lum(a[i]) - lum(b[i])); n++;
        }
        return n == 0 ? -1 : (float) s / n;
    }

    static boolean red(int c) {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r > 140 && r > g * 1.8f && r > b * 1.8f;
    }

    static boolean hpColor(int c) {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return red(c) || (g > 140 && g > r * 1.5f && g > b * 1.3f);
    }

    /**
     * Barres de vie rouges (longues, très fines) dans une zone en pixels de l'image réduite.
     * Retour : {x, y, largeur} en pixels de l'image réduite.
     */
    static List<float[]> redBars(int[] px, int w, int h, int x0, int y0, int x1, int y1, int minLen, int maxH) {
        List<float[]> out = new ArrayList<>();
        if (px == null || px.length < w * h) return out;
        x0 = Math.max(0, x0); y0 = Math.max(0, y0); x1 = Math.min(w, x1); y1 = Math.min(h, y1);
        // groupe : xs, xe, yStart, yLast
        List<int[]> open = new ArrayList<>(), done = new ArrayList<>();
        for (int y = y0; y < y1; y++) {
            List<int[]> runs = new ArrayList<>();
            int x = x0;
            while (x < x1) {
                if (!red(px[y * w + x])) { x++; continue; }
                int s = x;
                while (x < x1 && red(px[y * w + x])) x++;
                if (x - s >= minLen) runs.add(new int[]{s, x});
            }
            List<int[]> next = new ArrayList<>();
            for (int[] r : runs) {
                int[] g = null;
                for (int[] o : open) if (o[3] == y - 1 && r[0] < o[1] && r[1] > o[0]) { g = o; break; }
                if (g != null) { open.remove(g); g[0] = Math.min(g[0], r[0]); g[1] = Math.max(g[1], r[1]); g[3] = y; next.add(g); }
                else next.add(new int[]{r[0], r[1], y, y});
            }
            for (int[] o : open) if (o[3] < y) done.add(o);
            open = next;
        }
        done.addAll(open);
        for (int[] g : done) {
            int gh = g[3] - g[2] + 1, gw = g[1] - g[0];
            if (gh <= maxH && gw >= gh * 3) out.add(new float[]{(g[0] + g[1]) / 2f, (g[2] + g[3]) / 2f, gw});
        }
        return out;
    }

    /** Plus longue traînée rouge ou verte d'une zone : sert à lire la barre de vie du joueur. */
    static int hpRun(int[] px, int w, int h, int x0, int y0, int x1, int y1) {
        if (px == null || px.length < w * h) return 0;
        x0 = Math.max(0, x0); y0 = Math.max(0, y0); x1 = Math.min(w, x1); y1 = Math.min(h, y1);
        int best = 0;
        for (int y = y0; y < y1; y++) {
            int run = 0;
            for (int x = x0; x < x1; x++) {
                // barre fine : pas la même couleur 5 px au-dessus et au-dessous (exclut l'herbe d'une minicarte)
                boolean thin = (y - 5 < 0 || !hpColor(px[(y - 5) * w + x])) && (y + 5 >= h || !hpColor(px[(y + 5) * w + x]));
                if (thin && hpColor(px[y * w + x])) { run++; if (run > best) best = run; } else run = 0;
            }
        }
        return best;
    }

    /** Part des pixels peu colorés (écran de mort souvent gris). */
    static float greyRatio(int[] px) {
        if (px == null) return 0;
        int n = 0, g = 0;
        for (int i = 0; i < px.length; i += 37) {
            int c = px[i], r = (c >> 16) & 255, gg = (c >> 8) & 255, b = c & 255;
            int mx = Math.max(r, Math.max(gg, b)), mn = Math.min(r, Math.min(gg, b));
            if (mx - mn < 14) g++;
            n++;
        }
        return n == 0 ? 0 : (float) g / n;
    }

    /** Sol dangereux : rouge-orangé vif (zones d'attaque de boss, souvent en fondu additif). */
    static boolean danger(int c) {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r > 150 && r > g * 1.35f && r > b * 1.6f;
    }

    /**
     * Masque basse résolution des zones dangereuses (1 case = step x step pixels).
     * Une case est dangereuse si au moins 40 % de ses pixels le sont ; les traits fins (barres de vie) sont retirés
     * en exigeant qu'au moins une case voisine au-dessus ou au-dessous soit aussi dangereuse.
     */
    static boolean[] dangerMask(int[] px, int w, int h, int step) {
        int gw = w / step, gh = h / step;
        boolean[] raw = new boolean[gw * gh], out = new boolean[gw * gh];
        int need = Math.max(1, step * step * 2 / 5);
        for (int gy = 0; gy < gh; gy++) for (int gx = 0; gx < gw; gx++) {
            int n = 0;
            for (int y = gy * step; y < gy * step + step; y++) for (int x = gx * step; x < gx * step + step; x++) if (danger(px[y * w + x])) n++;
            raw[gy * gw + gx] = n >= need;
        }
        for (int gy = 1; gy < gh - 1; gy++) for (int gx = 0; gx < gw; gx++) {
            int i = gy * gw + gx;
            if (raw[i] && (raw[i - gw] || raw[i + gw]) && (raw[i - gw] || raw[i + gw]) ) {
                // au moins 3 cases de haut au total : une barre de vie fait 1 case
                out[i] = (raw[i - gw] && raw[i + gw]) || (gy > 1 && raw[i - gw] && raw[i - 2 * gw]) || (gy < gh - 2 && raw[i + gw] && raw[i + 2 * gw]);
            }
        }
        return out;
    }
}
