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
    private List<Detector.Det> curRes = new java.util.ArrayList<>();
    private float rx = -1, ry = -1; private long resSince, lastResTap;
    private final java.util.ArrayList<float[]> blacklist = new java.util.ArrayList<>();
    private int prevHp = -1; private long prevHpT, underAttackUntil, lastTrace;
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
            svc.postOverlay(null, null, null, null, null, -1, null,
                    cs == null ? "Capture inactive — lancez-la depuis l'appli" : "En attente d'images…", 0);
            return;
        }
        List<RectF> excl = svc.exclusions(f.scale);
        List<Detector.Det> en = Detector.findEnemies(f, c, excl);
        List<Detector.Det> res = new java.util.ArrayList<>();
        ModelDetector md = svc.model();
        if (md != null && now - md.latestTime < 800) {
            for (ModelDetector.Obj o : md.latest) {
                if (o.kind == ModelDetector.PLAYER) continue;
                if (hits(excl, o.box.centerX(), o.box.centerY())) continue;
                Detector.Det d = new Detector.Det(o.box, o.name + " " + Math.round(o.conf * 100) + "%");
                if (o.kind == ModelDetector.RESOURCE) res.add(d);
                else if (!overlapsBar(en, d)) en.add(d);
            }
        }
        curRes = res;
        int hp = Detector.readHp(f, c);
        boolean[] ready = Detector.spellsReady(f, c);
        Detector.Det target = pickTarget(en, f);
        String dec = active ? decide(f, c, en, target, hp, ready, now) : "En pause — ▶ pour démarrer";
        if (active) {
            int k = dec.indexOf(" —");
            String kind = k > 0 ? dec.substring(0, k) : dec;
            if (!kind.equals(lastKind)) { BotLog.log("État : " + dec); lastKind = kind; }
        }
        svc.postOverlay(f, en, res, target, curResTarget, hp, ready, dec, fps);
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
        // Perte de vie = on est attaqué, même si l'attaquant n'est pas vu
        if (hp >= 0) {
            if (prevHp >= 0 && prevHp - hp >= 3 && now - prevHpT < 3000) {
                if (now > underAttackUntil) BotLog.log("Alerte : vie " + prevHp + "% → " + hp + "%, je suis attaqué");
                underAttackUntil = now + 6000;
            }
            if (prevHp < 0 || hp != prevHp || now - prevHpT > 3000) { prevHp = hp; prevHpT = now; }
        }
        if (now - lastTrace > 3000) {
            lastTrace = now;
            BotLog.log("Vision : vie " + (hp < 0 ? "?" : hp + "%") + ", ennemis " + en.size()
                    + ", pixels couleur ennemie " + Detector.lastMatchCount + ", sorts prêts " + countReady(ready) + "/" + n);
        }
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
                float by = (target.body ? target.cy() : Math.min(f.h * 0.95f, target.y1 + target.w() * 0.9f)) / f.scale;
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

        // 2b. Riposte à l'aveugle : attaqué mais rien de visible → rotation de sorts
        if (now < underAttackUntil && n > 0) {
            if (now - lastCast >= c.spellIntervalMs) {
                int slot = nextSpell(ready, heal, now, c);
                if (slot >= 0) cast(c, slot, now, "riposte");
            }
            return "RIPOSTE — attaqué, vie " + hp + "%";
        }

        // 3a. Récolte d'une ressource reconnue (arbre, minerai, fibre…) : toucher = y aller et récolter
        curResTarget = null;
        if (c.mode != 0 && !curRes.isEmpty() && now - lastEnemySeen > 1500) {
            blacklist.removeIf(b -> now > b[2]);
            Detector.Det best = null; double bd = Double.MAX_VALUE;
            for (Detector.Det d : curRes) {
                boolean bl = false;
                for (float[] b : blacklist) if (Math.hypot(d.cx() - b[0], d.cy() - b[1]) < f.w * 0.05f) { bl = true; break; }
                if (bl) continue;
                double dd = Math.hypot(d.cx() - f.w / 2f, d.cy() - f.h / 2f);
                if (dd < bd) { bd = dd; best = d; }
            }
            if (best != null) {
                curResTarget = best;
                if (rx < 0 || Math.hypot(best.cx() - rx, best.cy() - ry) > f.w * 0.06f) { resSince = now; BotLog.log("Ressource ciblée : " + best.label); }
                rx = best.cx(); ry = best.cy();
                if (now - resSince > 25000) {
                    blacklist.add(new float[]{rx, ry, now + 60000});
                    BotLog.log("Ressource abandonnée (25 s sans résultat) : " + best.label);
                    rx = -1;
                } else if (now - lastResTap > 3500) {
                    if (svc.tapSafe(best.cx() / f.scale, best.cy() / f.scale, 60)) { lastResTap = now; BotLog.log("Action : récolte " + best.label); }
                    if (c.actionX >= 0 && now - lastAction > 3500) { svc.tap(c.actionX, c.actionY, 60); lastAction = now; }
                }
                lastMove = now;
                return "RÉCOLTE — " + best.label;
            }
        }

        // 3b. Récolte au bouton d'action
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
            boolean ok = false;
            for (int i = 0; i < 8 && !ok; i++) {
                heading += (rnd.nextDouble() - 0.5) * (i == 0 ? 1.2 : 3.0);
                float px = cx + (float) Math.cos(heading) * r * 1.4f, py = cy + (float) Math.sin(heading) * r;
                ok = svc.tapSafe(px, py, 60);
                if (ok) BotLog.log("Action : déplacement d'exploration (" + (int) px + "," + (int) py + ")");
            }
            if (!ok) BotLog.log("Refus : déplacement impossible, tous les points tombent dans une zone interdite");
            lastMove = now;
            return "EXPLORATION — aucun ennemi en vue";
        }
        return en.isEmpty() ? "RECHERCHE — scan de l'écran" : "RÉCOLTE — ennemi ignoré (trop loin)";
    }

    private Detector.Det curResTarget;

    private static boolean hits(List<RectF> ex, float x, float y) { for (RectF e : ex) if (e.contains(x, y)) return true; return false; }

    private static boolean overlapsBar(List<Detector.Det> en, Detector.Det d) {
        for (Detector.Det b : en) if (!b.body && b.cx() > d.x0 && b.cx() < d.x1 && b.y1 < d.y1 && b.y1 > d.y0 - d.h() * 0.6f) return true;
        return false;
    }

    private int countReady(boolean[] r) { int k = 0; for (boolean b : r) if (b) k++; return k; }

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
