package fr.thomas.testbot;

import android.content.Context;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Petites briques d'interface partagées (thème graphite + ambre). */
final class Ui {
    static final int BG = 0xFF121419, CARD = 0xFF1A1D24, CARD2 = 0xFF22262F, LINE = 0xFF2C313C;
    static final int FG = 0xFFECE8DF, MUTE = 0xFF8E95A3, AMBER = 0xFFFFB627, CORAL = 0xFFFF6B5A;
    static final int OK = 0xFF5FD38D, CYAN = 0xFF7FE0FF, INK = 0xFF1C1503;

    private Ui() {}

    static int dp(Context c, float v) { return Math.round(v * c.getResources().getDisplayMetrics().density); }

    static GradientDrawable box(Context c, int fill, float radiusDp, int stroke) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(dp(c, radiusDp));
        if (stroke != 0) g.setStroke(dp(c, 1.2f), stroke);
        return g;
    }

    static TextView text(Context c, String s, float sp, int color, boolean bold) {
        TextView t = new TextView(c);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(color);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

    static TextView mono(Context c, String s, float sp, int color) {
        TextView t = text(c, s, sp, color, false);
        t.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.BOLD));
        return t;
    }

    /** Bouton plat avec effet d'appui. */
    static TextView button(Context c, String s, int fill, int color, int stroke) {
        TextView b = text(c, s, 14, color, true);
        b.setGravity(Gravity.CENTER);
        int p = dp(c, 11);
        b.setPadding(p, p, p, p);
        b.setBackground(box(c, fill, 11, stroke));
        pressable(b);
        return b;
    }

    static void pressable(View v) {
        v.setOnTouchListener((view, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) view.setAlpha(0.65f);
            else if (e.getAction() == MotionEvent.ACTION_UP || e.getAction() == MotionEvent.ACTION_CANCEL) view.setAlpha(1f);
            return false;
        });
    }

    static LinearLayout row(Context c) {
        LinearLayout l = new LinearLayout(c);
        l.setOrientation(LinearLayout.HORIZONTAL);
        l.setGravity(Gravity.CENTER_VERTICAL);
        return l;
    }

    static LinearLayout col(Context c) {
        LinearLayout l = new LinearLayout(c);
        l.setOrientation(LinearLayout.VERTICAL);
        return l;
    }

    static LinearLayout.LayoutParams weight(float w) {
        return new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, w);
    }

    static LinearLayout.LayoutParams wrap() {
        return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    }

    static LinearLayout.LayoutParams full() {
        return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    }

    static LinearLayout.LayoutParams margins(LinearLayout.LayoutParams lp, Context c, float l, float t, float r, float b) {
        lp.setMargins(dp(c, l), dp(c, t), dp(c, r), dp(c, b));
        return lp;
    }

    static String dur(long ms) {
        long s = ms / 1000;
        return (s / 60) + " min " + String.format("%02d", s % 60) + " s";
    }
}
