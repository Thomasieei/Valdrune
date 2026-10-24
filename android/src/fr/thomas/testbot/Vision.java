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
}
