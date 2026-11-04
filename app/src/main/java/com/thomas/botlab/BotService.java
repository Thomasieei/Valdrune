package com.thomas.botlab;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.graphics.Color;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.PointF;
import android.graphics.RectF;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import java.util.ArrayList;
import java.util.List;

/** Service d'accessibilité : bulle de contrôle, surimpression de vision, appuis simulés. */
public class BotService extends AccessibilityService {
    public static volatile BotService instance;

    private WindowManager wm;
    private Handler main;
    private OverlayView overlay;
    private LinearLayout bubble;
    private WindowManager.LayoutParams bubbleLp;
    private TextView playBtn;
    private CalibrationView calib;
    private Brain brain;
    private volatile RectF bubbleRect = new RectF();
    private volatile boolean hidden;

    @Override
    protected void onServiceConnected() {
        instance = this;
        BotLog.init(this);
        wm = getSystemService(WindowManager.class);
        main = new Handler(Looper.getMainLooper());
        overlay = new OverlayView(this);
        wm.addView(overlay, lp(false, WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT));
        buildBubble();
        brain = new Brain(this);
        brain.start();
        BotLog.log("Service d'accessibilité connecté");
    }

    private WindowManager.LayoutParams lp(boolean touchable, int w, int h) {
        int flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS;
        if (!touchable) flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        WindowManager.LayoutParams p = new WindowManager.LayoutParams(w, h,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, flags, PixelFormat.TRANSLUCENT);
        p.gravity = Gravity.TOP | Gravity.START;
        if (Build.VERSION.SDK_INT >= 28)
            p.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        return p;
    }

    /** Taille réelle de l'écran (orientation courante). */
    public android.util.DisplayMetrics real() {
        android.util.DisplayMetrics m = new android.util.DisplayMetrics();
        getSystemService(android.hardware.display.DisplayManager.class)
                .getDisplay(android.view.Display.DEFAULT_DISPLAY).getRealMetrics(m);
        return m;
    }

    private int dp(float v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private TextView bubbleBtn(String t, int color) {
        TextView b = new TextView(this);
        b.setText(t); b.setTextColor(color); b.setTextSize(20); b.setGravity(Gravity.CENTER);
        b.setLayoutParams(new LinearLayout.LayoutParams(dp(44), dp(44)));
        return b;
    }

    private void buildBubble() {
        bubble = new LinearLayout(this);
        bubble.setOrientation(LinearLayout.HORIZONTAL);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xE6121820); bg.setCornerRadius(dp(24)); bg.setStroke(dp(1.5f), 0xFFF2B33D);
        bubble.setBackground(bg);
        bubble.setPadding(dp(4), 0, dp(4), 0);
        TextView drag = bubbleBtn("⠿", 0xFF8A94A6);
        playBtn = bubbleBtn("▶", 0xFF4CFF7A);
        TextView cal = bubbleBtn("◎", 0xFF3ED6E0);
        TextView eye = bubbleBtn("👁", 0xFFFFFFFF);
        TextView stop = bubbleBtn("■", 0xFFFFB020);
        bubble.addView(drag); bubble.addView(playBtn); bubble.addView(cal); bubble.addView(eye); bubble.addView(stop);
        bubbleLp = lp(true, WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT);
        bubbleLp.x = dp(16); bubbleLp.y = dp(120);
        wm.addView(bubble, bubbleLp);

        drag.setOnTouchListener(new View.OnTouchListener() {
            float sx, sy; int ox, oy;
            @Override public boolean onTouch(View v, MotionEvent e) {
                switch (e.getActionMasked()) {
                    case MotionEvent.ACTION_DOWN: sx = e.getRawX(); sy = e.getRawY(); ox = bubbleLp.x; oy = bubbleLp.y; return true;
                    case MotionEvent.ACTION_MOVE:
                        bubbleLp.x = ox + (int) (e.getRawX() - sx); bubbleLp.y = oy + (int) (e.getRawY() - sy);
                        wm.updateViewLayout(bubble, bubbleLp); updateBubbleRect(); return true;
                    case MotionEvent.ACTION_UP: updateBubbleRect(); return true;
                }
                return false;
            }
        });
        playBtn.setOnClickListener(v -> {
            if (CaptureService.instance == null) { toast("Lancez d'abord la capture depuis l'appli"); return; }
            if (!Config.get(this).calibrated) toast("Conseil : calibrez d'abord avec ◎");
            brain.setActive(!brain.active);
            refreshPlay();
        });
        cal.setOnClickListener(v -> startCalibration());
        eye.setOnClickListener(v -> { overlay.showVision = !overlay.showVision; overlay.invalidate();
            toast(overlay.showVision ? "Vision du bot affichée" : "Vision masquée (le bot continue)"); });
        stop.setOnClickListener(v -> {
            brain.setActive(false); refreshPlay();
            CaptureService cs = CaptureService.instance;
            if (cs != null) cs.stopAll();
            toast("Bot et capture arrêtés");
        });
        bubble.post(this::updateBubbleRect);
    }

