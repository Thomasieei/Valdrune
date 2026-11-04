package com.thomas.botlab;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.os.SystemClock;
import android.view.View;
import java.util.ArrayList;
import java.util.List;

/** Ce que le bot voit et décide, dessiné par-dessus le jeu. Pas de rouge (sinon le bot se détecterait lui-même). */
public class OverlayView extends View {
    public boolean showVision = true;
    private List<RectF> boxes = new ArrayList<>();
    private RectF target;
    private int hp = -1, fps;
    private boolean[] ready;
    private String decision = "Bot prêt";
    private boolean active;
    private float panelX, panelY, panelW;
    private float tapX = -1, tapY = -1; private long tapT;

    private final Paint box = new Paint(Paint.ANTI_ALIAS_FLAG), tgt = new Paint(Paint.ANTI_ALIAS_FLAG),
            line = new Paint(Paint.ANTI_ALIAS_FLAG), panel = new Paint(Paint.ANTI_ALIAS_FLAG),
            txt = new Paint(Paint.ANTI_ALIAS_FLAG), small = new Paint(Paint.ANTI_ALIAS_FLAG),
            ring = new Paint(Paint.ANTI_ALIAS_FLAG), tapP = new Paint(Paint.ANTI_ALIAS_FLAG),
            label = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float d;
    private final int[] loc = new int[2];

    public OverlayView(Context c) {
        super(c);
        d = getResources().getDisplayMetrics().density;
        box.setStyle(Paint.Style.STROKE); box.setStrokeWidth(2 * d); box.setColor(0xFF3ED6E0);
        tgt.setStyle(Paint.Style.STROKE); tgt.setStrokeWidth(3 * d); tgt.setColor(0xFFFFE14A);
        line.setStyle(Paint.Style.STROKE); line.setStrokeWidth(1.5f * d); line.setColor(0xAAFFE14A);
        line.setPathEffect(new android.graphics.DashPathEffect(new float[]{8 * d, 6 * d}, 0));
        panel.setColor(0xD90E1218);
        txt.setColor(0xFFFFFFFF); txt.setTextSize(13 * d); txt.setFakeBoldText(true);
        small.setColor(0xFFB8C2D0); small.setTextSize(11 * d);
        label.setColor(0xFFFFE14A); label.setTextSize(10 * d); label.setFakeBoldText(true);
        ring.setStyle(Paint.Style.STROKE); ring.setStrokeWidth(2.5f * d);
        tapP.setStyle(Paint.Style.STROKE); tapP.setStrokeWidth(2 * d); tapP.setColor(0xFFFFFFFF);
    }

    public void setPanel(float x, float y, float w) { panelX = x; panelY = y; panelW = w; invalidate(); }

    public void setData(List<RectF> b, RectF t, int hp, boolean[] ready, String dec, boolean active, int fps) {
        boxes = b; target = t; this.hp = hp; this.ready = ready; decision = dec; this.active = active; this.fps = fps;
        invalidate();
    }

    public void flashTap(float x, float y) { tapX = x; tapY = y; tapT = SystemClock.uptimeMillis(); invalidate(); }

    @Override
    protected void onDraw(Canvas c) {
        getLocationOnScreen(loc);
        c.save();
        c.translate(-loc[0], -loc[1]);
        if (showVision) {
            float cx = getRootView().getWidth() / 2f + loc[0], cy = getRootView().getHeight() / 2f + loc[1];
            for (RectF r : boxes) {
                RectF e = new RectF(r.left - 3 * d, r.top - 3 * d, r.right + 3 * d, r.bottom + r.width() * 1.6f);
                c.drawRoundRect(e, 4 * d, 4 * d, r == target ? tgt : box);
            }
            if (target != null) {
                c.drawLine(cx, cy, target.centerX(), target.bottom + target.width() * 0.9f, line);
                c.drawText("CIBLE", target.left, target.top - 6 * d, label);
            }
            Config cf = Config.get(getContext());
            if (ready != null) {
                float rr = 26 * d;
                for (int i = 0; i < cf.spellX.length && i < ready.length; i++) {
                    ring.setColor(ready[i] ? 0xFF4CFF7A : 0x88808A99);
                    c.drawCircle(cf.spellX[i], cf.spellY[i], rr, ring);
                    c.drawText(String.valueOf(i + 1), cf.spellX[i] + rr * 0.75f, cf.spellY[i] - rr * 0.75f, label);
                }
            }
            long age = SystemClock.uptimeMillis() - tapT;
            if (tapX >= 0 && age < 400) {
                tapP.setAlpha((int) (255 * (1 - age / 400f)));
                c.drawCircle(tapX, tapY, (10 + age / 12f) * d, tapP);
                postInvalidateDelayed(30);
            }
        }
        // Panneau d'état sous la bulle
        if (panelW > 0) {
            float h = 86 * d;
            RectF p = new RectF(panelX, panelY, panelX + panelW, panelY + h);
            c.drawRoundRect(p, 10 * d, 10 * d, panel);
            float x = panelX + 10 * d, y = panelY + 20 * d;
            txt.setColor(active ? 0xFF4CFF7A : 0xFFFFD84A);
            c.drawText(active ? "● ACTIF" : "● EN PAUSE", x, y, txt);
            txt.setColor(0xFFFFFFFF);
            String dec = decision == null ? "" : decision;
            int k = dec.indexOf(" —");
            c.drawText(k > 0 ? dec.substring(0, k) : dec, x + 92 * d, y, txt);
            y += 20 * d;
            if (k > 0) c.drawText(ellipsize(dec.substring(k + 3), panelW - 20 * d), x, y, small);
            y += 20 * d;
            String vie = hp < 0 ? "vie : non calibrée" : "vie : " + hp + " %";
            c.drawText(vie + "   ennemis : " + boxes.size() + "   " + fps + " déc/s", x, y, small);
        }
        c.restore();
    }

    private String ellipsize(String s, float max) {
        if (small.measureText(s) <= max) return s;
        while (s.length() > 3 && small.measureText(s + "…") > max) s = s.substring(0, s.length() - 1);
        return s + "…";
    }
}
