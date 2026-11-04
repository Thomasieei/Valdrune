package com.thomas.botlab;

import android.graphics.RectF;
import android.os.SystemClock;
import java.util.List;
import java.util.Random;

/** Cerveau du bot : ~7 décisions/seconde à partir de ce que voit le Detector. */
public class Brain implements Runnable {
    private final BotService svc;
    private volatile boolean running = true;
    public volatile boolean active = false;
    private final Random rnd = new Random();

    private long lastCast, lastTargetTap, lastEnemySeen, lastMove, lastAction, lastFlee;
    private final long[] slotCast = new long[8];
    private int rr = 0;
    private float tx = -1, ty = -1;
    private boolean switched;
    private double heading;
    private String lastKind = "";
    private int fps;
    private long fpsT0; private int fpsN;

    Brain(BotService s) { svc = s; heading = rnd.nextDouble() * Math.PI * 2; }

    void start() { new Thread(this, "brain").start(); }
    void stop() { running = false; }

    @Override public void run() {
        while (running) {
            long t = SystemClock.uptimeMillis();
            try { tick(); } catch (Throwable e) { BotLog.log("Erreur cerveau : " + e); }
            long dt = SystemClock.uptimeMillis() - t;
            try { Thread.sleep(Math.max(20, 140 - dt)); } catch (InterruptedException ignored) { }
        }
    }

    public void setActive(boolean a) {
        active = a;
        tx = -1; lastEnemySeen = SystemClock.uptimeMillis();
        BotLog.log(a ? "▶ BOT DÉMARRÉ" : "⏸ BOT EN PAUSE");
    }

    private void tick() {
        long now = SystemClock.uptimeMillis();
        if (++fpsN >= 7) { fps = (int) (fpsN * 1000 / Math.max(1, now - fpsT0)); fpsT0 = now; fpsN = 0; }
        CaptureService cs = CaptureService.instance;
        Frame f = cs == null ? null : cs.latest;
        Config c = Config.get(svc);
        if (f == null || now - f.time > 1500) {
            svc.postOverlay(null, null, null, -1, null,
                    cs == null ? "Capture inactive — lancez-la depuis l'appli" : "En attente d'images…", 0);
            return;
        }
        List<RectF> excl = svc.exclusions(f.scale);
        List<Detector.Det> en = Detector.findEnemies(f, c, excl);
        int hp = Detector.readHp(f, c);
        boolean[] ready = Detector.spellsReady(f, c);
        Detector.Det target = pickTarget(en, f);
        String dec = active ? decide(f, c, en, target, hp, ready, now) : "En pause — ▶ pour démarrer";
        if (active) {
            int k = dec.indexOf(" —");
            String kind = k > 0 ? dec.substring(0, k) : dec;
            if (!kind.equals(lastKind)) { BotLog.log("État : " + dec); lastKind = kind; }
        }
        svc.postOverlay(f, en, target, hp, ready, dec, fps);
    }

    private Detector.Det pickTarget(List<Detector.Det> en, Frame f) {
        switched = false;
        if (en.isEmpty()) { tx = -1; return null; }
        Detector.Det best = null; float bd = Float.MAX_VALUE;
        if (tx >= 0) {
            for (Detector.Det d : en) {
                float dd = (float) Math.hypot(d.cx() - tx, d.cy() - ty);
                if (dd < bd) { bd = dd; best = d; }
            }
            if (bd > f.w * 0.12f) best = null;
        }
        if (best == null) {
            bd = Float.MAX_VALUE;
            for (Detector.Det d : en) {
                float dd = (float) Math.hypot(d.cx() - f.w / 2f, d.cy() - f.h / 2f);
                if (dd < bd) { bd = dd; best = d; }
            }
            switched = true;
        }
        tx = best.cx(); ty = best.cy();
        return best;
    }

