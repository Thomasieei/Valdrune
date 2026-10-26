package fr.thomas.testbot;

import android.accessibilityservice.AccessibilityService;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Mode auto : le bot découvre seul un RPG vu de dessus (type Albion), sans rien apprendre de Thomas.
 *
 * Ce qu'il suppose, comme un joueur qui débarque :
 *  - la caméra suit le perso, donc le perso est au centre de l'écran ;
 *  - le joystick est en bas à gauche, ou bien on se déplace en touchant le sol ;
 *  - les sorts sont des boutons en bas à droite, qui s'assombrissent pendant le rechargement ;
 *  - les ennemis ont une barre de vie rouge au-dessus de la tête ;
 *  - la vie du joueur est une barre rouge ou verte en haut à gauche ;
 *  - le butin brille (doré) ; ce qui disparaît quand il passe dessus, c'est du butin, et il le retient.
 *
 * Calibrage au premier lancement sur un jeu (≈15 s) :
 *  1. il observe l'écran sans rien faire (bruit de fond : animations) ;
 *  2. il pousse le joystick, puis il touche le sol, et regarde ce qui fait bouger l'image ;
 *  3. il touche les boutons possibles en bas à droite : s'il s'assombrit, c'est un sort ;
 *     si tout l'écran change, c'est un menu : il fait Retour et ne touchera plus jamais ce point.
 */
final class AutoBrain {
    private enum Ph { BASE, JOY, TAP_PREP, TAP, SPELLS, RUN }

    private final BotService b;
    private Ph ph = Ph.RUN;
    private long phT;
    private int[] snap;
    float base = 2f;
    private float dJoy, dTap;

    // Recherche des sorts
    private final List<float[]> cand = new ArrayList<>();
    private int ci, sub;
    private int[] before;
    private float lumBefore;
    private boolean rescanDone, inRescan;
    private Ph after = Ph.RUN;

    // Perception
    /** Remplacées d'un bloc par le fil de vision (jamais modifiées après publication). */
    volatile List<float[]> enemies = new ArrayList<>();
    volatile List<float[]> loot = new ArrayList<>();
    private android.os.HandlerThread visionThread;
    private android.os.Handler vision;
    private volatile boolean busy;
    private long lastFrameSeen;
    float hp = -1;
    private int hpMax;
    private boolean low, dead;
    private long lastDeadTap;
    private int[] still;
    private long stillT;
    private long lastMoveCmd;

    // Décision
    private double heading = Math.random() * 6.283;
    private long headingUntil, lootIgnoreUntil, lastTarget, lastSpell;
    private float[] lootGoal;
    private long arriveT;
    private int[] lootColor;
    private int goneScans;
    private int centerGoldBase = -1;
    private final ArrayList<Integer> goldHist = new ArrayList<>();

    private static final List<int[]> GOLD = new ArrayList<>();
    static {
        GOLD.add(new int[]{238, 186, 40});
        GOLD.add(new int[]{252, 214, 92});
        GOLD.add(new int[]{214, 150, 24});
    }

    final MiniMap mini = new MiniMap();
    private long rotT, darkSince, mapDetourUntil, nearPoiSince;
    private float rotPx, rotPy;
    private double rotA, lastCmdA;
    private final List<float[]> poiBlack = new ArrayList<>(); // x, y (mini-carte), expiration

    AutoBrain(BotService b) { this.b = b; }

    boolean calibrating() { return ph != Ph.RUN; }

    void begin(long t) {
        enemies = new ArrayList<>(); loot = new ArrayList<>(); hp = -1; hpMax = 0; low = false; dead = false;
        still = null; lootGoal = null; centerGoldBase = -1; goldHist.clear(); rescanDone = false;
        mini.reset(); rotT = 0; darkSince = 0; poiBlack.clear(); nearPoiSince = 0;
        if (!b.cfg.calibrated) {
            ph = Ph.BASE; phT = t; snap = CaptureService.frame;
            b.status = "Calibrage : j'observe le jeu";
            b.event("Calibrage du jeu (déplacement, sorts)");
        } else ph = Ph.RUN;
    }

