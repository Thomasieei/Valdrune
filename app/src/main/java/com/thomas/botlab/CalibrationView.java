package com.thomas.botlab;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PointF;
import android.graphics.RectF;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.view.MotionEvent;
import android.view.View;
import java.util.ArrayList;

/** Calibrage en jeu : le joueur touche sa barre de vie, ses sorts, une barre ennemie, le bouton d'action. */
public class CalibrationView extends View {
    public interface Done { void done(Result r); }
    public static class Result {
        public PointF hpL, hpR, enemy, action;
        public final ArrayList<PointF> spells = new ArrayList<>();
        public boolean cancelled;
    }

    private static final String[] TEXT = {
        "1/5 · Touchez l'extrémité GAUCHE de VOTRE barre de vie. Faites-le avec la vie pleine.",
        "2/5 · Touchez l'extrémité DROITE de votre barre de vie.",
        "3/5 · Touchez vos boutons de sort dans l'ordre (6 max), sorts prêts. Puis « Suivant ».",
        "4/5 · Touchez la barre de vie d'un ENNEMI visible à l'écran (facultatif).",
        "5/5 · Touchez le bouton d'action / récolte du jeu (facultatif)."
    };

    private final Done cb;
    private final Result r = new Result();
    private int step = 0;
    private boolean top = true;
    private final float d;
    private final int[] loc = new int[2];
    private final Paint card = new Paint(Paint.ANTI_ALIAS_FLAG), btn = new Paint(Paint.ANTI_ALIAS_FLAG),
            btnTxt = new Paint(Paint.ANTI_ALIAS_FLAG), mark = new Paint(Paint.ANTI_ALIAS_FLAG),
            markTxt = new Paint(Paint.ANTI_ALIAS_FLAG), edge = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final TextPaint tp = new TextPaint(Paint.ANTI_ALIAS_FLAG);
    private RectF cardR = new RectF(), bNext = new RectF(), bUndo = new RectF(), bCancel = new RectF(), bSwap = new RectF();

    public CalibrationView(Context c, int prevSpells, Done cb) {
        super(c);
        this.cb = cb;
        d = getResources().getDisplayMetrics().density;
        card.setColor(0xF0121820);
        edge.setStyle(Paint.Style.STROKE); edge.setStrokeWidth(1.5f * d); edge.setColor(0xFFF2B33D);
        btn.setColor(0xFF263040);
        btnTxt.setColor(0xFFFFFFFF); btnTxt.setTextSize(13 * d); btnTxt.setTextAlign(Paint.Align.CENTER); btnTxt.setFakeBoldText(true);
        tp.setColor(0xFFFFFFFF); tp.setTextSize(14 * d);
        mark.setStyle(Paint.Style.STROKE); mark.setStrokeWidth(2.5f * d); mark.setColor(0xFF3ED6E0);
        markTxt.setColor(0xFF3ED6E0); markTxt.setTextSize(12 * d); markTxt.setFakeBoldText(true);
    }

    @Override
    protected void onDraw(Canvas c) {
        getLocationOnScreen(loc);
        float w = getWidth();
        canvasMarks(c);
        float cw = Math.min(w - 24 * d, 520 * d), cx = (w - cw) / 2f;
        StaticLayout sl = StaticLayout.Builder.obtain(TEXT[step], 0, TEXT[step].length(), tp, (int) (cw - 24 * d))
                .setAlignment(Layout.Alignment.ALIGN_NORMAL).build();
        float ch = sl.getHeight() + 70 * d;
        float cy = top ? 12 * d : getHeight() - ch - 12 * d;
        cardR = new RectF(cx, cy, cx + cw, cy + ch);
        c.drawRoundRect(cardR, 12 * d, 12 * d, card);
        c.drawRoundRect(cardR, 12 * d, 12 * d, edge);
        c.save(); c.translate(cx + 12 * d, cy + 10 * d); sl.draw(c); c.restore();
        float by = cy + ch - 44 * d, bh = 34 * d, gap = 8 * d, bw = (cw - 24 * d - gap * 3) / 4f;
        float bx = cx + 12 * d;
        bCancel = new RectF(bx, by, bx + bw, by + bh); bx += bw + gap;
        bSwap = new RectF(bx, by, bx + bw, by + bh); bx += bw + gap;
        bUndo = new RectF(bx, by, bx + bw, by + bh); bx += bw + gap;
        bNext = new RectF(bx, by, bx + bw, by + bh);
        drawBtn(c, bCancel, "Annuler", 0xFF3A2A1A);
        drawBtn(c, bSwap, top ? "⇩ Bas" : "⇧ Haut", 0xFF263040);
        drawBtn(c, bUndo, "↶ Retour", 0xFF263040);
        drawBtn(c, bNext, nextLabel(), 0xFF1F5A3A);
    }

