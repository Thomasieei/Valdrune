package fr.thomas.testbot;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Point;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.hardware.display.DisplayManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Display;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Le bot : bulle flottante par-dessus le jeu, il regarde l'écran (CaptureService),
 * décide, puis touche l'écran avec de vrais gestes (déplacement, sorts, coffres).
 */
public class BotService extends AccessibilityService {
    static volatile BotService inst;

    private static final int CI = Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE;
    static final Pattern RX_POPUP = Pattern.compile("^(r[ée]cup[ée]rer|ramasser|collecter|collect|claim|continuer|fermer|ok|valider|super|g[ée]nial|merci|suivant|prendre|ouvrir)\\b", CI);
    static final Pattern RX_CHEST = Pattern.compile("coffre|chest|loot|tr[ée]sor|butin", CI);
    static final Pattern RX_SPELL = Pattern.compile("sort|spell|skill|comp[ée]tence|capacit[ée]|attaque|attack|ulti|magie", CI);
    static final Pattern RX_BAD = Pattern.compile("achat|acheter|buy|payer|\\bpay|€|\\$|reset|r[ée]initialis|supprimer|delete|quitter|sortie|exit|logout|d[ée]connex|\\bpub\\b|vid[ée]o|regarder|partager|share|abandonner|annuler|boutique|shop", CI);

    private WindowManager wm;
    private final Handler h = new Handler(Looper.getMainLooper());

    // Jeu testé + apprentissage
    Cfg cfg = new Cfg();
    String gamePkg, gameLabel = "Aucun jeu";

    // État de la session
    boolean on;
    private long t0, runMs;
    int nSpells, nChests, nStuck, nPopups, nTaps, nDeaths;
    final AutoBrain auto = new AutoBrain(this);
    final AiBrain ai = new AiBrain(this);
    final CarBrain foot = new CarBrain(this);

    void post(Runnable r) { h.post(r); }

    /** Cerveau réellement utilisé : rpg, foot, ia, ou attente (l'IA n'a pas encore regardé le jeu). */
    String effectiveBrain() {
        if (!cfg.brain.equals("auto")) return cfg.brain.equals("ia") && !ai.hasKey() ? "rpg" : cfg.brain;
        switch (cfg.genre) {
            case "foot_voiture": return "foot";
            case "rpg": return "rpg";
            case "autre": return ai.hasKey() ? "ia" : "rpg";
            default: return ai.hasKey() ? "attente" : "rpg";
        }
    }

    static String brainName(String k) {
        switch (k) {
            case "rpg": return "RPG";
            case "foot": return "foot-voiture";
            case "ia": return "IA qui joue";
            case "attente": return "en attente de l'IA";
            default: return "auto";
        }
    }
    final List<String> events = new ArrayList<>();
    String status = "En attente";
    private boolean blackScreen;

    // Perception
    float sw = 1080, sh = 2400, px, py;
    private boolean pAssumed = true;
    List<Vision.Blob> chests = new ArrayList<>(), enemies = new ArrayList<>();

    // Cerveau
    private long lastSpell, lastPopup, lastNodeChest, lastTapMove, lastChestTap, closeTo, lastNodeSpell;
    int spellIdx;
    private int prevChestN, tick;
    private String kind = "explore";
    private boolean prog; private float progBest; private long progT, progStart; private int progN, progSide = 1;
    private long detourUntil; private int detourSide;
    private double wanderA = Math.random() * 6.283; private long wanderUntil;
    private final List<float[]> black = new ArrayList<>(); // x, y, expiration

    // Gestes
    /** Doigt 1 tenu : vers où pousser le joystick (départ = centre du joystick, ou holdStart). */
    float[] joyWant;
    /** Si non nul, le doigt 1 part de ce point au lieu du centre du joystick (bouton gauche/droite tenu). */
    float[] holdStart;
    /** Doigt 2 tenu (ex. boost), sur ce point. */
    float[] hold2;

    /** Un doigt qui reste posé d'un geste à l'autre. */
    private static final class Finger {
        GestureDescription.StrokeDescription stroke;
        float lx, ly, sx, sy;
        boolean wig;
    }
    private final Finger f1 = new Finger(), f2 = new Finger();
    private boolean inFlight;
    private final List<GestureDescription.StrokeDescription> pend = new ArrayList<>();

    // Interface
    private TextView bubble;
    private LinearLayout panel;
    private FrameLayout catcher;
    private WindowManager.LayoutParams bubbleLp, panelLp;
    private String learn, tab = "";
    private TextView tGo, tStatus, tTime, tGame, vChest, vSpell, vStuck, vAlert, tReport;
    private LinearLayout tabBar, pane;
    private final List<TextView> tabBtns = new ArrayList<>();
    private long wipeArmed;

    static long now() { return SystemClock.uptimeMillis(); }

    // ------------------------------------------------------------------ cycle de vie

    @Override
    protected void onServiceConnected() {
        inst = this;
        wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        SharedPreferences p = Cfg.prefs(this);
        gamePkg = p.getString("game", null);
        gameLabel = p.getString("gameLabel", "Aucun jeu");
        cfg = Cfg.load(this, gamePkg);
        h.post(loop);
    }

    @Override public void onInterrupt() {}

    @Override
    public boolean onUnbind(Intent intent) {
        inst = null;
        h.removeCallbacksAndMessages(null);
        hideAll();
        return super.onUnbind(intent);
    }

    @Override public void onDestroy() { inst = null; super.onDestroy(); }

    private final Runnable loop = new Runnable() {
        @Override public void run() {
            tick++;
            try {
                updateScreen();
                if (on) think();
                flush();
                if (tick % 4 == 0) refreshUi();
                if (sight != null && sight.getWindowToken() != null) sight.invalidate();
            } catch (Exception e) {
                event("Erreur interne du bot : " + e.getClass().getSimpleName());
            }
            h.postDelayed(this, 50); // 20 décisions/s
        }
    };

    /** Appelé depuis l'appli quand Thomas choisit un jeu dans la liste. */
    void prepare(String pkg, String label) {
        if (on) stop();
        setGame(pkg, label);
        showBubble();
    }

    private void setGame(String pkg, String label) {
        if (pkg == null) return;
        if (!pkg.equals(gamePkg)) { gamePkg = pkg; cfg = Cfg.load(this, pkg); }
        gameLabel = label != null ? label : labelOf(pkg);
        Cfg.prefs(this).edit().putString("game", gamePkg).putString("gameLabel", gameLabel).apply();
    }

    private String labelOf(String pkg) {
        try {
            PackageManager pm = getPackageManager();
            ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
            return String.valueOf(pm.getApplicationLabel(ai));
        } catch (Exception e) { return pkg; }
    }

    private void updateScreen() {
        DisplayManager dm = (DisplayManager) getSystemService(DISPLAY_SERVICE);
        Display d = dm.getDisplay(Display.DEFAULT_DISPLAY);
        Point p = new Point();
        d.getRealSize(p);
        sw = p.x; sh = p.y;
        if (tick % 7 == 0) CaptureService.checkSize();
    }

    // ------------------------------------------------------------------ démarrer / arrêter

