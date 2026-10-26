package fr.thomas.testbot;

import java.util.ArrayList;
import java.util.List;

/**
 * Lecteur de mini-carte générique.
 *  - Le « terrain » = les quelques couleurs qui couvrent la plus grande partie de la mini-carte.
 *  - Le joueur = la tache blanche la plus proche du centre (sinon le centre : mini-carte qui tourne avec lui).
 *  - Ennemis = petits points rouges ; objectifs = petits points vifs d'une autre couleur (coffres, portails, PNJ).
 *  - Exploration : il lance des rayons depuis le joueur sur le terrain et choisit la direction la plus ouverte
 *    et la plus éloignée des endroits déjà visités (il se souvient d'où il est passé).
 * Toutes les positions renvoyées sont en fractions de la mini-carte (0..1).
 */
final class MiniMap {
    static final class Read {
        float px, py;
        boolean playerSeen;
        final List<float[]> enemies = new ArrayList<>(), pois = new ArrayList<>();
        float[] explore; // direction unitaire sur la mini-carte
        float terrain;   // part du terrain reconnu (0..1) : sert à savoir si la lecture est fiable
    }

    private final List<float[]> visited = new ArrayList<>();
    private long lastVisit;
    /** Décalage d'angle entre la mini-carte et l'écran, appris en bougeant (radians). */
    private double rotS, rotC;
    private int rotN;
    volatile Read last;

    void reset() { visited.clear(); rotS = 0; rotC = 0; rotN = 0; last = null; }

    double rotation() { return rotN < 3 ? 0 : Math.atan2(rotS, rotC); }

    /** Apprentissage de la rotation : j'ai poussé vers l'angle écran aScreen, le joueur a bougé de (dx,dy) sur la mini-carte. */
    void learnRotation(double aScreen, float dx, float dy) {
        if (Math.hypot(dx, dy) < 0.015) return;
        double d = Math.atan2(dy, dx) - aScreen;
        rotS = rotS * 0.85 + Math.sin(d);
        rotC = rotC * 0.85 + Math.cos(d);
        rotN++;
    }

