package fr.thomas.artemis;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.text.TextUtils;
import android.util.DisplayMetrics;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * La bulle flottante d'Artémis, posée par-dessus toutes les applis (fenêtre d'accessibilité :
 * aucune permission « superposition » à donner). États : bulle → panneau → en cours → question → résultat.
 */
final class Overlay implements Agent.Ui {
    static final int BG = 0xF2161824, CARD = 0xFF1E2130, ACCENT = 0xFF8B7BFF, ACCENT2 = 0xFF4FD1C5,
            TEXT = 0xFFEEEBFF, MUTED = 0xFF9A97B5, RED = 0xFFFF5C7A, FIELD = 0xFF262A3B;

    private final AgentService svc;
    private final WindowManager wm;
    private final Handler h = new Handler(Looper.getMainLooper());
    private final FrameLayout root;
    private WindowManager.LayoutParams lp;
    private boolean added;
    private int bubbleX = -1, bubbleY = -1;
    private String state = "";
    private TextView statusTv;

    Overlay(AgentService svc) {
        this.svc = svc;
        this.wm = (WindowManager) svc.getSystemService(Context.WINDOW_SERVICE);
        this.root = new FrameLayout(svc);
    }

    private int dp(float v) { return Math.round(v * svc.getResources().getDisplayMetrics().density); }
    private int screenW() { DisplayMetrics m = svc.getResources().getDisplayMetrics(); return m.widthPixels; }

    void remove() { h.post(() -> { if (added) { try { wm.removeView(root); } catch (Exception ignored) {} added = false; } }); }

    private void apply(boolean big, boolean focusable) {
        WindowManager.LayoutParams p = new WindowManager.LayoutParams(
                big ? WindowManager.LayoutParams.MATCH_PARENT : WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL | WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | (focusable ? 0 : WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE),
                PixelFormat.TRANSLUCENT);
        p.gravity = Gravity.TOP | Gravity.START;
        if (big) { p.x = 0; p.y = dp(30); }
        else {
            if (bubbleX < 0) { bubbleX = screenW() - dp(66); bubbleY = dp(220); }
            p.x = bubbleX; p.y = bubbleY;
        }
        p.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN | WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE;
        lp = p;
        root.setAlpha(1f);
        if (added) wm.updateViewLayout(root, p); else { wm.addView(root, p); added = true; }
    }

    // ------------------------------------------------------------------ bulle

    @SuppressLint("ClickableViewAccessibility")
    void showBubble() {
        h.post(() -> {
            state = "bubble";
            root.removeAllViews();
            root.setOnTouchListener(null);
            ImageView iv = new ImageView(svc);
            iv.setImageResource(R.mipmap.ic_launcher);
            int s = dp(54);
            GradientDrawable g = new GradientDrawable();
            g.setShape(GradientDrawable.OVAL);
            g.setColor(0x33000000);
            iv.setBackground(g);
            iv.setElevation(dp(6));
            root.addView(iv, new FrameLayout.LayoutParams(s, s));
            final float[] d = new float[4];
            final boolean[] moved = {false};
            iv.setOnTouchListener((v, e) -> {
                switch (e.getActionMasked()) {
                    case MotionEvent.ACTION_DOWN:
                        d[0] = e.getRawX(); d[1] = e.getRawY(); d[2] = lp.x; d[3] = lp.y; moved[0] = false; return true;
                    case MotionEvent.ACTION_MOVE:
                        float dx = e.getRawX() - d[0], dy = e.getRawY() - d[1];
                        if (Math.abs(dx) + Math.abs(dy) > dp(8)) moved[0] = true;
                        if (moved[0]) { lp.x = (int) (d[2] + dx); lp.y = (int) (d[3] + dy); bubbleX = lp.x; bubbleY = lp.y; wm.updateViewLayout(root, lp); }
                        return true;
                    case MotionEvent.ACTION_UP:
                        if (!moved[0]) showPanel(null);
                        else {
                            lp.x = lp.x + s / 2 < screenW() / 2 ? dp(6) : screenW() - s - dp(6);
                            bubbleX = lp.x; wm.updateViewLayout(root, lp);
                        }
                        return true;
                }
                return false;
            });
            apply(false, false);
        });
    }

    // ------------------------------------------------------------------ panneau

    void showPanel(String result) { showPanel(result, true); }