    void start() {
        if (on) return;
        if (!CaptureService.running()) { toast("Ouvre TestBot et autorise la vue de l'écran d'abord"); return; }
        try {
            AccessibilityNodeInfo root = getRootInActiveWindow();
            if (root != null && root.getPackageName() != null) {
                String pkg = root.getPackageName().toString();
                if (!pkg.equals(getPackageName()) && !pkg.equals("com.android.systemui")) setGame(pkg, null);
            }
        } catch (Exception ignored) {}
        on = true; t0 = now(); prog = false; kind = "explore";
        status = "Démarrage";
        ai.reset(); foot.begin();
        if (cfg.auto) auto.begin(t0);
        if (panel != null && panel.getWindowToken() != null) showBubble();
        showSight();
        toast("Bot lancé sur " + gameLabel);
        refreshUi();
    }

    void stop() {
        if (!on) return;
        on = false; runMs += now() - t0;
        auto.stop(); foot.stop(); ai.reset();
        joyWant = null; holdStart = null; hold2 = null; status = "En pause";
        if (sight != null) sight.invalidate();
        Cfg.prefs(this).edit().putString("last_report", report()).apply();
        refreshUi();
    }

    void resetStats() {
        nSpells = nChests = nStuck = nPopups = nTaps = nDeaths = 0; events.clear();
        runMs = 0; if (on) t0 = now();
    }

    String elapsed() { return Ui.dur(runMs + (on ? now() - t0 : 0)); }

    void event(String m) {
        String line = "[" + elapsed() + "] " + m;
        if (events.size() < 40) events.add(line);
    }

    // ------------------------------------------------------------------ perception