    Read read(int[] f, int fw, int fh, float[] rect, long t) {
        int x0 = Math.max(0, (int) (rect[0] * fw)), y0 = Math.max(0, (int) (rect[1] * fh));
        int x1 = Math.min(fw, (int) Math.ceil(rect[2] * fw)), y1 = Math.min(fh, (int) Math.ceil(rect[3] * fh));
        int W = x1 - x0, H = y1 - y0;
        if (W < 12 || H < 12) return null;
        int N = W * H;
        int[] px = new int[N];
        for (int y = 0; y < H; y++) System.arraycopy(f, (y0 + y) * fw + x0, px, y * W, W);

        // 1. Couleurs du terrain : histogramme sur 4096 cases
        int[] hist = new int[4096];
        for (int c : px) hist[q(c)]++;
        boolean[] terr = new boolean[4096];
        int tn = 0;
        for (int i = 0; i < 4096; i++) {
            // Couleur fréquente ET pas sombre : le sol praticable. Le noir/sombre = zone inconnue ou mur.
            int lum = (((i >> 8) & 15) * 3 + ((i >> 4) & 15) * 6 + (i & 15)) * 16 / 10;
            if (hist[i] > N * 0.035f && lum > 40) { terr[i] = true; tn += hist[i]; }
        }
        Read r = new Read();
        r.terrain = (float) tn / N;

        // 2. Masques : blanc (joueur), rouge (ennemis), vif hors terrain (objectifs)
        byte[] m = new byte[N];
        for (int i = 0; i < N; i++) {
            int c = px[i], R = (c >> 16) & 255, G = (c >> 8) & 255, B = c & 255;
            int mx = Math.max(R, Math.max(G, B)), mn = Math.min(R, Math.min(G, B));
            if (R > 215 && G > 215 && B > 215) m[i] = 1;
            else if (terr[q(c)]) m[i] = 0;
            else if (R > 150 && R > G * 1.8f && R > B * 1.8f) m[i] = 2;
            else if (mx - mn > 70 && mx > 120) m[i] = 3;
        }
        float cx = W / 2f, cy = H / 2f;
        float bestD = 1e9f;
        int[] st = new int[N];
        for (int p = 0; p < N; p++) {
            int k = m[p];
            if (k <= 0) continue;
            int top = 0, n = 0; long sx = 0, sy = 0;
            st[top++] = p; m[p] = (byte) -k;
            while (top > 0) {
                int qd = st[--top], x = qd % W, y = qd / W;
                n++; sx += x; sy += y;
                if (x > 0 && m[qd - 1] == k) { m[qd - 1] = (byte) -k; st[top++] = qd - 1; }
                if (x < W - 1 && m[qd + 1] == k) { m[qd + 1] = (byte) -k; st[top++] = qd + 1; }
                if (y > 0 && m[qd - W] == k) { m[qd - W] = (byte) -k; st[top++] = qd - W; }
                if (y < H - 1 && m[qd + W] == k) { m[qd + W] = (byte) -k; st[top++] = qd + W; }
            }
            if (n > N / 25) continue; // trop gros : décor, pas un point
            float bx = (sx / (float) n + .5f) / W, by = (sy / (float) n + .5f) / H;
            if (k == 1) {
                float d = (float) Math.hypot(bx - .5, by - .5);
                if (n >= 3 && d < bestD) { bestD = d; r.px = bx; r.py = by; r.playerSeen = true; }
            } else if (n >= 2) (k == 2 ? r.enemies : r.pois).add(new float[]{bx, by});
        }
        if (!r.playerSeen) { r.px = .5f; r.py = .5f; }
        // On retire ce qui est collé au joueur (contour de sa flèche)
        r.pois.removeIf(p -> Math.hypot(p[0] - r.px, p[1] - r.py) < 0.04);
        r.enemies.removeIf(p -> Math.hypot(p[0] - r.px, p[1] - r.py) < 0.03);

        // 3. Mémoire des endroits visités
        if (r.playerSeen && t - lastVisit > 800) {
            lastVisit = t;
            float[] lastV = visited.isEmpty() ? null : visited.get(visited.size() - 1);
            if (lastV == null || Math.hypot(lastV[0] - r.px, lastV[1] - r.py) > 0.02) {
                visited.add(new float[]{r.px, r.py});
                if (visited.size() > 300) visited.remove(0);
            }
        }

        // 4. Exploration : 16 rayons sur le terrain, le plus long et le plus neuf l'emporte
        if (r.terrain > 0.05f) {
            double best = -1; float[] bd = null;
            int pxI = (int) (r.px * W), pyI = (int) (r.py * H);
            for (int i = 0; i < 16; i++) {
                double a = i * Math.PI / 8;
                float dx = (float) Math.cos(a), dy = (float) Math.sin(a);
                int len = 0, miss = 0;
                for (int s = 2; s < Math.max(W, H); s++) {
                    int x = Math.round(pxI + dx * s), y = Math.round(pyI + dy * s);
                    if (x < 0 || y < 0 || x >= W || y >= H) break;
                    if (terr[q(px[y * W + x])] || m[y * W + x] != 0) { len = s; miss = 0; }
                    else if (++miss > 2) break;
                }
                if (len < 4) continue;
                float ex = (pxI + dx * len) / W, ey = (pyI + dy * len) / H;
                double nov = 1;
                for (float[] v : visited) nov = Math.min(nov, Math.hypot(v[0] - ex, v[1] - ey) * 4);
                double score = (len / (double) Math.max(W, H)) * (0.25 + nov);
                if (score > best) { best = score; bd = new float[]{dx, dy}; }
            }
            r.explore = bd;
        }
        last = r;
        return r;
    }

    private static int q(int c) { return ((c >> 20) & 15) << 8 | ((c >> 12) & 15) << 4 | ((c >> 4) & 15); }
}
