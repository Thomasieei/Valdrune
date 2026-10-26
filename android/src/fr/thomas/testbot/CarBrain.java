package fr.thomas.testbot;

import android.os.Handler;
import android.os.HandlerThread;

import java.util.ArrayList;
import java.util.List;

/**
 * Cerveau réflexe « foot-voiture » (type Rocket League Sideswipe, vue de côté).
 * Il suit la balle et sa voiture à la couleur, se place derrière la balle par rapport
 * à la cage adverse, pousse, saute quand la balle est au-dessus et boost quand c'est dégagé.
 */
final class CarBrain {
    private final BotService b;
    volatile float[] ball, car;          // position écran
    private volatile long ballT, carT;
    private HandlerThread th;
    private Handler vh;
    private volatile boolean busy;
    private long lastFrame, lastJump, jump2At, lastHelp, stillT, flipUntil;
    private float stillX;
    private int flipDir;
    private long lostSince;
    private boolean lostWarned;

    CarBrain(BotService b) { this.b = b; }

    void begin() { ball = null; car = null; ballT = 0; carT = 0; jump2At = 0; stillT = 0; flipUntil = 0; }

    void stop() { b.joyWant = null; b.holdStart = null; b.hold2 = null; }

    /** Ce qu'il manque pour jouer (vide = prêt). */
    String missing() {
        List<String> m = new ArrayList<>();
        if (b.cfg.ball == null) m.add("la balle");
        if (b.cfg.car == null) m.add("ma voiture");
        if (b.cfg.joy == null && (b.cfg.left == null || b.cfg.right == null)) m.add("la direction (joystick ou gauche/droite)");
        return String.join(", ", m);
    }

    private float md() { return Math.min(b.sw, b.sh); }

    private boolean hud(float x, float y) {
        float r = md() * 0.12f;
        float[][] c = {b.cfg.jump, b.cfg.boost, b.cfg.left, b.cfg.right};
        for (float[] p : c) if (p != null && Math.hypot(x - p[0] * b.sw, y - p[1] * b.sh) < r) return true;
        if (b.cfg.joy != null && Math.hypot(x - b.cfg.joy[0] * b.sw, y - b.cfg.joy[1] * b.sh) < r * 1.7f) return true;
        for (float[] p : b.cfg.avoid) if (Math.hypot(x - p[0] * b.sw, y - p[1] * b.sh) < r) return true;
        return false;
    }

    // ------------------------------------------------------------------ vision (fil séparé)

    private void perceive(int[] f, int fw, int fh, long t) {
        float kx = b.sw / fw, ky = b.sh / fh;
        if (b.cfg.ball != null) {
            List<int[]> c = new ArrayList<>(); c.add(b.cfg.ball);
            float[] prev = ball; boolean fresh = prev != null && t - ballT < 500;
            Vision.Blob best = null; double score = -1e18;
            for (Vision.Blob bl : Vision.blobs(f, fw, fh, c, 48, 5, kx, ky)) {
                if (hud(bl.x, bl.y)) continue;
                double s = fresh ? -Math.hypot(bl.x - prev[0], bl.y - prev[1]) : bl.n;
                if (s > score) { score = s; best = bl; }
            }
            if (best != null) { ball = new float[]{best.x, best.y}; ballT = t; }
        }
        if (b.cfg.car != null) {
            List<int[]> c = new ArrayList<>(); c.add(b.cfg.car);
            float[] prev = car; boolean fresh = prev != null && t - carT < 500;
            Vision.Blob best = null; double score = -1e18;
            for (Vision.Blob bl : Vision.blobs(f, fw, fh, c, 48, 8, kx, ky)) {
                if (hud(bl.x, bl.y) || bl.y < b.sh * 0.12f) continue; // le haut = tableau des scores
                double s = fresh ? -Math.hypot(bl.x - prev[0], bl.y - prev[1]) + bl.n * 0.2 : bl.n;
                if (s > score) { score = s; best = bl; }
            }
            if (best != null) { car = new float[]{best.x, best.y}; carT = t; }
        }
    }

    // ------------------------------------------------------------------ décision

