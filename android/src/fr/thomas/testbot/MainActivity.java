package fr.thomas.testbot;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.drawable.Drawable;
import android.media.projection.MediaProjectionConfig;
import android.media.projection.MediaProjectionManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Écran d'accueil : 2 autorisations, puis choix du jeu à tester. */
public class MainActivity extends Activity {
    private static final int REQ_CAP = 7;
    private TextView s1, s2, b1, b2, gameNow, lastRep;
    private LinearLayout apps;
    private final Handler h = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        Window w = getWindow();
        w.setStatusBarColor(Ui.BG);
        w.setNavigationBarColor(Ui.BG);

        ScrollView sc = new ScrollView(this);
        sc.setBackgroundColor(Ui.BG);
        sc.setFillViewport(true);
        LinearLayout root = Ui.col(this);
        int p = Ui.dp(this, 18);
        root.setPadding(p, Ui.dp(this, 26), p, Ui.dp(this, 30));
        sc.addView(root);

        TextView logo = Ui.mono(this, "TESTBOT", 15, Ui.AMBER);
        logo.setLetterSpacing(0.2f);
        root.addView(logo);
        TextView title = Ui.text(this, "Le bot qui joue à tes jeux pour les tester", 25, Ui.FG, true);
        root.addView(title, Ui.margins(Ui.full(), this, 0, 8, 0, 4));
        root.addView(Ui.text(this, "Il se déplace, lance les sorts, ramasse les coffres et note quand le jeu plante.", 14, Ui.MUTE, false));

