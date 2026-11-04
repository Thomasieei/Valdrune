package com.thomas.botlab;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.projection.MediaProjectionManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {
    private static final int REQ_CAPTURE = 7;
    private static final int GOLD = 0xFFF2B33D, CYAN = 0xFF3ED6E0, BG = 0xFF0E1116, CARD = 0xFF171C24,
            OK = 0xFF4CFF7A, KO = 0xFFFF8A3D, DIM = 0xFF8A94A6;
    private LinearLayout root;
    private TextView stAcc, stCap, stCal, logInfo;
    private TextView[] modeBtns = new TextView[3];
    private final Handler h = new Handler(Looper.getMainLooper());
    private Config cfg;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        BotLog.init(this);
        cfg = Config.get(this);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        ScrollView sv = new ScrollView(this);
        sv.setBackgroundColor(BG);
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(22), dp(18), dp(40));
        sv.addView(root);
        setContentView(sv);

        TextView title = text("ALBION BOT LAB", 26, GOLD, true);
        title.setLetterSpacing(0.08f);
        root.addView(title);
        root.addView(text("Bot de test pour vidéo YouTube — vision par l'écran, appuis simulés, journal complet.", 13, DIM, false));
        gap(14);

        // --- État
        LinearLayout st = card("ÉTAT");
        stAcc = statusRow(st, "1. Service d'accessibilité", "Ouvrir", v -> openAccessibility());
        stCap = statusRow(st, "2. Capture d'écran", "Lancer", v -> startCapture());
        stCal = statusRow(st, "3. Calibrage (en jeu, bouton ◎)", null, null);
        LinearLayout row = new LinearLayout(this);
        row.addView(button("Arrêter la capture", KO, v -> {
            CaptureService cs = CaptureService.instance; if (cs != null) cs.stopAll();
            h.postDelayed(this::refresh, 300);
        }), weight());
        row.addView(spacer(8));
        row.addView(button("Réglages de l'appli", DIM, v -> openAppInfo()), weight());
        st.addView(row);

        // --- Mode d'emploi
        LinearLayout help = card("MODE D'EMPLOI");
        help.addView(text(
            "1. Touchez « Ouvrir » et activez Albion Bot Lab dans l'accessibilité.\n" +
            "   Si l'option est grisée (Xiaomi, Android 13+) : « Réglages de l'appli » → ⋮ en haut à droite → « Autoriser les paramètres restreints », puis recommencez.\n\n" +
            "2. Touchez « Lancer » et choisissez « Écran entier » (pas une seule appli).\n\n" +
            "3. Ouvrez Albion Online en paysage. La bulle du bot apparaît (déplaçable par ⠿).\n\n" +
            "4. ◎ Calibrer, vie pleine et sorts prêts : barre de vie (gauche puis droite), vos sorts, une barre de vie ennemie, le bouton d'action.\n\n" +
            "5. ▶ démarrer · ⏸ pause · 👁 masquer la vision · 🧪 tester les appuis · 📸 photo de ce que voit le bot (Galerie › AlbionBotLab) · ■ tout arrêter.\n\n" +
            "Xiaomi : Réglages de l'appli → Économiseur de batterie → « Aucune restriction », sinon MIUI coupe le bot.",
            13, 0xFFD5DCE6, false));

        // --- Mode
        LinearLayout md = card("COMPORTEMENT");
        LinearLayout seg = new LinearLayout(this);
        String[] names = {"Combat", "Récolte", "Mixte"};
        for (int i = 0; i < 3; i++) {
            final int m = i;
            TextView t = text(names[i], 14, 0xFFFFFFFF, true);
            t.setGravity(Gravity.CENTER); t.setPadding(0, dp(10), 0, dp(10));
            t.setOnClickListener(v -> { cfg.mode = m; cfg.save(); refreshMode(); BotLog.log("Mode : " + names[m]); });
            modeBtns[i] = t;
            seg.addView(t, weight());
            if (i < 2) seg.addView(spacer(6));
        }
        md.addView(seg);
        md.addView(text("Combat : cible et tue tout ce qui est hostile. Récolte : appuie sur le bouton d'action, ne se défend que de près. Mixte : les deux.", 12, DIM, false));
        refreshMode();
        gap(4);
        slider(md, "Sort de soin", 0, 6, cfg.healSlot, v -> v == 0 ? "aucun" : "sort " + v, v -> cfg.healSlot = v);
        slider(md, "Se soigner sous", 10, 90, cfg.healPct, v -> v + " % de vie", v -> cfg.healPct = v);
        slider(md, "Fuir sous", 0, 60, cfg.fleePct, v -> v == 0 ? "jamais" : v + " % de vie", v -> cfg.fleePct = v);
        slider(md, "Délai entre deux sorts", 300, 3000, cfg.spellIntervalMs, v -> v + " ms", v -> cfg.spellIntervalMs = v);
        slider(md, "Re-cibler toutes les", 800, 6000, cfg.retargetMs, v -> String.format("%.1f s", v / 1000f), v -> cfg.retargetMs = v);
        slider(md, "Explorer après", 1000, 15000, cfg.exploreAfterMs, v -> String.format("%.0f s sans ennemi", v / 1000f), v -> cfg.exploreAfterMs = v);

        LinearLayout vis = card("VISION");
        slider(vis, "Tolérance couleur ennemie", 20, 140, cfg.colorTol, v -> v + (v < 50 ? " (strict)" : v > 100 ? " (large)" : ""), v -> cfg.colorTol = v);
        slider(vis, "Ignorer le haut de l'écran", 0, 30, cfg.topExcludePct, v -> v + " %", v -> cfg.topExcludePct = v);
        vis.addView(text("Le bot repère les barres de vie de la couleur mesurée au calibrage (rouge par défaut). Trop de fausses cibles → baissez la tolérance. Aucune cible → montez-la ou recalibrez la couleur.", 12, DIM, false));

        // --- Journal
        LinearLayout lg = card("JOURNAL (preuve pour le studio)");
        logInfo = text("", 12, DIM, false);
        lg.addView(logInfo);
        LinearLayout lr = new LinearLayout(this);
        lr.addView(button("Partager le journal", CYAN, v -> shareLog()), weight());
        lr.addView(spacer(8));
        lr.addView(button("Effacer", KO, v -> { BotLog.clear(); BotLog.log("Journal effacé"); refresh(); }), weight());
        lg.addView(lr);

        root.addView(text("Version " + versionName(), 11, DIM, false));

        if (Build.VERSION.SDK_INT >= 33) requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 3);
    }

    @Override protected void onResume() { super.onResume(); refresh(); h.postDelayed(tick, 1000); }
    @Override protected void onPause() { super.onPause(); h.removeCallbacks(tick); }
    private final Runnable tick = new Runnable() { public void run() { refresh(); h.postDelayed(this, 1000); } };

    private void refresh() {
        boolean acc = BotService.instance != null, cap = CaptureService.instance != null;
        setStatus(stAcc, acc, acc ? "activé" : "désactivé");
        setStatus(stCap, cap, cap ? "en cours" : "arrêtée");
        setStatus(stCal, cfg.calibrated, cfg.summary());
        logInfo.setText(String.format("Taille : %.1f Ko — chaque décision et chaque appui est horodaté.", BotLog.size() / 1024f));
    }

    private void setStatus(TextView t, boolean ok, String s) { t.setText((ok ? "✔ " : "✘ ") + s); t.setTextColor(ok ? OK : KO); }

    private void refreshMode() {
        for (int i = 0; i < 3; i++) {
            GradientDrawable g = new GradientDrawable();
            g.setCornerRadius(dp(8));
            g.setColor(cfg.mode == i ? 0xFF3A2E12 : 0xFF222A36);
            g.setStroke(dp(1.5f), cfg.mode == i ? GOLD : 0xFF2E3846);
            modeBtns[i].setBackground(g);
            modeBtns[i].setTextColor(cfg.mode == i ? GOLD : 0xFFD5DCE6);
        }
    }

    private void openAccessibility() {
        startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
        Toast.makeText(this, "Cherchez « Albion Bot Lab » (parfois dans « Applications téléchargées »)", Toast.LENGTH_LONG).show();
    }

    private void openAppInfo() {
        startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + getPackageName())));
    }

    private void startCapture() {
        if (CaptureService.instance != null) { Toast.makeText(this, "La capture tourne déjà", Toast.LENGTH_SHORT).show(); return; }
        MediaProjectionManager m = getSystemService(MediaProjectionManager.class);
        startActivityForResult(m.createScreenCaptureIntent(), REQ_CAPTURE);
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req != REQ_CAPTURE) return;
        if (res != RESULT_OK || data == null) { Toast.makeText(this, "Capture refusée", Toast.LENGTH_SHORT).show(); return; }
        Intent s = new Intent(this, CaptureService.class).putExtra("code", res).putExtra("data", data);
        startForegroundService(s);
        Toast.makeText(this, "Capture lancée — ouvrez Albion", Toast.LENGTH_LONG).show();
        h.postDelayed(this::refresh, 600);
    }

    private void shareLog() {
        String log = "Albion Bot Lab — journal d'activité\nAppareil : " + Build.MANUFACTURER + " " + Build.MODEL
                + " (Android " + Build.VERSION.RELEASE + ")\n" + cfg.summary() + "\n\n" + BotLog.read();
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_SUBJECT, "Journal Albion Bot Lab");
        i.putExtra(Intent.EXTRA_TEXT, log);
        startActivity(Intent.createChooser(i, "Partager le journal"));
    }

    // ---------- UI helpers ----------
    interface Fmt { String f(int v); }
    interface Set { void s(int v); }

    private void slider(LinearLayout parent, String name, int min, int max, int val, Fmt fmt, Set set) {
        TextView lab = text("", 13, 0xFFD5DCE6, false);
        lab.setPadding(0, dp(10), 0, 0);
        SeekBar sb = new SeekBar(this);
        sb.setMax(max - min);
        sb.setProgress(Math.max(0, Math.min(max - min, val - min)));
        lab.setText(name + " : " + fmt.f(val));
        sb.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar s, int p, boolean u) { lab.setText(name + " : " + fmt.f(p + min)); if (u) { set.s(p + min); cfg.save(); } }
            public void onStartTrackingTouch(SeekBar s) { }
            public void onStopTrackingTouch(SeekBar s) { BotLog.log("Réglage : " + lab.getText()); }
        });
        parent.addView(lab);
        parent.addView(sb);
    }

    private LinearLayout card(String title) {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setPadding(dp(14), dp(12), dp(14), dp(14));
        GradientDrawable g = new GradientDrawable();
        g.setColor(CARD); g.setCornerRadius(dp(14)); g.setStroke(dp(1), 0xFF252D3A);
        c.setBackground(g);
        TextView t = text(title, 12, CYAN, true);
        t.setLetterSpacing(0.12f);
        t.setPadding(0, 0, 0, dp(8));
        c.addView(t);
        root.addView(c);
        gap(12);
        return c;
    }

    private TextView statusRow(LinearLayout parent, String label, String btn, View.OnClickListener l) {
        LinearLayout r = new LinearLayout(this);
        r.setGravity(Gravity.CENTER_VERTICAL);
        r.setPadding(0, dp(4), 0, dp(4));
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.addView(text(label, 14, 0xFFFFFFFF, true));
        TextView st = text("…", 12, DIM, false);
        col.addView(st);
        r.addView(col, weight());
        if (btn != null) r.addView(button(btn, GOLD, l));
        parent.addView(r);
        return st;
    }

    private TextView button(String t, int color, View.OnClickListener l) {
        TextView b = text(t, 13, color, true);
        b.setGravity(Gravity.CENTER);
        b.setPadding(dp(14), dp(10), dp(14), dp(10));
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(10)); g.setColor(0xFF1E2530); g.setStroke(dp(1.5f), color);
        b.setBackground(g);
        b.setOnClickListener(l);
        return b;
    }

    private TextView text(String s, float sp, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s); t.setTextSize(sp); t.setTextColor(color);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setLineSpacing(0, 1.15f);
        return t;
    }

    private LinearLayout.LayoutParams weight() { return new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1); }
    private View spacer(int w) { View v = new View(this); v.setLayoutParams(new LinearLayout.LayoutParams(dp(w), 1)); return v; }
    private void gap(int hdp) { View v = new View(this); v.setLayoutParams(new LinearLayout.LayoutParams(1, dp(hdp))); root.addView(v); }
    private int dp(float v) { return Math.round(v * getResources().getDisplayMetrics().density); }
    private String versionName() {
        try { return getPackageManager().getPackageInfo(getPackageName(), 0).versionName; } catch (Exception e) { return "?"; }
    }
}