    @SuppressLint("ClickableViewAccessibility")
    private void showPanel(String result, boolean resultOk) {
        h.post(() -> {
            state = "panel";
            LinearLayout card = card();
            LinearLayout top = new LinearLayout(svc);
            top.setGravity(Gravity.CENTER_VERTICAL);
            TextView title = tv("Artémis", 19, TEXT, true);
            top.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
            TextView close = tv("✕", 20, MUTED, false);
            close.setPadding(dp(12), dp(4), dp(4), dp(4));
            close.setOnClickListener(v -> showBubble());
            top.addView(close);
            card.addView(top);

            if (result != null) {
                TextView r = tv(result, 15, TEXT, false);
                r.setPadding(dp(12), dp(10), dp(12), dp(10));
                r.setBackground(round(resultOk ? 0x2A4FD1C5 : 0x2AFF5C7A, 12));
                r.setTextIsSelectable(true);
                card.addView(r, mt(10));
            }

            final EditText et = new EditText(svc);
            et.setHint("Que dois-je faire sur ton téléphone ?");
            et.setHintTextColor(MUTED);
            et.setTextColor(TEXT);
            et.setTextSize(15);
            et.setMinLines(2);
            et.setMaxLines(5);
            et.setGravity(Gravity.TOP);
            et.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
            et.setImeOptions(EditorInfo.IME_ACTION_GO);
            et.setBackground(round(FIELD, 12));
            et.setPadding(dp(12), dp(10), dp(12), dp(10));
            card.addView(et, mt(12));

            JSONArray rs = Cfg.routines(svc);
            if (rs.length() > 0) {
                HorizontalScrollView hs = new HorizontalScrollView(svc);
                hs.setHorizontalScrollBarEnabled(false);
                LinearLayout row = new LinearLayout(svc);
                for (int i = 0; i < rs.length(); i++) {
                    final JSONObject o = rs.optJSONObject(i);
                    if (o == null) continue;
                    TextView chip = tv("▶ " + o.optString("name"), 13, TEXT, false);
                    chip.setPadding(dp(12), dp(7), dp(12), dp(7));
                    chip.setBackground(round(0x338B7BFF, 20));
                    chip.setOnClickListener(v -> launch(o.optString("task")));
                    LinearLayout.LayoutParams l = new LinearLayout.LayoutParams(-2, -2);
                    l.rightMargin = dp(8);
                    row.addView(chip, l);
                }
                hs.addView(row);
                card.addView(hs, mt(10));
            }

            TextView go = button("Lancer", ACCENT);
            go.setOnClickListener(v -> launch(et.getText().toString()));
            card.addView(go, mt(12));
            et.setOnEditorActionListener((v, id, ev) -> { launch(et.getText().toString()); return true; });

            setCard(card, true);
            root.setOnTouchListener((v, e) -> {
                if (e.getActionMasked() == MotionEvent.ACTION_OUTSIDE && result == null) showBubble();
                return false;
            });
            if (result == null) h.postDelayed(() -> {
                et.requestFocus();
                InputMethodManager im = (InputMethodManager) svc.getSystemService(Context.INPUT_METHOD_SERVICE);
                if (im != null) im.showSoftInput(et, 0);
            }, 250);
        });
    }

    private void launch(String goal) {
        if (goal == null || goal.trim().isEmpty()) return;
        hideKeyboard();
        svc.start(goal);
    }

    private void hideKeyboard() {
        InputMethodManager im = (InputMethodManager) svc.getSystemService(Context.INPUT_METHOD_SERVICE);
        if (im != null) im.hideSoftInputFromWindow(root.getWindowToken(), 0);
    }

    // ------------------------------------------------------------------ en cours

    void running(String goal) {
        h.post(() -> {
            state = "running";
            root.setOnTouchListener(null);
            LinearLayout bar = new LinearLayout(svc);
            bar.setOrientation(LinearLayout.HORIZONTAL);
            bar.setGravity(Gravity.CENTER_VERTICAL);
            bar.setPadding(dp(14), dp(8), dp(8), dp(8));
            bar.setBackground(round(BG, 22));
            bar.setElevation(dp(8));
            View dot = new View(svc);
            dot.setBackground(round(ACCENT2, 6));
            bar.addView(dot, new LinearLayout.LayoutParams(dp(10), dp(10)));
            statusTv = tv("Je démarre…", 13, TEXT, false);
            statusTv.setMaxLines(2);
            statusTv.setEllipsize(TextUtils.TruncateAt.END);
            LinearLayout.LayoutParams sl = new LinearLayout.LayoutParams(0, -2, 1);
            sl.leftMargin = dp(10); sl.rightMargin = dp(8);
            bar.addView(statusTv, sl);
            TextView stop = tv("■ Stop", 13, Color.WHITE, true);
            stop.setPadding(dp(14), dp(8), dp(14), dp(8));
            stop.setBackground(round(RED, 18));
            stop.setOnClickListener(v -> { svc.stopAgent(); statusTv.setText("J'arrête…"); });
            bar.addView(stop);
            FrameLayout wrap = new FrameLayout(svc);
            wrap.setPadding(dp(10), 0, dp(10), 0);
            wrap.addView(bar, new FrameLayout.LayoutParams(-1, -2));
            root.removeAllViews();
            root.addView(wrap, new FrameLayout.LayoutParams(-1, -2));
            apply(true, false);
        });
    }

    @Override public void status(String text) {
        h.post(() -> { if (statusTv != null && "running".equals(state)) statusTv.setText(text); });
    }