    /** Mode auto : on garde seulement la détection d'écran noir. */
    private void scanBlackOnly() {
        int[] f = CaptureService.frame;
        if (f == null) return;
        long sum = 0; int n = 0;
        for (int i = 0; i < f.length; i += 61) { int c = f[i]; sum += ((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255); n++; }
        boolean blk = n > 0 && sum / n < 10;
        if (blk && !blackScreen) event("Écran noir : le jeu bloque peut-être la capture");
        blackScreen = blk;
    }

    private void scan() {
        int[] f = CaptureService.frame;
        int fw = CaptureService.fw, fh = CaptureService.fh;
        px = sw / 2f; py = sh / 2f; pAssumed = true;
        if (f == null || fw == 0 || fh == 0) { chests = new ArrayList<>(); enemies = new ArrayList<>(); return; }
        float sx = sw / fw, sy = sh / fh;
        long sum = 0; int n = 0;
        for (int i = 0; i < f.length; i += 61) { int c = f[i]; sum += ((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255); n++; }
        boolean blk = n > 0 && sum / n < 10;
        if (blk && !blackScreen && on) event("Écran noir : le jeu bloque peut-être la capture");
        blackScreen = blk;
        if (cfg.player != null) {
            List<int[]> one = new ArrayList<>(); one.add(cfg.player);
            Vision.Blob best = null;
            for (Vision.Blob b : Vision.blobs(f, fw, fh, one, cfg.tol, 2, sx, sy))
                if (!own(b.x, b.y) && (best == null || b.n > best.n)) best = b;
            if (best != null) { px = best.x; py = best.y; pAssumed = false; }
        }
        chests = keep(Vision.blobs(f, fw, fh, cfg.chest, cfg.tol, 3, sx, sy));
        enemies = keep(Vision.blobs(f, fw, fh, cfg.enemy, cfg.tol, 3, sx, sy));
        // Coffre ramassé : on était dessus et il a disparu
        if (closeTo > 0 && now() - closeTo < 1600 && chests.size() < prevChestN && nearest(chests, 50) == null) {
            nChests++; closeTo = 0; status = "Coffre ramassé";
        }
        prevChestN = chests.size();
    }

    private List<Vision.Blob> keep(List<Vision.Blob> in) {
        List<Vision.Blob> out = new ArrayList<>();
        float r = Ui.dp(this, 34);
        for (Vision.Blob b : in) {
            if (own(b.x, b.y) || nearHud(b.x, b.y)) continue;
            boolean ign = false;
            for (float[] z : cfg.ignore) if (Math.hypot(b.x - z[0] * sw, b.y - z[1] * sh) < r) { ign = true; break; }
            if (!ign) out.add(b);
        }
        return out;
    }

    private Vision.Blob nearest(List<Vision.Blob> l, float max) {
        Vision.Blob best = null; double bd = max;
        for (Vision.Blob b : l) { double d = Math.hypot(b.x - px, b.y - py); if (d < bd) { bd = d; best = b; } }
        return best;
    }

    private boolean blacklisted(Vision.Blob b) {
        for (float[] k : black) if (Math.hypot(k[0] - b.x, k[1] - b.y) < Ui.dp(this, 40)) return true;
        return false;
    }

    private boolean own(float x, float y) { return inView(bubble, x, y) || inView(panel, x, y) || catcher != null; }

    private boolean inView(View v, float x, float y) {
        if (v == null || v.getWindowToken() == null) return false;
        int[] l = new int[2];
        v.getLocationOnScreen(l);
        int m = Ui.dp(this, 10);
        return x >= l[0] - m && y >= l[1] - m && x <= l[0] + v.getWidth() + m && y <= l[1] + v.getHeight() + m;
    }

    /** Près d'un bouton de sort ou du joystick : on n'y cherche pas de coffre et on n'y marche pas. */
    private boolean nearHud(float x, float y) {
        float r = Ui.dp(this, 46);
        for (float[] s : cfg.spells) if (Math.hypot(x - s[0] * sw, y - s[1] * sh) < r) return true;
        return cfg.joy != null && Math.hypot(x - cfg.joy[0] * sw, y - cfg.joy[1] * sh) < r * 1.8f;
    }

    /** Cherche un bouton dans l'arbre d'accessibilité (marche sur les jeux WebView et natifs). */
    private float[] findNode(Pattern want, int maxLen) {
        AccessibilityNodeInfo root;
        try { root = getRootInActiveWindow(); } catch (Exception e) { return null; }
        if (root == null || root.getPackageName() == null || root.getPackageName().toString().equals(getPackageName())) return null;
        ArrayDeque<AccessibilityNodeInfo> q = new ArrayDeque<>();
        q.add(root);
        int n = 0;
        Rect r = new Rect();
        while (!q.isEmpty() && n++ < 600) {
            AccessibilityNodeInfo node = q.poll();
            if (node == null) continue;
            CharSequence t = node.getText();
            if (t == null) t = node.getContentDescription();
            if (t != null && node.isVisibleToUser()) {
                String s = t.toString().trim();
                if (s.length() > 0 && s.length() <= maxLen && want.matcher(s).find() && !RX_BAD.matcher(s).find()) {
                    node.getBoundsInScreen(r);
                    if (r.width() > 8 && r.height() > 8 && !own(r.exactCenterX(), r.exactCenterY()))
                        return new float[]{r.exactCenterX(), r.exactCenterY()};
                }
            }
            for (int i = 0; i < node.getChildCount(); i++) {
                AccessibilityNodeInfo c = node.getChild(i);
                if (c != null) q.add(c);
            }
        }
        return null;
    }

    // ------------------------------------------------------------------ décision

    private void think() {
        long t = now();
        if (!cfg.auto && tick % 2 == 0) scan();
        for (int i = black.size() - 1; i >= 0; i--) if (t > black.get(i)[2]) black.remove(i);

        String eb = effectiveBrain();
        if (eb.equals("attente")) {
            joyWant = null; holdStart = null; hold2 = null;
            status = "L'IA découvre ton jeu…";
            ai.analyze(t);
            return;
        }
        if (ai.executing()) { ai.tickActions(t); return; }
        ai.audit(t);
        if (eb.equals("foot")) {
            if (cfg.popups && t - lastPopup > 700) {
                float[] pb = findNode(RX_POPUP, 28);
                if (pb != null) { tap(pb[0], pb[1]); nPopups++; lastPopup = t; return; }
            }
            foot.tick(t, CaptureService.frame);
            return;
        }
        if (eb.equals("ia")) { ai.tickDirect(t); return; }
        if (cfg.auto && auto.calibrating()) { auto.tick(t); return; }
        if (cfg.popups && t - lastPopup > 700) {
            float[] b = findNode(RX_POPUP, 28);
            if (b != null) { joyWant = null; tap(b[0], b[1]); nPopups++; lastPopup = t; status = "Ferme une popup"; return; }
        }
        if (cfg.autoChests && t - lastNodeChest > 1000) {
            lastNodeChest = t;
            float[] c = findNode(RX_CHEST, 30);
            if (c != null) { tap(c[0], c[1]); nChests++; status = "Coffre (bouton)"; }
        }
        if (cfg.auto) {
            if (!auto.calibrating() && tick % 2 == 0) scanBlackOnly();
            auto.tick(t);
            return;
        }
        if (cfg.autoSpells && t - lastSpell > cfg.spellEvery) castSpell(t);

        float near = Math.min(sw, sh) * 0.5f;
        Vision.Blob tg = null; String k = "explore";
        if (cfg.autoChests) {
            Vision.Blob best = null; double bd = 1e9;
            for (Vision.Blob c : chests) { if (blacklisted(c)) continue; double d = Math.hypot(c.x - px, c.y - py); if (d < bd) { bd = d; best = c; } }
            if (best != null) { tg = best; k = "chest"; }
        }
        if (cfg.hunt) {
            Vision.Blob e = nearest(enemies, 1e9f);
            if (e != null) {
                double de = Math.hypot(e.x - px, e.y - py);
                if (de < near * 0.55 && (tg == null || Math.hypot(tg.x - px, tg.y - py) > near * 0.5)) { tg = e; k = "enemy"; }
                else if (tg == null && de < near * 1.4) { tg = e; k = "enemy"; }
            }
        }
        if (!k.equals(kind)) { prog = false; detourUntil = 0; }
        kind = k;

        float fight = Ui.dp(this, 70);
        if (k.equals("chest")) {
            double d = Math.hypot(tg.x - px, tg.y - py);
            status = "Va au coffre";
            if (d < Ui.dp(this, 40)) closeTo = t;
            if (d < Ui.dp(this, 28) && t - lastChestTap > 800) { tap(tg.x, tg.y); lastChestTap = t; }
            steerTo(tg.x, tg.y);
        } else if (k.equals("enemy")) {
            if (Math.hypot(tg.x - px, tg.y - py) < fight) { status = "Combat"; joyWant = null; }
            else { status = "Va vers un ennemi"; steerTo(tg.x, tg.y); }
        } else if (cfg.explore) {
            if (t > wanderUntil) newWander();
            float r = Math.min(sw, sh) * 0.22f;
            status = "Explore";
            moveToward((float) (px + Math.cos(wanderA) * r), (float) (py + Math.sin(wanderA) * r));
        } else { status = "Attend"; joyWant = null; }

        // Blocage : on n'approche plus la cible -> on contourne, puis on abandonne
        if (tg != null && !(k.equals("enemy") && Math.hypot(tg.x - px, tg.y - py) < fight)) {
            float d = (float) Math.hypot(tg.x - px, tg.y - py);
            if (!prog) { prog = true; progBest = d; progT = t; progStart = t; progN = 0; progSide = Math.random() < .5 ? 1 : -1; }
            else if (d < progBest - Ui.dp(this, 8)) { progBest = d; progT = t; }
            else if (t - progT > 5000 || (t - progStart > 10000 && progBest > Ui.dp(this, 40))) {
                nStuck++;
                if (k.equals("chest")) black.add(new float[]{tg.x, tg.y, t + 8000});
                newWander(); prog = false; detourUntil = 0; kind = "explore";
                status = k.equals("chest") ? "Coffre inaccessible, je passe" : "Bloqué, je change de cap";
            } else if (t - progT > 900 && t > detourUntil + 500) {
                if (progN++ % 2 == 1) progSide = -progSide;
                detourSide = progSide;
                detourUntil = t + 1000 + (long) (Math.random() * 600);
                status = "Contourne un obstacle";
            }
        }
    }

    void steerTo(float tx, float ty) {
        if (now() < detourUntil) {
            double a = Math.atan2(ty - py, tx - px) + detourSide * 1.25;
            float r = Math.min(sw, sh) * 0.2f;
            moveToward((float) (px + Math.cos(a) * r), (float) (py + Math.sin(a) * r));
        } else moveToward(tx, ty);
    }

    private void newWander() { wanderA += 1.2 + Math.random() * 3.2; wanderUntil = now() + 2200 + (long) (Math.random() * 1800); }

    private void moveToward(float tx, float ty) {
        String m = cfg.move.equals("auto") ? (cfg.joy != null ? "joystick" : "toucher") : cfg.move;
        float dx = tx - px, dy = ty - py, L = (float) Math.hypot(dx, dy);
        if (m.equals("joystick") && cfg.joy != null) {
            if (L < 4) { joyWant = null; return; }
            float R = Ui.dp(this, 48), jx = cfg.joy[0] * sw, jy = cfg.joy[1] * sh;
            joyWant = new float[]{jx + dx / L * R, jy + dy / L * R};
            return;
        }
        joyWant = null;
        if (L > Ui.dp(this, 8) && now() - lastTapMove > 350) {
            float len = Math.min(L, Math.min(sw, sh) * 0.28f), mg = Ui.dp(this, 8);
            for (int i = 0; i < 4; i++, len *= 0.6f) {
                float x = Math.max(mg, Math.min(sw - mg, px + dx / L * len));
                float y = Math.max(mg, Math.min(sh - mg, py + dy / L * len));
                if (!own(x, y) && !nearHud(x, y)) { tap(x, y); lastTapMove = now(); break; }
            }
        }
    }

    private void castSpell(long t) {
        if (!cfg.enemy.isEmpty()) {
            if (nearest(enemies, Math.min(sw, sh) * 0.45f) == null) return;
        }
        if (cfg.spells.isEmpty()) {
            // Jeux WebView : boutons de sort lisibles dans l'arbre d'accessibilité
            if (t - lastNodeSpell < 1200) return;
            lastNodeSpell = t;
            float[] b = findNode(RX_SPELL, 24);
            if (b != null) { tap(b[0], b[1]); nSpells++; lastSpell = t; }
            return;
        }
        int n = cfg.spells.size();
        for (int k = 0; k < n; k++) {
            int i = (spellIdx + k) % n;
            float[] s = cfg.spells.get(i);
            if (ready(s)) {
                tap(s[0] * sw, s[1] * sh);
                spellIdx = (i + 1) % n; lastSpell = t; nSpells++;
                return;
            }
        }
    }

    /** Un sort est prêt s'il est presque aussi lumineux que quand on l'a appris. */
    boolean ready(float[] s) {
        int[] f = CaptureService.frame;
        if (f == null || s.length < 3 || s[2] <= 0) return true;
        float l = Vision.luma(f, CaptureService.fw, CaptureService.fh, s[0] * CaptureService.fw, s[1] * CaptureService.fh, 3);
        return l < 0 || l >= s[2] * 0.78f;
    }

    // ------------------------------------------------------------------ gestes

    void tap(float x, float y) {
        if (own(x, y)) return;
        Path p = new Path();
        p.moveTo(x, y);
        pend.add(new GestureDescription.StrokeDescription(p, 0, 55));
        nTaps++;
        tapsShown.add(new float[]{x, y, now()});
        if (tapsShown.size() > 12) tapsShown.remove(0);
    }

    /** Envoie les gestes de ce tour : joystick maintenu + touchers, en un seul geste multi-doigts. */
    private long inFlightSince;
    private boolean wig;
    int nGestOk, nGestFail;
    /** Derniers touchers, pour la vue du bot : x, y, instant. */
    final List<float[]> tapsShown = new ArrayList<>();

    private void flush() {
        long t = now();
        // Garde-fou : si Android ne répond jamais, on ne reste pas bloqué
        if (inFlight && t - inFlightSince > 1500) { inFlight = false; f1.stroke = null; f2.stroke = null; }
        if (inFlight) return;
        List<GestureDescription.StrokeDescription> strokes = new ArrayList<>(pend);
        pend.clear();
        try {
            float[] s1 = null, w1 = null;
            if (joyWant != null) {
                if (holdStart != null) s1 = holdStart;
                else if (cfg.joy != null) s1 = new float[]{cfg.joy[0] * sw, cfg.joy[1] * sh};
                if (s1 != null) w1 = joyWant;
            }
            finger(f1, s1, w1, strokes);
            finger(f2, hold2, hold2, strokes);
        } catch (Exception e) {
            f1.stroke = null; f2.stroke = null;
            gestFail("geste tenu invalide");
        }
        if (strokes.isEmpty()) return;
        GestureDescription.Builder b = new GestureDescription.Builder();
        int max = Math.min(strokes.size(), GestureDescription.getMaxStrokeCount());
        for (int i = 0; i < max; i++) b.addStroke(strokes.get(i));
        inFlight = true; inFlightSince = t;
        boolean ok;
        try {
            ok = dispatchGesture(b.build(), new GestureResultCallback() {
                @Override public void onCompleted(GestureDescription g) { inFlight = false; nGestOk++; }
                @Override public void onCancelled(GestureDescription g) { inFlight = false; f1.stroke = null; f2.stroke = null; gestFail("geste annulé par Android"); }
            }, null);
        } catch (Exception e) { ok = false; }
        if (!ok) { inFlight = false; f1.stroke = null; f2.stroke = null; gestFail("geste refusé par Android"); }
    }

    /**
     * Fait vivre un doigt tenu : le pose (départ -> cible), le fait glisser, ou le relève.
     * La suite d'un geste doit partir exactement du point d'arrêt précédent, et jamais avoir une longueur nulle.
     */
    private void finger(Finger f, float[] start, float[] want, List<GestureDescription.StrokeDescription> out) {
        if (want != null && f.stroke != null && Math.abs(start[0] - f.sx) + Math.abs(start[1] - f.sy) > 4) {
            endFinger(f, out); // on change de bouton : on relève, on reposera au tour suivant
            return;
        }
        if (want != null) {
            float tx = want[0], ty = want[1];
            Path p = new Path();
            if (f.stroke == null) {
                if (Math.abs(tx - start[0]) + Math.abs(ty - start[1]) < 1.5f) tx += 2;
                p.moveTo(start[0], start[1]);
                p.lineTo(tx, ty);
                f.stroke = new GestureDescription.StrokeDescription(p, 0, 60, true);
                f.sx = start[0]; f.sy = start[1];
            } else {
                if (Math.abs(tx - f.lx) + Math.abs(ty - f.ly) < 1.5f) { f.wig = !f.wig; tx += f.wig ? 2 : -2; }
                p.moveTo(f.lx, f.ly);
                p.lineTo(tx, ty);
                f.stroke = f.stroke.continueStroke(p, 0, 60, true);
            }
            f.lx = tx; f.ly = ty;
            out.add(f.stroke);
        } else if (f.stroke != null) endFinger(f, out);
    }

    private void endFinger(Finger f, List<GestureDescription.StrokeDescription> out) {
        Path p = new Path();
        p.moveTo(f.lx, f.ly);
        p.lineTo(f.lx + 2, f.ly);
        out.add(f.stroke.continueStroke(p, 0, 40, false));
        f.stroke = null;
    }

    private void gestFail(String why) {
        nGestFail++;
        if (nGestFail == 1 || nGestFail == 20 || nGestFail == 200) event("Touchers : " + why + " (" + nGestFail + " fois)");
    }

    // ------------------------------------------------------------------ détection des plantages

    @Override
    public void onAccessibilityEvent(AccessibilityEvent e) {
        if (e == null || e.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || e.getPackageName() == null) return;
        String pkg = e.getPackageName().toString();
        if (pkg.equals(getPackageName()) || pkg.equals("com.android.systemui") || pkg.contains("inputmethod")
                || pkg.contains("keyboard") || pkg.startsWith("com.google.android.gms")) return;
        if (!on || gamePkg == null) return;
        String cls = String.valueOf(e.getClassName());
        if (pkg.equals("android")) {
            if (cls.contains("AppNotResponding")) event("Le jeu ne répond plus (ANR)");
            else if (cls.contains("AppError") || cls.contains("Dialog")) event("Fenêtre d'erreur Android (plantage ?)");
            return;
        }
        if (!pkg.equals(gamePkg)) {
            event("Le jeu a quitté l'écran (fermé ou planté ?) → " + labelOf(pkg));
            stop();
            toast("Le jeu n'est plus à l'écran : bot en pause");
        }
    }

    // ------------------------------------------------------------------ rapport

    String report() {
        StringBuilder s = new StringBuilder();
        s.append("TESTBOT — rapport de test\n");
        s.append("Jeu : ").append(gameLabel).append(gamePkg != null ? " (" + gamePkg + ")" : "").append('\n');
        s.append("Date : ").append(new SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.FRANCE).format(new Date())).append('\n');
        s.append("Durée de jeu du bot : ").append(elapsed()).append('\n');
        s.append("Sorts lancés : ").append(nSpells).append('\n');
        s.append("Coffres ramassés : ").append(nChests).append('\n');
        s.append("Popups fermées : ").append(nPopups).append('\n');
        s.append("Blocages : ").append(nStuck).append('\n');
        s.append("Morts du perso : ").append(nDeaths).append('\n');
        s.append("Cerveau : ").append(brainName(effectiveBrain())).append(cfg.brain.equals("auto") ? " (choisi automatiquement)" : "").append('\n');
        if (!cfg.aiDesc.isEmpty()) s.append("L'IA a compris : ").append(cfg.aiDesc).append('\n');
        if (!cfg.aiGoal.isEmpty()) s.append("Objectif selon l'IA : ").append(cfg.aiGoal).append('\n');
        s.append("IA : ").append(ai.hasKey() ? ai.calls + " appel(s), " + ai.tokIn + " jetons lus / " + ai.tokOut + " écrits, " + ai.errors + " erreur(s)" : "pas de clé (cerveaux réflexes seulement)").append('\n');
        s.append("Mode RPG : ").append(cfg.auto ? "auto (" + (cfg.calibrated ? "calibré, " + cfg.spells.size() + " sort(s), " + cfg.move : "pas encore calibré") + ")" : "appris à la main").append('\n');
        s.append("Touchers envoyés : ").append(nTaps).append('\n');
        s.append("Gestes acceptés / refusés par Android : ").append(nGestOk).append(" / ").append(nGestFail).append('\n');
        s.append("Image de l'écran : ").append(CaptureService.frame == null ? "aucune reçue" : CaptureService.fw + "x" + CaptureService.fh + ", il y a " + (now() - CaptureService.frameTime) + " ms").append('\n');
        s.append("Vue de l'écran : ").append(!CaptureService.running() ? "désactivée" : blackScreen ? "écran noir (capture bloquée)" : "OK").append('\n');
        s.append("Alertes (").append(events.size()).append(") :\n");
        if (events.isEmpty()) s.append("  aucune\n");
        for (String ev : events) s.append("  - ").append(ev).append('\n');
        return s.toString();
    }

    // ------------------------------------------------------------------ interface flottante

    private WindowManager.LayoutParams overlayLp(int w, int hgt) {
        WindowManager.LayoutParams p = new WindowManager.LayoutParams(w, hgt,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        p.gravity = Gravity.TOP | Gravity.START;
        return p;
    }

    private void add(View v, WindowManager.LayoutParams lp) { try { wm.addView(v, lp); } catch (Exception ignored) {} }
    private void remove(View v) { try { if (v != null && v.getWindowToken() != null) wm.removeView(v); } catch (Exception ignored) {} }

    SightView sight;

    /** Calque transparent qui montre ce que le bot voit et fait (ne bloque aucun toucher). */
    void showSight() {
        if (wm == null || !cfg.showSight) return;
        if (sight == null) sight = new SightView(this);
        if (sight.getWindowToken() != null) return;
        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.START;
        if (Build.VERSION.SDK_INT >= 28) lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        // Le calque passe sous la bulle : on l'ajoute, puis on remet la bulle au-dessus
        add(sight, lp);
        if (bubble != null && bubble.getWindowToken() != null) { remove(bubble); add(bubble, bubbleLp); }
    }

    void hideSight() { remove(sight); }

    void showBubble() {
        if (wm == null) return;
        remove(panel);
        if (bubble == null) buildBubble();
        if (bubble.getWindowToken() == null) add(bubble, bubbleLp);
        refreshUi();
    }

    private void showPanel() {
        remove(bubble);
        if (panel == null) buildPanel();
        if (panel.getWindowToken() == null) add(panel, panelLp);
        refreshUi();
    }

    void hideAll() { remove(bubble); remove(panel); remove(catcher); remove(sight); catcher = null; }

    boolean visible() { return (bubble != null && bubble.getWindowToken() != null) || (panel != null && panel.getWindowToken() != null); }

    private void buildBubble() {
        int s = Ui.dp(this, 56);
        bubble = Ui.mono(this, "BOT", 13, Ui.FG);
        bubble.setGravity(Gravity.CENTER);
        bubble.setLetterSpacing(0.12f);
        bubble.setBackground(Ui.box(this, Ui.BG, 28, Ui.LINE));
        bubble.setElevation(Ui.dp(this, 6));
        bubbleLp = overlayLp(s, s);
        SharedPreferences p = Cfg.prefs(this);
        bubbleLp.x = p.getInt("bx", (int) sw - s - Ui.dp(this, 12));
        bubbleLp.y = p.getInt("by", Ui.dp(this, 120));
        draggable(bubble, bubbleLp, this::showPanel);
    }

    private interface Tap { void run(); }

    private void draggable(View v, WindowManager.LayoutParams lp, Tap onTap) {
        final float[] st = new float[4];
        final boolean[] moved = {false};
        v.setOnTouchListener((view, e) -> {
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    st[0] = e.getRawX(); st[1] = e.getRawY(); st[2] = lp.x; st[3] = lp.y; moved[0] = false;
                    view.setAlpha(0.8f);
                    return true;
                case MotionEvent.ACTION_MOVE:
                    float dx = e.getRawX() - st[0], dy = e.getRawY() - st[1];
                    if (!moved[0] && Math.hypot(dx, dy) < Ui.dp(this, 6)) return true;
                    moved[0] = true;
                    lp.x = (int) Math.max(0, Math.min(sw - Ui.dp(this, 40), st[2] + dx));
                    lp.y = (int) Math.max(0, Math.min(sh - Ui.dp(this, 40), st[3] + dy));
                    try { wm.updateViewLayout(lp == bubbleLp ? bubble : panel, lp); } catch (Exception ignored) {}
                    return true;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    view.setAlpha(1f);
                    if (moved[0]) {
                        String kx = lp == bubbleLp ? "bx" : "px", ky = lp == bubbleLp ? "by" : "py";
                        Cfg.prefs(this).edit().putInt(kx, lp.x).putInt(ky, lp.y).apply();
                    } else if (e.getActionMasked() == MotionEvent.ACTION_UP && onTap != null) onTap.run();
                    return true;
            }
            return false;
        });
    }

    private void buildPanel() {
        int pad = Ui.dp(this, 12);
        panel = Ui.col(this);
        panel.setBackground(Ui.box(this, Ui.BG, 16, Ui.LINE));
        panel.setPadding(pad, pad, pad, pad);
        panel.setElevation(Ui.dp(this, 10));

        // En-tête (sert aussi à déplacer le panneau)
        LinearLayout hd = Ui.row(this);
        TextView logo = Ui.mono(this, "TESTBOT", 14, Ui.FG);
        logo.setLetterSpacing(0.16f);
        tGame = Ui.text(this, "", 12, Ui.MUTE, false);
        tGame.setSingleLine(true);
        tGame.setPadding(Ui.dp(this, 8), 0, 0, 0);
        TextView min = Ui.text(this, "–", 22, Ui.MUTE, true);
        min.setPadding(Ui.dp(this, 12), 0, Ui.dp(this, 6), 0);
        min.setOnClickListener(v -> showBubble());
        TextView close = Ui.text(this, "✕", 17, Ui.MUTE, true);
        close.setPadding(Ui.dp(this, 10), 0, Ui.dp(this, 2), 0);
        close.setOnClickListener(v -> { stop(); hideAll(); toast("Bot masqué. Rouvre-le depuis l'appli TestBot."); });
        hd.addView(logo, Ui.wrap());
        hd.addView(tGame, Ui.weight(1));
        hd.addView(min, Ui.wrap());
        hd.addView(close, Ui.wrap());
        panel.addView(hd, Ui.full());

        tGo = Ui.button(this, "Lancer", Ui.AMBER, Ui.INK, 0);
        tGo.setTextSize(16);
        tGo.setOnClickListener(v -> { if (on) stop(); else start(); });
        panel.addView(tGo, Ui.margins(Ui.full(), this, 0, 10, 0, 0));

        LinearLayout st = Ui.row(this);
        tStatus = Ui.text(this, status, 13, Ui.FG, true);
        tStatus.setSingleLine(true);
        tTime = Ui.mono(this, "0 min 00 s", 12, Ui.MUTE);
        st.addView(tStatus, Ui.weight(1));
        st.addView(tTime, Ui.wrap());
        panel.addView(st, Ui.margins(Ui.full(), this, 2, 8, 2, 0));

        LinearLayout stats = Ui.row(this);
        vChest = stat(stats, "Coffres", true);
        vSpell = stat(stats, "Sorts", true);
        vStuck = stat(stats, "Blocages", true);
        vAlert = stat(stats, "Alertes", false);
        panel.addView(stats, Ui.margins(Ui.full(), this, 0, 8, 0, 0));

        tabBar = Ui.row(this);
        tabBar.setBackground(Ui.box(this, Ui.CARD, 11, 0));
        tabBar.setPadding(Ui.dp(this, 3), Ui.dp(this, 3), Ui.dp(this, 3), Ui.dp(this, 3));
        String[][] tabs = {{"learn", "Apprendre"}, {"set", "Réglages"}, {"rep", "Rapport"}};
        for (String[] tb : tabs) {
            TextView b = Ui.text(this, tb[1], 13, Ui.MUTE, true);
            b.setGravity(Gravity.CENTER);
            b.setPadding(0, Ui.dp(this, 8), 0, Ui.dp(this, 8));
            b.setTag(tb[0]);
            b.setOnClickListener(v -> { tab = tab.equals(v.getTag()) ? "" : (String) v.getTag(); buildPane(); });
            tabBtns.add(b);
            tabBar.addView(b, Ui.weight(1));
        }
        panel.addView(tabBar, Ui.margins(Ui.full(), this, 0, 10, 0, 0));

        paneScroll = new ScrollView(this);
        pane = Ui.col(this);
        paneScroll.addView(pane);
        panel.addView(paneScroll, Ui.full());

        panelLp = overlayLp(Ui.dp(this, 300), WindowManager.LayoutParams.WRAP_CONTENT);
        SharedPreferences p = Cfg.prefs(this);
        panelLp.x = p.getInt("px", Math.max(0, (int) sw - Ui.dp(this, 312)));
        panelLp.y = p.getInt("py", Ui.dp(this, 80));
        draggable(hd, panelLp, null);
        buildPane();
    }

    private TextView stat(LinearLayout parent, String label, boolean gap) {
        LinearLayout c = Ui.col(this);
        c.setBackground(Ui.box(this, Ui.CARD, 10, 0));
        c.setPadding(Ui.dp(this, 8), Ui.dp(this, 6), Ui.dp(this, 6), Ui.dp(this, 6));
        TextView v = Ui.mono(this, "0", 17, Ui.FG);
        TextView l = Ui.text(this, label.toUpperCase(Locale.FRANCE), 9, Ui.MUTE, true);
        l.setLetterSpacing(0.06f);
        c.addView(v); c.addView(l);
        parent.addView(c, Ui.margins(Ui.weight(1), this, 0, 0, gap ? 5 : 0, 0));
        return v;
    }

    private ScrollView paneScroll;

    private void buildPane() {
        if (pane == null) return;
        pane.removeAllViews();
        // Hauteur bornée : en paysage le panneau ne doit jamais sortir de l'écran
        if (paneScroll != null) {
            paneScroll.setVisibility(tab.isEmpty() ? View.GONE : View.VISIBLE);
            LinearLayout.LayoutParams lp = (LinearLayout.LayoutParams) paneScroll.getLayoutParams();
            lp.height = (int) Math.min(Ui.dp(this, 300), sh * 0.42f);
            paneScroll.setLayoutParams(lp);
        }
        for (TextView b : tabBtns) {
            boolean sel = tab.equals(b.getTag());
            b.setTextColor(sel ? Ui.FG : Ui.MUTE);
            b.setBackground(sel ? Ui.box(this, Ui.CARD2, 8, 0) : null);
        }
        tReport = null;
        if (tab.equals("learn")) buildLearn();
        else if (tab.equals("set")) buildSettings();
        else if (tab.equals("rep")) buildReport();
    }

    private void buildLearn() {
        String autoTxt = cfg.auto
                ? (cfg.calibrated ? "Mode auto : jeu déjà calibré (" + cfg.spells.size() + " sort(s), déplacement " + cfg.move + "). Rien à faire, ou corrige ci-dessous." : "Mode auto : au lancement je calibre seul (≈15 s). Rien à faire.")
                : "Appuie sur un bouton puis touche l'élément dans le jeu. Pour un sort, touche-le quand il est prêt.";
        pane.addView(Ui.text(this, autoTxt, 12, cfg.auto ? Ui.CYAN : Ui.MUTE, false), Ui.margins(Ui.full(), this, 2, 10, 2, 4));
        if (ai.hasKey()) {
            TextView an = Ui.button(this, "Faire réanalyser le jeu par l'IA", Ui.CARD, Ui.CYAN, Ui.LINE);
            an.setOnClickListener(v -> { cfg.genre = ""; ai.reset(); save(); buildPane(); toast(on ? "L'IA regarde le jeu" : "L'IA regardera le jeu au lancement"); });
            pane.addView(an, Ui.margins(Ui.full(), this, 0, 4, 0, 4));
        }
        if (cfg.auto) {
            TextView rc = Ui.button(this, "Refaire le calibrage", Ui.CARD, Ui.FG, Ui.LINE);
            rc.setOnClickListener(v -> { auto.recalibrate(); buildPane(); toast(on ? "Calibrage relancé" : "Calibrage au prochain lancement"); });
            pane.addView(rc, Ui.margins(Ui.full(), this, 0, 4, 0, 4));
        }
        String[][] items = {
                {"chest", "Coffre", cfg.chest.size() + " couleur(s)"},
                {"enemy", "Ennemi", cfg.enemy.size() + " couleur(s)"},
                {"player", "Mon perso", cfg.player != null ? "suivi couleur" : "centre écran"},
                {"spell", "Sort", cfg.spells.size() + " appris"},
                {"joystick", "Joystick", cfg.joy != null ? "appris" : "aucun"},
                {"ignore", "Ignorer zone", cfg.ignore.size() + " zone(s)"},
                {"ball", "Balle", cfg.ball != null ? "apprise" : "rien"},
                {"car", "Ma voiture", cfg.car != null ? "apprise" : "rien"},
                {"jump", "Saut", cfg.jump != null ? "appris" : "aucun"},
                {"boost", "Boost", cfg.boost != null ? "appris" : "aucun"},
                {"left", "Bouton gauche", cfg.left != null ? "appris" : "aucun"},
                {"right", "Bouton droite", cfg.right != null ? "appris" : "aucun"}};
        LinearLayout r = null;
        for (int i = 0; i < items.length; i++) {
            if (i % 2 == 0) { r = Ui.row(this); pane.addView(r, Ui.margins(Ui.full(), this, 0, 6, 0, 0)); }
            final String what = items[i][0];
            LinearLayout b = Ui.col(this);
            b.setBackground(Ui.box(this, Ui.CARD, 10, Ui.LINE));
            b.setPadding(Ui.dp(this, 10), Ui.dp(this, 8), Ui.dp(this, 8), Ui.dp(this, 8));
            b.addView(Ui.text(this, items[i][1], 14, Ui.FG, true));
            b.addView(Ui.text(this, items[i][2], 11, Ui.MUTE, false));
            Ui.pressable(b);
            b.setOnClickListener(v -> startLearn(what));
            r.addView(b, Ui.margins(Ui.weight(1), this, 0, 0, i % 2 == 0 ? 6 : 0, 0));
        }
        LinearLayout tol = Ui.row(this);
        TextView tl = Ui.text(this, "Tolérance couleur : " + cfg.tol, 13, Ui.FG, false);
        tol.addView(tl, Ui.weight(1));
        tol.addView(small("−", v -> { cfg.tol = Math.max(12, cfg.tol - 6); save(); buildPane(); }));
        tol.addView(small("+", v -> { cfg.tol = Math.min(96, cfg.tol + 6); save(); buildPane(); }));
        pane.addView(tol, Ui.margins(Ui.full(), this, 2, 10, 0, 0));
        TextView wipe = Ui.text(this, "Tout effacer pour ce jeu", 13, Ui.CORAL, true);
        wipe.setPadding(0, Ui.dp(this, 10), 0, Ui.dp(this, 4));
        wipe.setOnClickListener(v -> {
            if (now() - wipeArmed > 2500) { wipeArmed = now(); ((TextView) v).setText("Touche encore pour confirmer"); return; }
            cfg.clearLearned(); save(); wipeArmed = 0; buildPane(); toast("Apprentissage effacé");
        });
        pane.addView(wipe, Ui.full());
    }

    private TextView small(String s, View.OnClickListener l) {
        TextView b = Ui.button(this, s, Ui.CARD, Ui.FG, Ui.LINE);
        b.setPadding(Ui.dp(this, 14), Ui.dp(this, 4), Ui.dp(this, 14), Ui.dp(this, 4));
        b.setTextSize(17);
        b.setOnClickListener(l);
        LinearLayout.LayoutParams lp = Ui.wrap();
        lp.leftMargin = Ui.dp(this, 6);
        b.setLayoutParams(lp);
        return b;
    }

    private void buildSettings() {
        LinearLayout br = Ui.row(this);
        br.addView(Ui.text(this, "Cerveau", 14, Ui.FG, false), Ui.weight(1));
        String bl = cfg.brain.equals("auto") ? "Auto (" + brainName(effectiveBrain()) + ")" : brainName(cfg.brain);
        br.addView(small(bl, v -> {
            cfg.brain = cfg.brain.equals("auto") ? "rpg" : cfg.brain.equals("rpg") ? "foot" : cfg.brain.equals("foot") ? "ia" : "auto";
            joyWant = null; holdStart = null; hold2 = null; save(); buildPane();
        }));
        pane.addView(br, Ui.margins(Ui.full(), this, 2, 8, 0, 0));
        LinearLayout at = Ui.row(this);
        at.addView(Ui.text(this, "Foot : j'attaque vers", 14, Ui.FG, false), Ui.weight(1));
        at.addView(small(cfg.attack < 0 ? "la gauche" : cfg.attack > 0 ? "la droite" : "? (droite)", v -> {
            cfg.attack = cfg.attack > 0 ? -1 : 1; save(); buildPane();
        }));
        pane.addView(at, Ui.margins(Ui.full(), this, 2, 4, 0, 0));
        pane.addView(toggle("Mode auto RPG (découvre le jeu seul)", cfg.auto, v -> { cfg.auto = !cfg.auto; if (on) { auto.stop(); if (cfg.auto) auto.begin(now()); } }), Ui.full());
        pane.addView(toggle("Montrer ce que voit le bot", cfg.showSight, v -> { cfg.showSight = !cfg.showSight; if (cfg.showSight) showSight(); else hideSight(); }), Ui.full());
        pane.addView(toggle("Lancer les sorts", cfg.autoSpells, v -> { cfg.autoSpells = !cfg.autoSpells; }), Ui.full());
        pane.addView(toggle("Ramasser les coffres", cfg.autoChests, v -> { cfg.autoChests = !cfg.autoChests; }), Ui.full());
        pane.addView(toggle("Aller vers les ennemis", cfg.hunt, v -> { cfg.hunt = !cfg.hunt; }), Ui.full());
        pane.addView(toggle("Explorer si rien à faire", cfg.explore, v -> { cfg.explore = !cfg.explore; }), Ui.full());
        pane.addView(toggle("Fermer les popups de gain", cfg.popups, v -> { cfg.popups = !cfg.popups; }), Ui.full());
        LinearLayout mv = Ui.row(this);
        mv.addView(Ui.text(this, "Déplacement", 14, Ui.FG, false), Ui.weight(1));
        String lbl = cfg.move.equals("auto") ? "Auto" : cfg.move.equals("joystick") ? "Joystick" : "Toucher";
        mv.addView(small(lbl, v -> {
            cfg.move = cfg.move.equals("auto") ? "joystick" : cfg.move.equals("joystick") ? "toucher" : "auto";
            joyWant = null; save(); buildPane();
        }));
        pane.addView(mv, Ui.margins(Ui.full(), this, 2, 6, 0, 0));
        LinearLayout rate = Ui.row(this);
        rate.addView(Ui.text(this, String.format(Locale.FRANCE, "Un sort toutes les %.1f s", cfg.spellEvery / 1000f), 14, Ui.FG, false), Ui.weight(1));
        rate.addView(small("−", v -> { cfg.spellEvery = Math.max(200, cfg.spellEvery - 100); save(); buildPane(); }));
        rate.addView(small("+", v -> { cfg.spellEvery = Math.min(4000, cfg.spellEvery + 100); save(); buildPane(); }));
        pane.addView(rate, Ui.margins(Ui.full(), this, 2, 8, 0, 4));
    }

    private View toggle(String label, boolean val, View.OnClickListener l) {
        LinearLayout r = Ui.row(this);
        r.setPadding(Ui.dp(this, 2), Ui.dp(this, 7), Ui.dp(this, 2), Ui.dp(this, 7));
        r.addView(Ui.text(this, label, 14, Ui.FG, false), Ui.weight(1));
        TextView pill = Ui.mono(this, val ? "ON" : "OFF", 12, val ? Ui.INK : Ui.MUTE);
        pill.setGravity(Gravity.CENTER);
        pill.setPadding(Ui.dp(this, 10), Ui.dp(this, 4), Ui.dp(this, 10), Ui.dp(this, 4));
        pill.setBackground(Ui.box(this, val ? Ui.AMBER : Ui.CARD2, 99, 0));
        r.addView(pill, Ui.wrap());
        r.setOnClickListener(v -> { l.onClick(v); save(); buildPane(); });
        return r;
    }

    private void buildReport() {
        tReport = Ui.mono(this, report(), 11, Ui.FG);
        tReport.setTypeface(Typeface.MONOSPACE);
        tReport.setBackground(Ui.box(this, Ui.CARD, 10, 0));
        tReport.setPadding(Ui.dp(this, 10), Ui.dp(this, 8), Ui.dp(this, 10), Ui.dp(this, 8));
        tReport.setMaxLines(16);
        pane.addView(tReport, Ui.margins(Ui.full(), this, 0, 10, 0, 0));
        LinearLayout r = Ui.row(this);
        TextView copy = Ui.button(this, "Copier", Ui.CARD, Ui.FG, Ui.LINE);
        copy.setOnClickListener(v -> {
            ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
            cm.setPrimaryClip(ClipData.newPlainText("Rapport TestBot", report()));
            Cfg.prefs(this).edit().putString("last_report", report()).apply();
            toast("Rapport copié");
        });
        TextView share = Ui.button(this, "Partager", Ui.CARD, Ui.FG, Ui.LINE);
        share.setOnClickListener(v -> {
            Intent s = new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, report());
            Intent c = Intent.createChooser(s, "Envoyer le rapport");
            c.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            try { startActivity(c); showBubble(); } catch (Exception e) { toast("Partage impossible"); }
        });
        TextView reset = Ui.button(this, "Remise à zéro", Ui.CARD, Ui.CORAL, Ui.LINE);
        reset.setOnClickListener(v -> { resetStats(); buildPane(); });
        r.addView(copy, Ui.margins(Ui.weight(1), this, 0, 0, 6, 0));
        r.addView(share, Ui.margins(Ui.weight(1), this, 0, 0, 6, 0));
        r.addView(reset, Ui.weight(1.3f));
        pane.addView(r, Ui.margins(Ui.full(), this, 0, 8, 0, 4));
    }