        // Étape 1 : service d'accessibilité (les doigts du bot)
        LinearLayout c1 = card(root, "1", "Donner les mains au bot",
                "Dans les réglages, va dans Accessibilité → Applications téléchargées → TestBot, et active-le. C'est ce qui lui permet de toucher l'écran.");
        s1 = status(c1);
        b1 = Ui.button(this, "Ouvrir les réglages d'accessibilité", Ui.CARD2, Ui.FG, Ui.LINE);
        b1.setOnClickListener(v -> {
            try { startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); }
            catch (Exception e) { toast("Ouvre Réglages → Accessibilité"); }
        });
        c1.addView(b1, Ui.margins(Ui.full(), this, 0, 10, 0, 0));

        // Étape 2 : vue de l'écran (les yeux du bot)
        LinearLayout c2 = card(root, "2", "Donner les yeux au bot",
                "Android va demander l'autorisation de voir l'écran. Choisis « Écran entier ». À refaire après un redémarrage du téléphone.");
        s2 = status(c2);
        b2 = Ui.button(this, "Autoriser la vue de l'écran", Ui.CARD2, Ui.FG, Ui.LINE);
        b2.setOnClickListener(v -> askCapture());
        c2.addView(b2, Ui.margins(Ui.full(), this, 0, 10, 0, 0));

        // Étape 3 : le jeu
        LinearLayout c3 = card(root, "3", "Choisir le jeu à tester",
                "Touche ton jeu : il s'ouvre avec la bulle BOT par-dessus. Touche la bulle puis Lancer. En mode auto, le bot calibre seul le jeu (≈15 s) : déplacement, sorts, ennemis, butin. Rien à lui apprendre.");
        gameNow = Ui.text(this, "", 13, Ui.CYAN, true);
        c3.addView(gameNow, Ui.margins(Ui.full(), this, 0, 8, 0, 0));
        TextView showBot = Ui.button(this, "Afficher la bulle sans changer de jeu", Ui.CARD2, Ui.FG, Ui.LINE);
        showBot.setOnClickListener(v -> {
            BotService s = BotService.inst;
            if (s == null) { toast("Active d'abord TestBot dans l'accessibilité (étape 1)"); return; }
            s.showBubble();
            moveTaskToBack(true);
        });
        c3.addView(showBot, Ui.margins(Ui.full(), this, 0, 10, 0, 0));
        apps = Ui.col(this);
        c3.addView(apps, Ui.margins(Ui.full(), this, 0, 10, 0, 0));

        // Dernier rapport
        LinearLayout c4 = card(root, null, "Dernier rapport", null);
        lastRep = Ui.mono(this, "", 11, Ui.FG);
        lastRep.setTypeface(android.graphics.Typeface.MONOSPACE);
        c4.addView(lastRep, Ui.margins(Ui.full(), this, 0, 6, 0, 0));
        TextView copy = Ui.button(this, "Copier le rapport", Ui.CARD2, Ui.FG, Ui.LINE);
        copy.setOnClickListener(v -> {
            String r = Cfg.prefs(this).getString("last_report", null);
            if (r == null) { toast("Pas encore de rapport"); return; }
            ((ClipboardManager) getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("Rapport TestBot", r));
            toast("Rapport copié");
        });
        c4.addView(copy, Ui.margins(Ui.full(), this, 0, 10, 0, 0));

        setContentView(sc);
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED)
            requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 1);
        loadApps();
    }

    @Override
    protected void onResume() {
        super.onResume();
        refresh();
        h.postDelayed(this::refresh, 800);
    }

    private void refresh() {
        boolean a = BotService.inst != null, c = CaptureService.running();
        setStatus(s1, a, "Activé", "À activer");
        setStatus(s2, c, "Autorisée", "À autoriser");
        b1.setVisibility(a ? View.GONE : View.VISIBLE);
        b2.setText(c ? "Autoriser à nouveau" : "Autoriser la vue de l'écran");
        BotService s = BotService.inst;
        String g = Cfg.prefs(this).getString("gameLabel", null);
        gameNow.setText(g == null ? "Aucun jeu choisi" : "Jeu actuel : " + g + (s != null ? " · " + s.learnedSummary() : ""));
        String r = Cfg.prefs(this).getString("last_report", null);
        lastRep.setText(r == null ? "Lance le bot sur un jeu : son rapport s'affichera ici." : r);
    }

    private void askCapture() {
        MediaProjectionManager m = (MediaProjectionManager) getSystemService(MEDIA_PROJECTION_SERVICE);
        Intent i;
        if (Build.VERSION.SDK_INT >= 34) i = m.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay());
        else i = m.createScreenCaptureIntent();
        try { startActivityForResult(i, REQ_CAP); } catch (Exception e) { toast("Impossible d'ouvrir la demande d'autorisation"); }
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req != REQ_CAP) return;
        if (res != RESULT_OK || data == null) { toast("Sans la vue de l'écran, le bot ne voit pas les coffres"); return; }
        stopService(new Intent(this, CaptureService.class));
        Intent s = new Intent(this, CaptureService.class).putExtra(CaptureService.EX_CODE, res).putExtra(CaptureService.EX_DATA, data);
        h.postDelayed(() -> {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(s); else startService(s);
            h.postDelayed(this::refresh, 900);
        }, 300);
    }

    private void loadApps() {
        PackageManager pm = getPackageManager();
        Intent q = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> list = pm.queryIntentActivities(q, 0);
        List<ResolveInfo> mine = new ArrayList<>();
        for (ResolveInfo r : list) {
            ApplicationInfo ai = r.activityInfo.applicationInfo;
            if (ai.packageName.equals(getPackageName())) continue;
            boolean sys = (ai.flags & ApplicationInfo.FLAG_SYSTEM) != 0 && (ai.flags & ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0;
            if (!sys) mine.add(r);
        }
        Collections.sort(mine, (x, y) -> String.valueOf(x.loadLabel(pm)).compareToIgnoreCase(String.valueOf(y.loadLabel(pm))));
        if (mine.isEmpty()) apps.addView(Ui.text(this, "Aucune appli installée trouvée.", 13, Ui.MUTE, false));
        for (ResolveInfo r : mine) {
            final String pkg = r.activityInfo.packageName;
            final String label = String.valueOf(r.loadLabel(pm));
            LinearLayout row = Ui.row(this);
            row.setBackground(Ui.box(this, Ui.CARD2, 12, 0));
            int pd = Ui.dp(this, 10);
            row.setPadding(pd, pd, pd, pd);
            ImageView ic = new ImageView(this);
            try { Drawable d = r.loadIcon(pm); ic.setImageDrawable(d); } catch (Exception ignored) {}
            int s = Ui.dp(this, 38);
            row.addView(ic, new LinearLayout.LayoutParams(s, s));
            LinearLayout tx = Ui.col(this);
            tx.setPadding(Ui.dp(this, 12), 0, 0, 0);
            tx.addView(Ui.text(this, label, 15, Ui.FG, true));
            TextView pk = Ui.text(this, pkg, 11, Ui.MUTE, false);
            pk.setSingleLine(true);
            tx.addView(pk);
            row.addView(tx, Ui.weight(1));
            TextView go = Ui.text(this, "Tester", 13, Ui.AMBER, true);
            go.setGravity(Gravity.CENTER);
            row.addView(go, Ui.wrap());
            Ui.pressable(row);
            row.setOnClickListener(v -> launch(pkg, label));
            apps.addView(row, Ui.margins(Ui.full(), this, 0, 0, 0, 6));
        }
    }

    private void launch(String pkg, String label) {
        BotService s = BotService.inst;
        if (s == null) { toast("Active d'abord TestBot dans l'accessibilité (étape 1)"); return; }
        if (!CaptureService.running()) toast("Pense à autoriser la vue de l'écran (étape 2)");
        s.prepare(pkg, label);
        Intent i = getPackageManager().getLaunchIntentForPackage(pkg);
        if (i == null) { toast("Impossible d'ouvrir ce jeu"); return; }
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(i);
    }

    private LinearLayout card(LinearLayout root, String num, String title, String body) {
        LinearLayout c = Ui.col(this);
        c.setBackground(Ui.box(this, Ui.CARD, 16, 0));
        int p = Ui.dp(this, 16);
        c.setPadding(p, p, p, p);
        LinearLayout hd = Ui.row(this);
        if (num != null) {
            TextView n = Ui.mono(this, num, 13, Ui.AMBER);
            n.setGravity(Gravity.CENTER);
            n.setBackground(Ui.box(this, Ui.CARD2, 8, 0));
            int s = Ui.dp(this, 28);
            hd.addView(n, Ui.margins(new LinearLayout.LayoutParams(s, s), this, 0, 0, 10, 0));
        }
        hd.addView(Ui.text(this, title, 17, Ui.FG, true), Ui.weight(1));
        c.addView(hd);
        if (body != null) c.addView(Ui.text(this, body, 13.5f, Ui.MUTE, false), Ui.margins(Ui.full(), this, 0, 8, 0, 0));
        root.addView(c, Ui.margins(Ui.full(), this, 0, 16, 0, 0));
        return c;
    }

    private TextView status(LinearLayout card) {
        TextView t = Ui.mono(this, "", 12, Ui.MUTE);
        LinearLayout hd = (LinearLayout) card.getChildAt(0);
        hd.addView(t, Ui.wrap());
        return t;
    }

    private void setStatus(TextView t, boolean ok, String yes, String no) {
        t.setText(ok ? yes : no);
        t.setTextColor(ok ? Ui.OK : Ui.CORAL);
    }

    private void toast(String m) { Toast.makeText(this, m, Toast.LENGTH_LONG).show(); }
}