    private void refreshPlay() {
        playBtn.setText(brain.active ? "⏸" : "▶");
        playBtn.setTextColor(brain.active ? 0xFFFFD84A : 0xFF4CFF7A);
    }

    private void updateBubbleRect() {
        int[] loc = new int[2];
        bubble.getLocationOnScreen(loc);
        float panelH = dp(92), panelW = Math.max(bubble.getWidth(), dp(270));
        bubbleRect = new RectF(loc[0] - dp(8), loc[1] - dp(8), loc[0] + panelW + dp(8), loc[1] + bubble.getHeight() + panelH + dp(8));
        overlay.setPanel(loc[0], loc[1] + bubble.getHeight() + dp(6), panelW);
    }

    /** Zones à ne jamais toucher / ignorer (écran). */
    private List<RectF> screenExclusions() {
        ArrayList<RectF> l = new ArrayList<>();
        Config c = Config.get(this);
        android.util.DisplayMetrics m = real();
        int sh = m.heightPixels, sw = m.widthPixels;
        float r = Math.min(sw, sh) * 0.07f;
        for (int i = 0; i < c.spellX.length; i++) l.add(new RectF(c.spellX[i] - r, c.spellY[i] - r, c.spellX[i] + r, c.spellY[i] + r));
        if (c.actionX >= 0) l.add(new RectF(c.actionX - r, c.actionY - r, c.actionX + r, c.actionY + r));
        if (c.hpLx >= 0 && c.hpRx >= 0) {
            float m = r * 0.6f;
            l.add(new RectF(Math.min(c.hpLx, c.hpRx) - m, Math.min(c.hpLy, c.hpRy) - m, Math.max(c.hpLx, c.hpRx) + m, Math.max(c.hpLy, c.hpRy) + m));
        }
        l.add(new RectF(bubbleRect));
        return l;
    }

    /** Exclusions en coordonnées image (appelé par le cerveau). */
    public List<RectF> exclusions(float scale) {
        List<RectF> l = screenExclusions();
        for (RectF e : l) { e.left *= scale; e.top *= scale; e.right *= scale; e.bottom *= scale; }
        return l;
    }

    public boolean tapSafe(float x, float y, long dur) {
        android.util.DisplayMetrics m = real();
        Config c = Config.get(this);
        float maxW = m.widthPixels, maxH = m.heightPixels;
        if (x < maxW * 0.04f || x > maxW * 0.96f || y < maxH * (c.topExcludePct / 100f) || y > maxH * 0.94f) return false;
        for (RectF e : screenExclusions()) if (e.contains(x, y)) return false;
        tap(x, y, dur);
        return true;
    }

    public void tap(float x, float y, long dur) {
        if (x < 0 || y < 0) return;
        Path p = new Path();
        p.moveTo(x, y);
        GestureDescription g = new GestureDescription.Builder()
                .addStroke(new GestureDescription.StrokeDescription(p, 0, Math.max(1, dur))).build();
        dispatchGesture(g, null, null);
        main.post(() -> overlay.flashTap(x, y));
    }

    public void postOverlay(Frame f, List<Detector.Det> en, Detector.Det target, int hp, boolean[] ready, String dec, int fps) {
        final List<RectF> boxes = new ArrayList<>();
        RectF tgt = null;
        if (f != null && en != null) {
            float s = f.scale;
            for (Detector.Det d : en) {
                RectF r = new RectF(d.x0 / s, d.y0 / s, (d.x1 + 1) / s, (d.y1 + 1) / s);
                boxes.add(r);
                if (d == target) tgt = r;
            }
        }
        final RectF t = tgt;
        final boolean act = brain != null && brain.active;
        main.post(() -> overlay.setData(boxes, t, hp, ready, dec, act, fps));
    }