    void tick(long t, int[] f) {
        long ft = CaptureService.frameTime;
        if (f != null && ft != lastFrame && !busy) {
            if (vh == null) { th = new HandlerThread("testbot-car"); th.start(); vh = new Handler(th.getLooper()); }
            busy = true; lastFrame = ft;
            final int[] ff = f; final int fw = CaptureService.fw, fh = CaptureService.fh; final long tt = t;
            vh.post(() -> { try { perceive(ff, fw, fh, tt); } catch (Exception ignored) {} finally { busy = false; } });
        }
        String miss = missing();
        if (!miss.isEmpty()) {
            stop();
            b.status = "Foot : il me manque " + miss;
            if (b.ai.hasKey()) b.ai.help(t, "Il me manque : " + miss + ". Donne leur position.", true);
            return;
        }
        float m = md();
        float[] bl = ball, cr = car;
        if (bl == null || t - ballT > 2500) {
            stop();
            b.status = "Je ne vois pas la balle";
            if (lostSince == 0) lostSince = t;
            if (t - lostSince > 10000 && !lostWarned) {
                lostWarned = true;
                b.event("Balle introuvable depuis 10 s : sa couleur ne correspond plus ? Réapprends-la (Apprendre → Balle)");
                // J'essaie quand même de bouger pour sortir d'un éventuel blocage
                drive(Math.random() < .5 ? -1 : 1);
            }
            if (t - lastHelp > 9000 && b.ai.hasKey()) { lastHelp = t; b.ai.help(t, "Je ne vois plus la balle depuis 2 s (menu, but, replay, fin de match ?).", false); }
            return;
        }
        lostSince = 0; lostWarned = false;
        if (cr == null || t - carT > 2500) {
            stop();
            b.status = "Je ne vois pas ma voiture";
            if (t - lastHelp > 9000 && b.ai.hasKey()) { lastHelp = t; b.ai.help(t, "Je ne trouve pas ma voiture à l'écran.", false); }
            return;
        }
        int dir = b.cfg.attack != 0 ? b.cfg.attack : 1;
        float dx = bl[0] - cr[0], up = cr[1] - bl[1];
        boolean behind = (bl[0] - cr[0]) * dir > -m * 0.05f;

        float targetX;
        if (!behind) { targetX = bl[0] - dir * m * 0.32f; b.status = "Je me replace derrière la balle"; }
        else { targetX = bl[0]; b.status = up > m * 0.1f ? "Balle en l'air" : "Je pousse la balle"; }
        float gap = targetX - cr[0];
        int move = Math.abs(gap) > m * 0.04f ? (gap > 0 ? 1 : -1) : (behind ? dir : 0);

        // Coincé contre un mur : la voiture ne bouge plus alors qu'on roule -> marche arrière un instant
        if (t < flipUntil) move = flipDir;
        else if (move != 0) {
            if (stillT == 0 || Math.abs(cr[0] - stillX) > m * 0.03f) { stillT = t; stillX = cr[0]; }
            else if (t - stillT > 1500) { flipDir = -move; flipUntil = t + 650; stillT = 0; b.nStuck++; b.status = "Coincé, je recule"; }
        } else stillT = 0;

        drive(move);

        // Boost : loin de la balle, du bon côté, balle au sol
        boolean boost = b.cfg.boost != null && behind && Math.abs(dx) > m * 0.3f && up < m * 0.15f && move == (dx > 0 ? 1 : -1);
        b.hold2 = boost ? new float[]{b.cfg.boost[0] * b.sw, b.cfg.boost[1] * b.sh} : null;

        // Saut puis double saut quand la balle passe au-dessus
        if (b.cfg.jump != null) {
            float jx = b.cfg.jump[0] * b.sw, jy = b.cfg.jump[1] * b.sh;
            if (behind && Math.abs(dx) < m * 0.2f && up > m * 0.1f && t - lastJump > 900) {
                b.tap(jx, jy); lastJump = t; jump2At = t + 260;
            }
            if (jump2At > 0 && t >= jump2At) {
                if (up > m * 0.05f && Math.abs(dx) < m * 0.25f) b.tap(jx, jy);
                jump2At = 0;
            }
        }
    }

    /** -1 gauche, +1 droite, 0 rien : joystick tenu, ou bouton gauche/droite tenu. */
    private void drive(int move) {
        if (move == 0) { b.joyWant = null; b.holdStart = null; return; }
        if (b.cfg.joy != null) {
            float jx = b.cfg.joy[0] * b.sw, jy = b.cfg.joy[1] * b.sh, r = BotService.dpS(b, 48);
            b.holdStart = null;
            b.joyWant = new float[]{jx + move * r, jy};
        } else {
            float[] p = move < 0 ? b.cfg.left : b.cfg.right;
            float[] pt = {p[0] * b.sw, p[1] * b.sh};
            b.holdStart = pt;
            b.joyWant = pt;
        }
    }
}