    private String nextLabel() {
        if (step == 4) return "Terminer";
        if (step == 2) return r.spells.isEmpty() ? "Passer" : "Suivant";
        return "Passer";
    }

    private void drawBtn(Canvas c, RectF b, String t, int col) {
        btn.setColor(col);
        c.drawRoundRect(b, 8 * d, 8 * d, btn);
        c.drawText(t, b.centerX(), b.centerY() + 5 * d, btnTxt);
    }

    private void canvasMarks(Canvas c) {
        c.save(); c.translate(-loc[0], -loc[1]);
        float rr = 18 * d;
        if (r.hpL != null) { c.drawCircle(r.hpL.x, r.hpL.y, rr * 0.6f, mark); c.drawText("G", r.hpL.x - 4 * d, r.hpL.y - rr, markTxt); }
        if (r.hpR != null) { c.drawCircle(r.hpR.x, r.hpR.y, rr * 0.6f, mark); c.drawText("D", r.hpR.x - 4 * d, r.hpR.y - rr, markTxt); }
        if (r.hpL != null && r.hpR != null) c.drawLine(r.hpL.x, r.hpL.y, r.hpR.x, r.hpR.y, mark);
        for (int i = 0; i < r.spells.size(); i++) {
            PointF p = r.spells.get(i);
            c.drawCircle(p.x, p.y, rr, mark); c.drawText(String.valueOf(i + 1), p.x - 4 * d, p.y + 5 * d, markTxt);
        }
        if (r.enemy != null) { c.drawCircle(r.enemy.x, r.enemy.y, rr * 0.7f, mark); c.drawText("ENNEMI", r.enemy.x - 20 * d, r.enemy.y - rr, markTxt); }
        if (r.action != null) { c.drawCircle(r.action.x, r.action.y, rr, mark); c.drawText("ACTION", r.action.x - 20 * d, r.action.y - rr - 4 * d, markTxt); }
        c.restore();
    }

    @Override
    public boolean onTouchEvent(MotionEvent e) {
        if (e.getActionMasked() != MotionEvent.ACTION_UP) return true;
        float x = e.getX(), y = e.getY();
        if (bCancel.contains(x, y)) { r.cancelled = true; cb.done(r); return true; }
        if (bSwap.contains(x, y)) { top = !top; invalidate(); return true; }
        if (bUndo.contains(x, y)) { undo(); invalidate(); return true; }
        if (bNext.contains(x, y)) { next(); invalidate(); return true; }
        if (cardR.contains(x, y)) return true;
        PointF p = new PointF(e.getRawX(), e.getRawY());
        switch (step) {
            case 0: r.hpL = p; step = 1; break;
            case 1: r.hpR = p; step = 2; break;
            case 2: r.spells.add(p); if (r.spells.size() >= 6) step = 3; break;
            case 3: r.enemy = p; step = 4; break;
            case 4: r.action = p; cb.done(r); return true;
        }
        invalidate();
        return true;
    }

    private void next() {
        if (step == 0) { r.hpL = null; r.hpR = null; step = 2; }
        else if (step == 1) { r.hpL = null; step = 2; }
        else if (step < 4) step++;
        else cb.done(r);
    }

    private void undo() {
        switch (step) {
            case 1: r.hpL = null; step = 0; break;
            case 2: if (!r.spells.isEmpty()) r.spells.remove(r.spells.size() - 1); else { r.hpR = null; step = r.hpL != null ? 1 : 0; } break;
            case 3: if (r.spells.size() >= 6) r.spells.remove(5); step = 2; break;
            case 4: r.enemy = null; step = 3; break;
        }
    }
}