    /** Rend la bulle invisible et « transparente » au toucher pendant une capture ou un geste. Synchrone. */
    @Override public void stealth(boolean hidden) {
        final CountDownLatch l = new CountDownLatch(1);
        h.post(() -> {
            try {
                if (added && lp != null && "running".equals(state)) {
                    if (hidden) lp.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
                    else lp.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
                    root.setAlpha(hidden ? 0f : 1f);
                    wm.updateViewLayout(root, lp);
                }
            } catch (Exception ignored) {}
            l.countDown();
        });
        try { l.await(400, TimeUnit.MILLISECONDS); } catch (InterruptedException ignored) {}
        if (hidden) try { Thread.sleep(60); } catch (InterruptedException ignored) {}
    }

    // ------------------------------------------------------------------ question

    @SuppressLint("ClickableViewAccessibility")
    @Override public void ask(String question, boolean confirm) {
        h.post(() -> {
            state = "ask";
            LinearLayout card = card();
            card.addView(tv(confirm ? "Artémis te demande ton accord" : "Artémis a une question", 13, ACCENT, true));
            TextView q = tv(question, 16, TEXT, false);
            card.addView(q, mt(8));
            LinearLayout row = new LinearLayout(svc);
            row.setGravity(Gravity.CENTER_VERTICAL);
            final EditText et = new EditText(svc);
            if (confirm) {
                TextView yes = button("Oui", ACCENT2), no = button("Non", 0xFF3A3F55);
                yes.setOnClickListener(v -> reply("oui"));
                no.setOnClickListener(v -> reply("non"));
                LinearLayout.LayoutParams a = new LinearLayout.LayoutParams(0, -2, 1), b = new LinearLayout.LayoutParams(0, -2, 1);
                a.rightMargin = dp(8);
                row.addView(yes, a); row.addView(no, b);
                card.addView(row, mt(14));
            } else {
                et.setHint("Ta réponse (ou « c'est fait »)");
                et.setHintTextColor(MUTED);
                et.setTextColor(TEXT);
                et.setTextSize(15);
                et.setBackground(round(FIELD, 12));
                et.setPadding(dp(12), dp(10), dp(12), dp(10));
                et.setImeOptions(EditorInfo.IME_ACTION_SEND);
                et.setSingleLine(true);
                et.setOnEditorActionListener((v, id, ev) -> { reply(et.getText().toString()); return true; });
                card.addView(et, mt(12));
                TextView send = button("Répondre", ACCENT);
                send.setOnClickListener(v -> reply(et.getText().toString()));
                card.addView(send, mt(10));
            }
            TextView stop = tv("Arrêter la tâche", 13, RED, false);
            stop.setPadding(0, dp(12), 0, 0);
            stop.setGravity(Gravity.CENTER);
            stop.setOnClickListener(v -> svc.stopAgent());
            card.addView(stop, new LinearLayout.LayoutParams(-1, -2));
            setCard(card, !confirm);
            // Toucher en dehors : rend la main à l'appli (pour taper un code soi-même), la question reste affichée.
            root.setOnTouchListener((v, e) -> {
                if (e.getActionMasked() == MotionEvent.ACTION_OUTSIDE && lp != null
                        && (lp.flags & WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE) == 0) {
                    lp.flags |= WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
                    wm.updateViewLayout(root, lp);
                }
                return false;
            });
            if (!confirm) {
                et.setOnClickListener(v -> {
                    if (lp != null && (lp.flags & WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE) != 0) {
                        lp.flags &= ~WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
                        wm.updateViewLayout(root, lp);
                    }
                });
                et.requestFocus();
            }
        });
    }

    private void reply(String s) {
        hideKeyboard();
        running("");
        svc.answer(s == null || s.trim().isEmpty() ? "(pas de réponse)" : s.trim());
    }

    @Override public void finished(boolean ok, String summary) {
        h.post(() -> {
            svc.done();
            showPanel((ok ? "✓ " : "✕ ") + summary, ok);
        });
    }

    // ------------------------------------------------------------------ helpers vue

    private LinearLayout card() {
        LinearLayout c = new LinearLayout(svc);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setPadding(dp(16), dp(14), dp(16), dp(16));
        c.setBackground(round(BG, 20));
        c.setElevation(dp(10));
        return c;
    }

    private void setCard(LinearLayout card, boolean focusable) {
        FrameLayout wrap = new FrameLayout(svc);
        wrap.setPadding(dp(10), 0, dp(10), 0);
        wrap.addView(card, new FrameLayout.LayoutParams(-1, -2));
        root.removeAllViews();
        root.addView(wrap, new FrameLayout.LayoutParams(-1, -2));
        apply(true, focusable);
    }

    private TextView tv(String s, float size, int color, boolean bold) {
        TextView t = new TextView(svc);
        t.setText(s);
        t.setTextSize(size);
        t.setTextColor(color);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

    private TextView button(String s, int color) {
        TextView b = tv(s, 15, Color.WHITE, true);
        b.setGravity(Gravity.CENTER);
        b.setPadding(dp(16), dp(12), dp(16), dp(12));
        b.setBackground(round(color, 14));
        return b;
    }

    private GradientDrawable round(int color, int radiusDp) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(radiusDp));
        return g;
    }

    private LinearLayout.LayoutParams mt(int topDp) {
        LinearLayout.LayoutParams l = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        l.topMargin = dp(topDp);
        return l;
    }
}