    private String decide(Frame f, Config c, List<Detector.Det> en, Detector.Det target, int hp, boolean[] ready, long now) {
        int n = ready.length, heal = c.healSlot - 1;
        if (!en.isEmpty()) lastEnemySeen = now;
        boolean healReady = heal >= 0 && heal < n && ready[heal] && now - slotCast[heal] > Math.max(600, c.spellIntervalMs);
        float sw = f.screenW, sh = f.screenH, cx = sw / 2f, cy = sh / 2f;

        // 1. Survie
        if (hp >= 0 && hp < c.fleePct && !healReady) {
            if (now - lastFlee > 700) {
                double ang;
                Detector.Det near = nearest(en, f);
                if (near != null) ang = Math.atan2(f.h / 2f - near.cy(), f.w / 2f - near.cx());
                else ang = heading + Math.PI;
                float r = 0.3f * Math.min(sw, sh);
                for (int i = 0; i < 5; i++) {
                    double a = ang + (i == 0 ? 0 : (rnd.nextDouble() - 0.5) * 1.6);
                    if (svc.tapSafe(cx + (float) Math.cos(a) * r * 1.3f, cy + (float) Math.sin(a) * r, 60)) break;
                }
                lastFlee = now;
                BotLog.log("Action : fuite (vie " + hp + "%)");
            }
            return "FUITE — vie " + hp + "%";
        }
        if (hp >= 0 && hp < c.healPct && healReady && now - lastCast > 300) {
            cast(c, heal, now, "soin, vie " + hp + "%");
            return "SOIN — sort " + (heal + 1) + ", vie " + hp + "%";
        }

        // 2. Combat
        boolean fight = target != null && (c.mode != 1
                || Math.hypot(target.cx() - f.w / 2f, target.cy() - f.h / 2f) < f.w * 0.22f);
        if (fight) {
            StringBuilder s = new StringBuilder("COMBAT — ").append(en.size()).append(" ennemi(s)");
            if (switched || now - lastTargetTap > c.retargetMs) {
                float bx = target.cx() / f.scale;
                float by = Math.min(f.h * 0.95f, target.y1 + target.w() * 0.9f) / f.scale;
                if (svc.tapSafe(bx, by, 50)) {
                    lastTargetTap = now;
                    BotLog.log("Action : cible touchée (" + (int) bx + "," + (int) by + ")" + (switched ? " [nouvelle cible]" : ""));
                }
            }
            if (now - lastCast >= c.spellIntervalMs) {
                int slot = nextSpell(ready, heal, now, c);
                if (slot >= 0) { cast(c, slot, now, "attaque"); s.append(" · sort ").append(slot + 1); }
            }
            return s.toString();
        }

        // 3. Récolte
        if (c.mode != 0 && c.actionX >= 0 && now - lastAction > 1600 && now - lastEnemySeen > 1500) {
            svc.tap(c.actionX, c.actionY, 60);
            lastAction = now;
            BotLog.log("Action : bouton récolte/action");
            return "RÉCOLTE — appui sur le bouton d'action";
        }

        // 4. Exploration
        long moveEvery = c.mode == 0 ? 2600 : 9000;
        if (now - lastEnemySeen > c.exploreAfterMs && now - lastMove > moveEvery) {
            float r = (0.22f + rnd.nextFloat() * 0.1f) * Math.min(sw, sh);
            for (int i = 0; i < 6; i++) {
                heading += (rnd.nextDouble() - 0.5) * (i == 0 ? 1.2 : 3.0);
                if (svc.tapSafe(cx + (float) Math.cos(heading) * r * 1.4f, cy + (float) Math.sin(heading) * r, 60)) break;
            }
            lastMove = now;
            BotLog.log("Action : déplacement d'exploration");
            return "EXPLORATION — aucun ennemi en vue";
        }
        return en.isEmpty() ? "RECHERCHE — scan de l'écran" : "RÉCOLTE — ennemi ignoré (trop loin)";
    }

    private Detector.Det nearest(List<Detector.Det> en, Frame f) {
        Detector.Det best = null; double bd = Double.MAX_VALUE;
        for (Detector.Det d : en) {
            double dd = Math.hypot(d.cx() - f.w / 2f, d.cy() - f.h / 2f);
            if (dd < bd) { bd = dd; best = d; }
        }
        return best;
    }

    private int nextSpell(boolean[] ready, int heal, long now, Config c) {
        int n = ready.length;
        for (int k = 0; k < n; k++) {
            int s = (rr + k) % n;
            if (s == heal) continue;
            if (ready[s] && now - slotCast[s] > Math.max(600, c.spellIntervalMs)) { rr = s + 1; return s; }
        }
        return -1;
    }

    private void cast(Config c, int slot, long now, String why) {
        svc.tap(c.spellX[slot], c.spellY[slot], 50);
        slotCast[slot] = now; lastCast = now;
        BotLog.log("Action : sort " + (slot + 1) + " (" + why + ")");
    }
}