    // ---------- Calibrage ----------
    private void startCalibration() {
        if (calib != null) return;
        if (brain.active) { brain.setActive(false); refreshPlay(); }
        if (CaptureService.instance == null) toast("Capture inactive : positions enregistrées, mais pas les couleurs. Lancez la capture puis recalibrez.");
        hidden = true;
        overlay.setVisibility(View.GONE);
        bubble.setVisibility(View.GONE);
        calib = new CalibrationView(this, Config.get(this).spellX.length, res -> {
            try { wm.removeView(calib); } catch (Exception ignored) { }
            calib = null;
            if (res.cancelled) { restoreViews(); toast("Calibrage annulé"); return; }
            main.postDelayed(() -> applyCalibration(res), 700);
        });
        wm.addView(calib, lp(true, WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT));
    }

    private void restoreViews() {
        hidden = false;
        overlay.setVisibility(View.VISIBLE);
        bubble.setVisibility(View.VISIBLE);
        bubble.post(this::updateBubbleRect);
    }

    private void applyCalibration(CalibrationView.Result r) {
        Config c = Config.get(this);
        CaptureService cs = CaptureService.instance;
        Frame f = cs == null ? null : cs.latest;
        StringBuilder rep = new StringBuilder("Calibrage : ");
        if (r.hpL != null && r.hpR != null) {
            c.hpLx = (int) r.hpL.x; c.hpLy = (int) r.hpL.y; c.hpRx = (int) r.hpR.x; c.hpRy = (int) r.hpR.y;
            if (f != null) {
                float s = f.scale;
                int mx = Math.round((r.hpL.x * 0.6f + r.hpR.x * 0.4f) * s), my = Math.round((r.hpL.y * 0.6f + r.hpR.y * 0.4f) * s);
                c.hpColor = Detector.avgColor(f, mx, my);
                if (c.hpColor == 0) c.hpColor = 1;
                rep.append("vie ✔ ");
            } else { c.hpColor = 0; rep.append("vie (couleur non mesurée) "); }
        }
        if (!r.spells.isEmpty()) {
            int n = r.spells.size();
            c.spellX = new int[n]; c.spellY = new int[n]; c.spellLum = new float[n];
            for (int i = 0; i < n; i++) {
                PointF p = r.spells.get(i);
                c.spellX[i] = (int) p.x; c.spellY[i] = (int) p.y;
                if (f != null) c.spellLum[i] = f.lum(Math.round(p.x * f.scale), Math.round(p.y * f.scale), Detector.patchRadius(f));
            }
            if (c.healSlot > n) c.healSlot = 0;
            rep.append(n).append(" sort(s) ✔ ");
        }
        if (r.enemy != null && f != null) {
            int col = Detector.mostSaturated(f, Math.round(r.enemy.x * f.scale), Math.round(r.enemy.y * f.scale), 5);
            if (col >= 0) { c.enemyColor = col; c.enemyColorSampled = true; rep.append("couleur ennemi ✔ "); }
            else rep.append("couleur ennemi non trouvée (rouge par défaut) ");
        }
        if (r.action != null) { c.actionX = (int) r.action.x; c.actionY = (int) r.action.y; rep.append("action ✔"); }
        c.calibrated = true;
        c.save();
        BotLog.log(rep.toString() + " | " + c.summary());
        restoreViews();
        toast(rep.toString());
    }

    void toast(String s) { main.post(() -> Toast.makeText(this, s, Toast.LENGTH_LONG).show()); }

    public boolean isActive() { return brain != null && brain.active; }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) { }
    @Override public void onInterrupt() { }

    @Override
    public void onDestroy() {
        instance = null;
        if (brain != null) brain.stop();
        try { wm.removeView(overlay); } catch (Exception ignored) { }
        try { wm.removeView(bubble); } catch (Exception ignored) { }
        try { if (calib != null) wm.removeView(calib); } catch (Exception ignored) { }
        BotLog.log("Service d'accessibilité arrêté");
        super.onDestroy();
    }
}