    private void save() { cfg.save(this, gamePkg); }
    void saveCfg() { save(); }
    static float dpS(BotService s, float v) { return Ui.dp(s, v); }

    private void refreshUi() {
        if (bubble != null) {
            bubble.setBackground(Ui.box(this, Ui.BG, 28, on ? Ui.AMBER : Ui.LINE));
            bubble.setTextColor(on ? Ui.AMBER : Ui.FG);
        }
        if (panel == null || panel.getWindowToken() == null) return;
        tGame.setText(gameLabel);
        tGo.setText(on ? "Arrêter" : "Lancer");
        tGo.setBackground(Ui.box(this, on ? Ui.BG : Ui.AMBER, 11, on ? Ui.CORAL : 0));
        tGo.setTextColor(on ? Ui.CORAL : Ui.INK);
        tStatus.setText(on ? status : (CaptureService.running() ? "Prêt, en pause" : "Vue de l'écran non autorisée"));
        tTime.setText(elapsed());
        vChest.setText(String.valueOf(nChests));
        vSpell.setText(String.valueOf(nSpells));
        vStuck.setText(String.valueOf(nStuck));
        vAlert.setText(String.valueOf(events.size()));
        vAlert.setTextColor(events.isEmpty() ? Ui.FG : Ui.CORAL);
        if (tReport != null) tReport.setText(report());
    }