    void stop() { if (ph != Ph.RUN) { ph = Ph.RUN; b.joyWant = null; } }

    private float minDim() { return Math.min(b.sw, b.sh); }

    private float[] joyDefault() { return b.sw > b.sh ? new float[]{0.14f, 0.74f} : new float[]{0.22f, 0.82f}; }

    // ------------------------------------------------------------------ boucle

    void tick(long t) {
        int[] f = CaptureService.frame;
        if (f == null) { b.status = "J'attends l'image de l'écran"; return; }
        switch (ph) {
            case BASE: calBase(t, f); return;
            case JOY: calJoy(t, f); return;
            case TAP_PREP: calTapPrep(t, f); return;
            case TAP: calTap(t, f); return;
            case SPELLS: calSpells(t, f); return;
            default: run(t, f);
        }
    }

    // ------------------------------------------------------------------ calibrage

    private void calBase(long t, int[] f) {
        b.status = "Calibrage : j'observe le jeu";
        if (snap == null) { snap = f; phT = t; return; }
        if (t - phT < 800) return;
        base = Math.max(0.5f, Vision.diff(snap, f, CaptureService.fw, CaptureService.fh, .2f, .2f, .8f, .75f));
        float[] j = joyDefault();
        b.cfg.joy = j;
        snap = f; phT = t; ph = Ph.JOY;
    }

    private void calJoy(long t, int[] f) {
        b.status = "Calibrage : j'essaie le joystick";
        float jx = b.cfg.joy[0] * b.sw, jy = b.cfg.joy[1] * b.sh, r = BotService.dpS(b, 48);
        b.joyWant = new float[]{jx, jy - r};
        if (t - phT < 1200) return;
        dJoy = Vision.diff(snap, f, CaptureService.fw, CaptureService.fh, .2f, .2f, .8f, .75f);
        b.joyWant = null;
        phT = t; ph = Ph.TAP_PREP;
    }

    private void calTapPrep(long t, int[] f) {
        b.status = "Calibrage : j'essaie de toucher le sol";
        if (t - phT < 700) return;
        snap = f;
        b.tap(b.sw * 0.5f, b.sh * 0.3f);
        phT = t; ph = Ph.TAP;
    }

    private void calTap(long t, int[] f) {
        if (t - phT < 1400) return;
        dTap = Vision.diff(snap, f, CaptureService.fw, CaptureService.fh, .2f, .2f, .8f, .75f);
        float thr = base * 2.2f + 2.5f;
        String how;
        if (dJoy > thr && dJoy >= dTap * 0.8f) { b.cfg.move = "joystick"; b.cfg.joy = joyDefault(); how = "joystick"; }
        else if (dTap > thr) { b.cfg.move = "toucher"; b.cfg.joy = null; how = "toucher le sol"; }
        else { b.cfg.move = "joystick"; b.cfg.joy = joyDefault(); how = "joystick (pas sûr)"; b.event("Je n'ai pas vu l'image bouger : j'essaie le joystick par défaut"); }
        b.event("Déplacement trouvé : " + how);
        buildCandidates();
        after = Ph.RUN;
        ci = 0; sub = 0; phT = t; ph = Ph.SPELLS;
    }

    private void buildCandidates() {
        cand.clear();
        float[] xs = {0.96f, 0.885f, 0.81f, 0.735f, 0.66f};
        float[] ys = {0.92f, 0.81f, 0.70f, 0.59f};
        for (float x : xs) for (float y : ys) {
            float sx = x * b.sw, sy = y * b.sh;
            if (b.cfg.joy != null && Math.hypot(sx - b.cfg.joy[0] * b.sw, sy - b.cfg.joy[1] * b.sh) < minDim() * 0.2f) continue;
            if (nearList(b.cfg.avoid, sx, sy, 0.05f) || nearList(b.cfg.spells, sx, sy, 0.05f)) continue;
            cand.add(new float[]{x, y});
        }
        Collections.sort(cand, (p, q) -> Float.compare(
                (1 - p[0]) * (1 - p[0]) + (1 - p[1]) * (1 - p[1]),
                (1 - q[0]) * (1 - q[0]) + (1 - q[1]) * (1 - q[1])));
        while (cand.size() > 12) cand.remove(cand.size() - 1);
    }

