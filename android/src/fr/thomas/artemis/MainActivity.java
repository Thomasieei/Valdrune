package fr.thomas.artemis;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ComponentName;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.provider.Settings;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Écran principal : activation, tâche rapide, routines, réglages, historique. */
public class MainActivity extends Activity {
    private LinearLayout col;

    private int dp(float v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        Window w = getWindow();
        w.setStatusBarColor(0xFF10121A);
        w.setNavigationBarColor(0xFF10121A);
    }

    @Override protected void onResume() {
        super.onResume();
        build();
    }

    private boolean enabled() {
        String s = Settings.Secure.getString(getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        String me = new ComponentName(this, AgentService.class).flattenToString();
        return s != null && (s.contains(me) || s.contains(getPackageName() + "/.AgentService")) && AgentService.I != null;
    }

    private void build() {
        ScrollView sv = new ScrollView(this);
        sv.setBackgroundColor(0xFF10121A);
        sv.setFillViewport(true);
        col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding(dp(18), dp(28), dp(18), dp(40));
        sv.addView(col);

        TextView t = tv("Artémis", 30, Overlay.TEXT, true);
        col.addView(t);
        col.addView(tv("Ton assistant qui utilise le téléphone à ta place. Dis-lui une tâche, il ouvre les applis, lit, touche et écrit pour toi.", 14, Overlay.MUTED, false), mt(4));

        // ---------------------------------------------------------- activation
        LinearLayout st = card();
        boolean on = enabled();
        st.addView(tv(on ? "● Artémis est actif" : "● Artémis n'est pas activé", 16, on ? Overlay.ACCENT2 : Overlay.RED, true));
        st.addView(tv(on ? "La bulle flottante est disponible partout. Touche-la pour donner une tâche, glisse-la pour la déplacer."
                : "Active-le dans Accessibilité → Applications installées → Artémis. Sur Xiaomi, autorise aussi les « paramètres restreints » si Android le demande (Infos de l'appli → ⋮).",
                13, Overlay.MUTED, false), mt(6));
        if (!on) {
            TextView go = button("Ouvrir les réglages d'accessibilité", Overlay.ACCENT);
            go.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
            st.addView(go, mt(12));
        }
        if (Cfg.key(this).length() < 20) {
            st.addView(tv("⚠ Il manque ta clé API Claude (plus bas, dans Réglages).", 13, 0xFFFFC857, true), mt(10));
        }
        col.addView(st, mt(18));

        // ---------------------------------------------------------- tâche rapide
        LinearLayout tk = card();
        tk.addView(tv("Nouvelle tâche", 16, Overlay.TEXT, true));
        final EditText task = field("Ex. « Cherche sur YouTube une recette de tiramisu et lance la première vidéo »", false);
        task.setMinLines(2);
        tk.addView(task, mt(10));
        TextView run = button("Lancer", Overlay.ACCENT);
        run.setOnClickListener(v -> start(task.getText().toString()));
        tk.addView(run, mt(10));
        col.addView(tk, mt(14));

        // ---------------------------------------------------------- routines
        LinearLayout rt = card();
        LinearLayout rh = new LinearLayout(this);
        rh.setGravity(Gravity.CENTER_VERTICAL);
        rh.addView(tv("Routines", 16, Overlay.TEXT, true), new LinearLayout.LayoutParams(0, -2, 1));
        TextView add = tv("+ Ajouter", 14, Overlay.ACCENT, true);
        add.setOnClickListener(v -> addRoutine(task.getText().toString()));
        rh.addView(add);
        rt.addView(rh);
        rt.addView(tv("Tes tâches répétitives, lançables en un toucher depuis la bulle.", 12, Overlay.MUTED, false), mt(2));
        JSONArray rs = Cfg.routines(this);
        for (int i = 0; i < rs.length(); i++) {
            final int idx = i;
            final JSONObject o = rs.optJSONObject(i);
            if (o == null) continue;
            LinearLayout row = new LinearLayout(this);
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setPadding(dp(12), dp(10), dp(8), dp(10));
            row.setBackground(round(Overlay.FIELD, 12));
            LinearLayout txt = new LinearLayout(this);
            txt.setOrientation(LinearLayout.VERTICAL);
            txt.addView(tv(o.optString("name"), 15, Overlay.TEXT, true));
            TextView d = tv(o.optString("task"), 12, Overlay.MUTED, false);
            d.setMaxLines(2);
            txt.addView(d);
            row.addView(txt, new LinearLayout.LayoutParams(0, -2, 1));
            TextView play = tv("▶", 20, Overlay.ACCENT2, true);
            play.setPadding(dp(12), dp(4), dp(10), dp(4));
            play.setOnClickListener(v -> start(o.optString("task")));
            row.addView(play);
            TextView del = tv("🗑", 16, Overlay.MUTED, false);
            del.setPadding(dp(8), dp(4), dp(6), dp(4));
            del.setOnClickListener(v -> new AlertDialog.Builder(this).setMessage("Supprimer « " + o.optString("name") + " » ?")
                    .setPositiveButton("Supprimer", (x, y) -> { Cfg.removeRoutine(this, idx); build(); })
                    .setNegativeButton("Annuler", null).show());
            row.addView(del);
            rt.addView(row, mt(8));
        }
        col.addView(rt, mt(14));

        // ---------------------------------------------------------- réglages
        LinearLayout set = card();
        set.addView(tv("Réglages", 16, Overlay.TEXT, true));
        set.addView(tv("Clé API Claude (console.anthropic.com → API Keys). Elle reste sur ton téléphone.", 12, Overlay.MUTED, false), mt(8));
        final EditText key = field("sk-ant-…", true);
        key.setText(Cfg.key(this));
        set.addView(key, mt(6));
        TextView save = button("Enregistrer la clé", 0xFF3A3F55);
        save.setOnClickListener(v -> { Cfg.put(this, "key", key.getText().toString().trim()); toast("Clé enregistrée"); build(); });
        set.addView(save, mt(8));

        set.addView(tv("Cerveau", 13, Overlay.TEXT, true), mt(16));
        set.addView(choices(Cfg.MODEL_NAMES, java.util.Arrays.asList(Cfg.MODELS).indexOf(Cfg.model(this)),
                i -> Cfg.put(this, "model", Cfg.MODELS[i])), mt(6));

        set.addView(tv("Captures d'écran envoyées à l'IA", 13, Overlay.TEXT, true), mt(16));
        set.addView(choices(Cfg.VISION_NAMES, Cfg.vision(this), i -> Cfg.put(this, "vision", i)), mt(6));

        final TextView steps = tv("", 13, Overlay.TEXT, true);
        set.addView(steps, mt(16));
        SeekBar sb = new SeekBar(this);
        sb.setMax(50);
        sb.setProgress(Cfg.maxSteps(this) - 10);
        steps.setText("Étapes max par tâche : " + Cfg.maxSteps(this));
        sb.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar s, int p, boolean u) { steps.setText("Étapes max par tâche : " + (p + 10)); }
            @Override public void onStartTrackingTouch(SeekBar s) {}
            @Override public void onStopTrackingTouch(SeekBar s) { Cfg.put(MainActivity.this, "max_steps", s.getProgress() + 10); }
        });
        set.addView(sb, mt(4));

        final TextView guard = tv("", 14, Overlay.TEXT, false);
        guard.setPadding(dp(12), dp(10), dp(12), dp(10));
        guard.setBackground(round(Overlay.FIELD, 12));
        Runnable rg = () -> guard.setText((Cfg.guard(this) ? "☑ " : "☐ ") + "Toujours me demander avant d'envoyer, payer, acheter, supprimer ou appeler");
        rg.run();
        guard.setOnClickListener(v -> { Cfg.put(this, "guard", !Cfg.guard(this)); rg.run(); });
        set.addView(guard, mt(14));
        col.addView(set, mt(14));

        // ---------------------------------------------------------- historique
        JSONArray hs = Cfg.history(this);
        if (hs.length() > 0) {
            LinearLayout hi = card();
            hi.addView(tv("Dernières tâches", 16, Overlay.TEXT, true));
            SimpleDateFormat f = new SimpleDateFormat("dd/MM HH:mm", Locale.FRANCE);
            for (int i = 0; i < hs.length() && i < 12; i++) {
                JSONObject o = hs.optJSONObject(i);
                if (o == null) continue;
                LinearLayout row = new LinearLayout(this);
                row.setOrientation(LinearLayout.VERTICAL);
                row.setPadding(dp(12), dp(10), dp(12), dp(10));
                row.setBackground(round(Overlay.FIELD, 12));
                boolean ok = o.optBoolean("ok");
                TextView g = tv((ok ? "✓ " : "✕ ") + o.optString("goal"), 14, ok ? Overlay.ACCENT2 : Overlay.RED, true);
                g.setMaxLines(2);
                row.addView(g);
                TextView r = tv(o.optString("result"), 13, Overlay.TEXT, false);
                r.setTextIsSelectable(true);
                row.addView(r, mt(4));
                row.addView(tv(f.format(new Date(o.optLong("t"))) + " · " + o.optInt("steps") + " étapes · "
                        + (o.optInt("in") / 1000) + "k jetons lus / " + o.optInt("out") + " écrits", 11, Overlay.MUTED, false), mt(4));
                final String goal = o.optString("goal");
                row.setOnLongClickListener(v -> { start(goal); return true; });
                hi.addView(row, mt(8));
            }
            hi.addView(tv("Appui long sur une tâche pour la relancer.", 11, Overlay.MUTED, false), mt(8));
            col.addView(hi, mt(14));
        }

        col.addView(tv("Basé sur le moteur open source ARTEMIS de Google (licence Apache 2.0), adapté pour tourner entièrement sur le téléphone.",
                11, 0xFF5E5B78, false), mt(22));
        setContentView(sv);
    }

    private void start(String goal) {
        if (goal == null || goal.trim().isEmpty()) { toast("Écris d'abord une tâche"); return; }
        if (!enabled()) { toast("Active d'abord Artémis dans l'accessibilité"); startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); return; }
        if (Cfg.key(this).length() < 20) { toast("Ajoute ta clé API Claude dans Réglages"); return; }
        AgentService s = AgentService.I;
        if (s.running()) { toast("Une tâche est déjà en cours"); return; }
        GestureController.performGlobalAction(s, "home");
        new Handler().postDelayed(() -> s.start(goal), 700);
    }

    private void addRoutine(String prefill) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(20), dp(8), dp(20), 0);
        final EditText name = new EditText(this); name.setHint("Nom (ex. Météo)");
        final EditText task = new EditText(this); task.setHint("Ce qu'Artémis doit faire"); task.setText(prefill);
        task.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        box.addView(name); box.addView(task);
        new AlertDialog.Builder(this).setTitle("Nouvelle routine").setView(box)
                .setPositiveButton("Ajouter", (d, w) -> {
                    String n = name.getText().toString().trim(), t = task.getText().toString().trim();
                    if (!n.isEmpty() && !t.isEmpty()) { Cfg.addRoutine(this, n, t); build(); }
                })
                .setNegativeButton("Annuler", null).show();
    }

    // ------------------------------------------------------------------ helpers vue

    interface Pick { void on(int i); }

    private LinearLayout choices(String[] names, int sel, Pick pick) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        final TextView[] tvs = new TextView[names.length];
        for (int i = 0; i < names.length; i++) {
            final int idx = i;
            TextView t = tv(names[i], 14, Overlay.TEXT, false);
            t.setPadding(dp(12), dp(10), dp(12), dp(10));
            tvs[i] = t;
            t.setOnClickListener(v -> {
                pick.on(idx);
                for (int j = 0; j < tvs.length; j++) tvs[j].setBackground(round(j == idx ? 0x558B7BFF : Overlay.FIELD, 12));
            });
            t.setBackground(round(i == Math.max(0, sel) ? 0x558B7BFF : Overlay.FIELD, 12));
            LinearLayout.LayoutParams l = new LinearLayout.LayoutParams(-1, -2);
            l.bottomMargin = dp(6);
            box.addView(t, l);
        }
        return box;
    }

    private LinearLayout card() {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setPadding(dp(16), dp(14), dp(16), dp(16));
        c.setBackground(round(Overlay.CARD, 18));
        return c;
    }

    private EditText field(String hint, boolean secret) {
        EditText e = new EditText(this);
        e.setHint(hint);
        e.setHintTextColor(Overlay.MUTED);
        e.setTextColor(Overlay.TEXT);
        e.setTextSize(14);
        e.setBackground(round(Overlay.FIELD, 12));
        e.setPadding(dp(12), dp(10), dp(12), dp(10));
        e.setInputType(secret ? (InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD)
                : (InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES));
        return e;
    }

    private TextView tv(String s, float size, int color, boolean bold) {
        TextView t = new TextView(this);
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

    private GradientDrawable round(int color, int r) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(r));
        return g;
    }

    private LinearLayout.LayoutParams mt(int top) {
        LinearLayout.LayoutParams l = new LinearLayout.LayoutParams(-1, -2);
        l.topMargin = dp(top);
        return l;
    }

    private void toast(String s) { android.widget.Toast.makeText(this, s, android.widget.Toast.LENGTH_SHORT).show(); }
}