    // ------------------------------------------------------------------ apprentissage

    private static final String[][] LEARN_TXT = {
            {"chest", "Touche un COFFRE dans le jeu"}, {"enemy", "Touche un ENNEMI"},
            {"player", "Touche TON PERSO"}, {"spell", "Touche un SORT prêt"},
            {"joystick", "Touche le CENTRE du joystick"}, {"ignore", "Touche la zone à IGNORER"},
            {"ball", "Touche la BALLE"}, {"car", "Touche TA VOITURE (sur la couleur)"},
            {"jump", "Touche le bouton SAUT"}, {"boost", "Touche le bouton BOOST"},
            {"left", "Touche le bouton GAUCHE"}, {"right", "Touche le bouton DROITE"}};

    private void startLearn(String what) {
        boolean needsEyes = what.equals("chest") || what.equals("enemy") || what.equals("player") || what.equals("spell") || what.equals("ball") || what.equals("car");
        if (!CaptureService.running() && needsEyes) {
            toast("Autorise d'abord la vue de l'écran dans l'appli TestBot");
            return;
        }
        learn = what;
        remove(panel);
        remove(bubble);
        catcher = new FrameLayout(this);
        catcher.setBackgroundColor(Color.TRANSPARENT);
        LinearLayout bar = Ui.row(this);
        bar.setBackground(Ui.box(this, Ui.AMBER, 12, 0));
        bar.setPadding(Ui.dp(this, 14), Ui.dp(this, 11), Ui.dp(this, 14), Ui.dp(this, 11));
        String txt = "";
        for (String[] l : LEARN_TXT) if (l[0].equals(what)) txt = l[1];
        bar.addView(Ui.text(this, txt, 15, Ui.INK, true), Ui.weight(1));
        TextView cancel = Ui.text(this, "Annuler", 14, Ui.INK, true);
        cancel.setPaintFlags(cancel.getPaintFlags() | android.graphics.Paint.UNDERLINE_TEXT_FLAG);
        cancel.setOnClickListener(v -> endLearn());
        bar.addView(cancel, Ui.wrap());
        FrameLayout.LayoutParams blp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP);
        int m = Ui.dp(this, 14);
        blp.setMargins(m, Ui.dp(this, 36), m, 0);
        catcher.addView(bar, blp);
        catcher.setOnTouchListener((v, e) -> {
            if (e.getActionMasked() == MotionEvent.ACTION_DOWN) { learnAt(e.getRawX(), e.getRawY()); return true; }
            return true;
        });
        WindowManager.LayoutParams lp = overlayLp(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT);
        lp.flags |= WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;
        if (Build.VERSION.SDK_INT >= 28) lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        add(catcher, lp);
    }

    private void learnAt(float x, float y) {
        String what = learn;
        int[] f = CaptureService.frame;
        int fw = CaptureService.fw, fh = CaptureService.fh;
        float fx = x / sw, fy = y / sh;
        int[] col = f != null ? Vision.sample(f, fw, fh, fx * fw, fy * fh) : null;
        String msg;
        switch (what) {
            case "joystick": cfg.joy = new float[]{fx, fy}; msg = "Joystick appris"; break;
            case "ignore": cfg.ignore.add(new float[]{fx, fy}); msg = "Zone ignorée"; break;
            case "jump": cfg.jump = new float[]{fx, fy}; msg = "Saut appris"; break;
            case "boost": cfg.boost = new float[]{fx, fy}; msg = "Boost appris"; break;
            case "left": cfg.left = new float[]{fx, fy}; msg = "Bouton gauche appris"; break;
            case "right": cfg.right = new float[]{fx, fy}; msg = "Bouton droite appris"; break;
            case "ball": cfg.ball = col; msg = col != null ? "Balle apprise" : "Je ne vois pas l'écran ici"; break;
            case "car": cfg.car = col; msg = col != null ? "Voiture apprise" : "Je ne vois pas l'écran ici"; break;
            case "spell": {
                float l = f != null ? Vision.luma(f, fw, fh, fx * fw, fy * fh, 3) : -1;
                cfg.spells.add(new float[]{fx, fy, l});
                msg = "Sort " + cfg.spells.size() + " appris";
                break;
            }
            default:
                if (col == null) { msg = "Je ne vois pas l'écran ici"; break; }
                if (what.equals("chest")) cfg.chest.add(col);
                else if (what.equals("enemy")) cfg.enemy.add(col);
                else cfg.player = col;
                msg = (what.equals("chest") ? "Coffre" : what.equals("enemy") ? "Ennemi" : "Perso") + " appris";
        }
        save();
        toast(msg);
        endLearn();
    }

    private void endLearn() {
        learn = null;
        remove(catcher);
        catcher = null;
        showPanel();
        buildPane();
    }

    private void toast(String m) { h.post(() -> Toast.makeText(this, m, Toast.LENGTH_SHORT).show()); }

    /** Pour l'écran principal : résumé de ce qui est appris. */
    String learnedSummary() {
        List<String> l = new ArrayList<>();
        if (!cfg.chest.isEmpty()) l.add(cfg.chest.size() + " coffre(s)");
        if (!cfg.enemy.isEmpty()) l.add(cfg.enemy.size() + " ennemi(s)");
        if (!cfg.spells.isEmpty()) l.add(cfg.spells.size() + " sort(s)");
        if (cfg.joy != null) l.add("joystick");
        if (l.isEmpty()) return cfg.auto ? "Mode auto, pas encore calibré" : "Rien d'appris pour l'instant";
        if (cfg.auto) l.add(0, "mode auto");
        return "Appris : " + String.join(", ", l);
    }
}