    private boolean nearList(List<float[]> l, float sx, float sy, float frac) {
        for (float[] p : l) if (Math.hypot(sx - p[0] * b.sw, sy - p[1] * b.sh) < minDim() * frac * 2) return true;
        return false;
    }

    private void calSpells(long t, int[] f) {
        b.status = (inRescan ? "En combat : je cherche les sorts " : "Calibrage : je cherche les sorts ") + Math.min(ci + 1, cand.size()) + "/" + cand.size();
        int fw = CaptureService.fw, fh = CaptureService.fh;
        if (ci >= cand.size()) { finishSpells(); return; }
        float[] c = cand.get(ci);
        if (sub == 0) { // laisser l'écran se calmer
            if (t - phT < 350) return;
            before = f;
            lumBefore = Vision.luma(f, fw, fh, c[0] * fw, c[1] * fh, 4);
            b.tap(c[0] * b.sw, c[1] * b.sh);
            sub = 1; phT = t;
        } else if (sub == 1) {
            if (t - phT < 600) return;
            float g = Vision.diff(before, f, fw, fh, 0, 0, 1, 1);
            float l = Vision.luma(f, fw, fh, c[0] * fw, c[1] * fh, 4);
            if (g > Math.max(22f, base * 5f)) {
                b.cfg.avoid.add(new float[]{c[0], c[1]});
                b.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK);
                b.event("Bouton de menu repéré (évité)");
                sub = 2; phT = t;
                return;
            }
            if (lumBefore > 25 && l < lumBefore * 0.86f) {
                b.cfg.spells.add(new float[]{c[0], c[1], lumBefore});
                b.nSpells++;
            }
            ci++; sub = 0; phT = t;
        } else { // après un Retour
            if (t - phT < 800) return;
            ci++; sub = 0; phT = t;
        }
    }

    private void finishSpells() {
        boolean first = !b.cfg.calibrated;
        b.cfg.calibrated = true;
        b.saveCfg();
        if (first || inRescan) b.event("Sorts trouvés : " + b.cfg.spells.size() + (b.cfg.spells.isEmpty() ? " (je réessaierai en combat)" : ""));
        if (b.cfg.spells.isEmpty() && !inRescan) rescanDone = false;
        inRescan = false;
        ph = after;
        b.status = "Calibrage terminé";
    }

    /** Pour l'interface : refaire le calibrage. */
    void recalibrate() {
        b.cfg.calibrated = false; b.cfg.spells.clear(); b.cfg.avoid.clear(); b.cfg.joy = null; b.cfg.move = "auto";
        b.saveCfg();
        if (b.on) begin(BotService.now());
    }

    // ------------------------------------------------------------------ perception

    private void perceive(long t, int[] f) {
        int fw = CaptureService.fw, fh = CaptureService.fh;
        float kx = b.sw / fw, ky = b.sh / fh, md = minDim();
        float cx = b.sw / 2f, cy = b.sh / 2f;

        // Ennemis : barres rouges fines
        List<float[]> enemies = new ArrayList<>();
        int minLen = Math.max(4, fw / 120), maxH = Math.max(3, fh / 70);
        for (float[] bar : Vision.redBars(f, fw, fh, 0, (int) (fh * 0.08f), fw, fh, minLen, maxH)) {
            float x = bar[0] * kx, y = bar[1] * ky;
            if (bar[2] > fw * 0.22f) continue; // trop longue : barre d'interface
            if (x < b.sw * 0.4f && y < b.sh * 0.22f) continue; // HUD du joueur
            if (Math.abs(x - cx) < b.sw * 0.07f && y > cy - b.sh * 0.16f && y < cy + b.sh * 0.03f) continue; // ma propre barre
            if (hud(x, y)) continue;
            enemies.add(new float[]{x, y + b.sh * 0.045f});
        }

        // Ma vie : barre rouge/verte en haut à gauche
        int run = Vision.hpRun(f, fw, fh, 0, 0, (int) (fw * 0.42f), (int) (fh * 0.2f));
        if (run > hpMax) hpMax = run;
        hp = hpMax >= Math.max(8, fw / 60) ? (float) run / hpMax : -1;

        // Butin : doré + couleurs déjà apprises
        List<float[]> loot = new ArrayList<>();
        List<int[]> cols = new ArrayList<>(GOLD);
        cols.addAll(b.cfg.chest);
        for (Vision.Blob bl : Vision.blobs(f, fw, fh, cols, 55, 4, kx, ky)) {
            if (bl.n > fw * fh / 60) continue; // trop gros : décor ou interface
            if (bl.y < b.sh * 0.1f || hud(bl.x, bl.y)) continue;
            if (Math.hypot(bl.x - cx, bl.y - cy) < md * 0.035f) continue;
            loot.add(new float[]{bl.x, bl.y});
        }

        this.enemies = enemies;
        this.loot = loot;
        if (b.cfg.minimap != null) { try { mini.read(f, fw, fh, b.cfg.minimap, t); } catch (Exception ignored) {} }

        // Pixels dorés au centre : sert à savoir si le butin a été ramassé
        int g = centerGold(f, fw, fh);
        if (lootGoal == null && loot.isEmpty()) {
            goldHist.add(g);
            if (goldHist.size() > 30) goldHist.remove(0);
            ArrayList<Integer> s = new ArrayList<>(goldHist);
            Collections.sort(s);
            centerGoldBase = s.get(s.size() / 2);
        }
    }

    private int centerGold(int[] f, int fw, int fh) {
        int r = Math.round(Math.min(fw, fh) * 0.09f), cx = fw / 2, cy = fh / 2, n = 0;
        int t2 = 55 * 55;
        for (int y = cy - r; y <= cy + r; y++) for (int x = cx - r; x <= cx + r; x++) {
            if (x < 0 || y < 0 || x >= fw || y >= fh) continue;
            int c = f[y * fw + x], R = (c >> 16) & 255, G = (c >> 8) & 255, B = c & 255;
            for (int[] k : GOLD) { int a = R - k[0], d = G - k[1], e = B - k[2]; if (a * a + d * d + e * e < t2) { n++; break; } }
        }
        return n;
    }

    /** Zones d'interface : sorts, joystick, menus repérés. */
    private boolean hud(float x, float y) {
        float md = minDim();
        float[] mm = b.cfg.minimap;
        if (mm != null && x > (mm[0] - .02f) * b.sw && x < (mm[2] + .02f) * b.sw && y > (mm[1] - .02f) * b.sh && y < (mm[3] + .02f) * b.sh) return true;
        for (float[] s : b.cfg.spells) if (Math.hypot(x - s[0] * b.sw, y - s[1] * b.sh) < md * 0.09f) return true;
        for (float[] s : b.cfg.avoid) if (Math.hypot(x - s[0] * b.sw, y - s[1] * b.sh) < md * 0.09f) return true;
        if (b.cfg.joy != null && Math.hypot(x - b.cfg.joy[0] * b.sw, y - b.cfg.joy[1] * b.sh) < md * 0.2f) return true;
        return x > b.sw * 0.62f && y > b.sh * 0.55f; // coin des sorts
    }

    // ------------------------------------------------------------------ décision

    private void run(long t, int[] f) {
        // La vision tourne sur son propre fil, à chaque nouvelle image : l'affichage et les gestes ne rament plus
        long ft = CaptureService.frameTime;
        if (ft != lastFrameSeen && !busy) {
            if (vision == null) {
                visionThread = new android.os.HandlerThread("testbot-vision");
                visionThread.start();
                vision = new android.os.Handler(visionThread.getLooper());
            }
            busy = true; lastFrameSeen = ft;
            final int[] ff = f; final long tt = t;
            vision.post(() -> { try { perceive(tt, ff); } catch (Exception ignored) {} finally { busy = false; } });
        }
        float md = minDim(), cx = b.sw / 2f, cy = b.sh / 2f;
        b.px = cx; b.py = cy;

        // Mort ?
        float grey = Vision.greyRatio(f);
        long ls = 0; int ln = 0;
        for (int i = 0; i < f.length; i += 53) { ls += Vision.lum(f[i]); ln++; }
        float meanLum = ln == 0 ? 0 : (float) ls / ln;
        // Vrai écran noir seulement : très sombre ET uniforme pendant plus d'une seconde (une scène sombre a des contrastes)
        long vs = 0;
        for (int i = 0; i < f.length; i += 53) { float dl = Vision.lum(f[i]) - meanLum; vs += (long) (dl * dl); }
        float sd = ln == 0 ? 0 : (float) Math.sqrt((double) vs / ln);
        if (meanLum < 10 && sd < 6) {
            if (darkSince == 0) darkSince = t;
            if (t - darkSince > 1000) { b.joyWant = null; b.status = "Écran noir (chargement ?), j'attends"; return; }
        } else darkSince = 0;
        boolean deadNow = grey > 0.78f || (hp >= 0 && hp < 0.03f && hpMax > 0);
        if (deadNow && !dead) { dead = true; b.event("Mon perso est mort"); b.nDeaths++; }
        if (dead) {
            b.joyWant = null;
            b.status = "Mort, j'attends la réapparition";
            if (t - lastDeadTap > 3000) { b.tap(cx, b.sh * 0.72f); lastDeadTap = t; }
            if (grey < 0.6f && (hp < 0 || hp > 0.2f)) { dead = false; b.event("Réapparition"); hpMax = 0; }
            return;
        }

        float[] en = nearest(enemies, cx, cy);
        float de = en == null ? 1e9f : (float) Math.hypot(en[0] - cx, en[1] - cy);
        boolean lowNow = hp >= 0 && hp < 0.33f;
        if (lowNow && !low) b.event("PV bas (" + Math.round(hp * 100) + " %)");
        low = lowNow;

        // Sorts : en combat ou en danger
        boolean fight = en != null && de < md * 0.32f;
        if (b.cfg.autoSpells && (fight || low)) {
            if (b.cfg.spells.isEmpty() && !rescanDone && fight) {
                rescanDone = true; inRescan = true; buildCandidates();
                if (!cand.isEmpty()) { after = Ph.RUN; ci = 0; sub = 0; phT = t; ph = Ph.SPELLS; return; }
                inRescan = false;
            }
            if (t - lastSpell > b.cfg.spellEvery) castAny(t);
        }

        // 1. Fuir si la vie est basse
        if (low && en != null && de < md * 0.45f) {
            b.status = "PV bas : je recule";
            go(t, cx - (en[0] - cx), cy - (en[1] - cy));
            checkStuck(t, f);
            return;
        }
        // 2. Combat au corps à corps
        if (b.cfg.hunt && en != null && de < md * 0.2f) {
            b.status = "Combat";
            b.joyWant = null;
            if (t - lastTarget > 1600) { b.tap(en[0], en[1]); lastTarget = t; }
            still = null;
            return;
        }
        // 3. Butin
        if (b.cfg.autoChests && t > lootIgnoreUntil && (lootGoal != null || !loot.isEmpty())) {
            if (handleLoot(t, f)) { checkStuck(t, f); return; }
        }
        // 4. Aller vers un ennemi visible
        if (b.cfg.hunt && en != null) {
            b.status = "Va vers un ennemi";
            go(t, en[0], en[1]);
            checkStuck(t, f);
            return;
        }
        // 5. Mini-carte : objectifs, monstres au loin, zones jamais visitées
        MiniMap.Read mm = b.cfg.minimap != null ? mini.last : null;
        if (mm != null) learnRot(t, mm);
        if (b.cfg.explore && mm != null && mm.terrain > 0.05f && t > mapDetourUntil) {
            for (int i = poiBlack.size() - 1; i >= 0; i--) if (t > poiBlack.get(i)[2]) poiBlack.remove(i);
            float[] goal = null; String why = "Explore (mini-carte)";
            if (b.cfg.autoChests) {
                List<float[]> ok = new ArrayList<>();
                for (float[] p : mm.pois) { boolean bl = false; for (float[] k : poiBlack) if (Math.hypot(k[0] - p[0], k[1] - p[1]) < 0.04) bl = true; if (!bl) ok.add(p); }
                goal = nearest(ok, mm.px, mm.py);
                if (goal != null) why = "Va vers un objectif (mini-carte)";
            }
            if (goal == null && b.cfg.hunt) { goal = nearest(mm.enemies, mm.px, mm.py); if (goal != null) why = "Va vers des monstres (mini-carte)"; }
            float dx, dy;
            if (goal != null) {
                dx = goal[0] - mm.px; dy = goal[1] - mm.py;
                // Arrivé sur un objectif qui ne disparaît pas (portail, PNJ) : on l'oublie un moment
                if (Math.hypot(dx, dy) < 0.035) {
                    if (nearPoiSince == 0) nearPoiSince = t;
                    if (t - nearPoiSince > 3000) { poiBlack.add(new float[]{goal[0], goal[1], t + 30000}); nearPoiSince = 0; }
                } else nearPoiSince = 0;
            } else if (mm.explore != null) { dx = mm.explore[0]; dy = mm.explore[1]; }
            else { dx = 0; dy = 0; }
            if (dx != 0 || dy != 0) {
                double a = Math.atan2(dy, dx) - mini.rotation();
                b.status = why;
                go(t, (float) (cx + Math.cos(a) * md * 0.3), (float) (cy + Math.sin(a) * md * 0.3));
                if (checkStuck(t, f)) { mapDetourUntil = t + 1800; turn(true); if (goal != null) poiBlack.add(new float[]{goal[0], goal[1], t + 15000}); }
                return;
            }
        }
        // 6. Explorer au hasard
        if (b.cfg.explore) {
            if (t > headingUntil) turn(false);
            b.status = "Explore";
            go(t, (float) (cx + Math.cos(heading) * md * 0.3), (float) (cy + Math.sin(heading) * md * 0.3));
            checkStuck(t, f);
        } else { b.status = "Attend"; b.joyWant = null; }
    }

    private boolean handleLoot(long t, int[] f) {
        float md = minDim(), cx = b.sw / 2f, cy = b.sh / 2f;
        float[] l = nearest(loot, cx, cy);
        if (l != null) lootGoal = l;
        if (lootGoal == null) return false;
        float d = (float) Math.hypot(lootGoal[0] - cx, lootGoal[1] - cy);
        if (arriveT == 0 && d < md * 0.08f) {
            arriveT = t;
            int fw = CaptureService.fw, fh = CaptureService.fh;
            lootColor = Vision.sample(f, fw, fh, lootGoal[0] / b.sw * fw, lootGoal[1] / b.sh * fh);
            b.tap(lootGoal[0], lootGoal[1]);
        }
        if (arriveT > 0) {
            b.joyWant = null;
            b.status = "Ramasse";
            boolean near = false;
            for (float[] p : loot) if (Math.hypot(p[0] - cx, p[1] - cy) < md * 0.1f) { near = true; break; }
            int g = centerGold(f, CaptureService.fw, CaptureService.fh);
            if (!near && (centerGoldBase < 0 || g <= centerGoldBase + 3)) goneScans++; else goneScans = 0;
            if (goneScans >= 3) {
                b.nChests++;
                learnLoot();
                lootGoal = null; arriveT = 0; goneScans = 0;
                b.status = "Butin ramassé";
                return true;
            }
            if (t - arriveT > 4000) {
                b.event("Butin impossible à ramasser (ignoré un moment)");
                lootGoal = null; arriveT = 0; goneScans = 0;
                lootIgnoreUntil = t + 6000; turn(true);
                return false;
            }
            if (t - arriveT > 1800 && t - lastTarget > 1200) { b.tap(cx, cy); lastTarget = t; }
            return true;
        }
        b.status = "Va au butin";
        go(t, lootGoal[0], lootGoal[1]);
        if (l == null) lootGoal = null; // plus visible : on oublie
        return true;
    }

    /** Ce qui a disparu quand je suis passé dessus, c'est du butin : je retiens sa couleur. */
    private void learnLoot() {
        if (lootColor == null || b.cfg.chest.size() >= 6) return;
        for (int[] c : b.cfg.chest) {
            int a = c[0] - lootColor[0], d = c[1] - lootColor[1], e = c[2] - lootColor[2];
            if (a * a + d * d + e * e < 40 * 40) return;
        }
        for (int[] c : GOLD) {
            int a = c[0] - lootColor[0], d = c[1] - lootColor[1], e = c[2] - lootColor[2];
            if (a * a + d * d + e * e < 40 * 40) return;
        }
        b.cfg.chest.add(lootColor);
        b.saveCfg();
        b.event("Nouvelle couleur de butin apprise");
    }

    private void castAny(long t) {
        int n = b.cfg.spells.size();
        for (int k = 0; k < n; k++) {
            int i = (b.spellIdx + k) % n;
            float[] s = b.cfg.spells.get(i);
            if (b.ready(s)) {
                b.tap(s[0] * b.sw, s[1] * b.sh);
                b.spellIdx = (i + 1) % n; lastSpell = t; b.nSpells++;
                return;
            }
        }
    }

    private void go(long t, float x, float y) {
        b.steerTo(x, y);
        lastMoveCmd = t;
        lastCmdA = Math.atan2(y - b.sh / 2f, x - b.sw / 2f);
    }

    /** Apprend de combien la mini-carte est tournée par rapport à l'écran, en regardant ma flèche bouger. */
    private void learnRot(long t, MiniMap.Read mm) {
        if (!mm.playerSeen || t - lastMoveCmd > 300) { rotT = 0; return; }
        if (rotT == 0 || Math.abs(Math.atan2(Math.sin(lastCmdA - rotA), Math.cos(lastCmdA - rotA))) > 0.5) {
            rotT = t; rotPx = mm.px; rotPy = mm.py; rotA = lastCmdA; return;
        }
        if (t - rotT > 1200) {
            mini.learnRotation(rotA, mm.px - rotPx, mm.py - rotPy);
            rotT = 0;
        }
    }

    private void turn(boolean blocked) {
        heading += blocked ? (Math.random() < .5 ? 1 : -1) * (1.6 + Math.random() * 1.2) : (Math.random() - 0.5) * 2.2;
        headingUntil = BotService.now() + 3500 + (long) (Math.random() * 3000);
    }

    /** Image figée alors que je bouge : je suis bloqué contre un mur. */
    private boolean checkStuck(long t, int[] f) {
        if (t - lastMoveCmd > 800) { still = null; return false; }
        if (still == null) { still = f; stillT = t; return false; }
        if (t - stillT < 1600) return false;
        float d = Vision.diff(still, f, CaptureService.fw, CaptureService.fh, .2f, .2f, .8f, .75f);
        still = f; stillT = t;
        if (d >= 0 && d < base * 1.3f + 0.6f) {
            b.nStuck++;
            b.status = "Bloqué, je change de direction";
            if (lootGoal != null) { lootGoal = null; arriveT = 0; lootIgnoreUntil = t + 5000; }
            turn(true);
            return true;
        }
        return false;
    }

    private static float[] nearest(List<float[]> l, float x, float y) {
        float[] best = null; double bd = 1e18;
        for (float[] p : l) { double d = Math.hypot(p[0] - x, p[1] - y); if (d < bd) { bd = d; best = p; } }
        return best;
    }
}
