package com.thomas.botlab;

import android.content.Context;
import android.content.SharedPreferences;

/** Tous les réglages et le calibrage, persistés. Coordonnées en pixels écran réels. */
public class Config {
    private static Config inst;
    private final SharedPreferences sp;

    public int hpLx = -1, hpLy = -1, hpRx = -1, hpRy = -1, hpColor = 0;
    public int[] spellX = new int[0], spellY = new int[0];
    public float[] spellLum = new float[0];
    public int actionX = -1, actionY = -1;
    public int enemyColor = 0xC8261E;
    public boolean enemyColorSampled = false;
    public boolean calibrated = false;

    public int mode = 0;            // 0 combat, 1 récolte, 2 mixte
    public int healSlot = 0;        // 0 = aucun, sinon 1..6
    public int healPct = 55;
    public int fleePct = 25;
    public int spellIntervalMs = 900;
    public int colorTol = 70;
    public int topExcludePct = 8;
    public int retargetMs = 2500;
    public int exploreAfterMs = 3000;

    public static synchronized Config get(Context c) {
        if (inst == null) inst = new Config(c.getApplicationContext());
        return inst;
    }

    private Config(Context c) {
        sp = c.getSharedPreferences("botlab", Context.MODE_PRIVATE);
        hpLx = sp.getInt("hpLx", -1); hpLy = sp.getInt("hpLy", -1);
        hpRx = sp.getInt("hpRx", -1); hpRy = sp.getInt("hpRy", -1);
        hpColor = sp.getInt("hpColor", 0);
        spellX = ints(sp.getString("spellX", "")); spellY = ints(sp.getString("spellY", ""));
        spellLum = floats(sp.getString("spellLum", ""));
        if (spellY.length != spellX.length) { spellX = new int[0]; spellY = new int[0]; }
        if (spellLum.length != spellX.length) spellLum = new float[spellX.length];
        actionX = sp.getInt("actionX", -1); actionY = sp.getInt("actionY", -1);
        enemyColor = sp.getInt("enemyColor", 0xC8261E);
        enemyColorSampled = sp.getBoolean("enemySampled", false);
        calibrated = sp.getBoolean("calibrated", false);
        mode = sp.getInt("mode", 0); healSlot = sp.getInt("healSlot", 0);
        healPct = sp.getInt("healPct", 55); fleePct = sp.getInt("fleePct", 25);
        spellIntervalMs = sp.getInt("spellIntervalMs", 900); colorTol = sp.getInt("colorTol", 70);
        topExcludePct = sp.getInt("topExcludePct", 8); retargetMs = sp.getInt("retargetMs", 2500);
        exploreAfterMs = sp.getInt("exploreAfterMs", 3000);
    }

    public synchronized void save() {
        sp.edit()
            .putInt("hpLx", hpLx).putInt("hpLy", hpLy).putInt("hpRx", hpRx).putInt("hpRy", hpRy)
            .putInt("hpColor", hpColor)
            .putString("spellX", csv(spellX)).putString("spellY", csv(spellY))
            .putString("spellLum", csv(spellLum))
            .putInt("actionX", actionX).putInt("actionY", actionY)
            .putInt("enemyColor", enemyColor).putBoolean("enemySampled", enemyColorSampled)
            .putBoolean("calibrated", calibrated)
            .putInt("mode", mode).putInt("healSlot", healSlot).putInt("healPct", healPct)
            .putInt("fleePct", fleePct).putInt("spellIntervalMs", spellIntervalMs)
            .putInt("colorTol", colorTol).putInt("topExcludePct", topExcludePct)
            .putInt("retargetMs", retargetMs).putInt("exploreAfterMs", exploreAfterMs)
            .apply();
    }

    public String summary() {
        if (!calibrated) return "Non calibré — touchez ◎ sur la bulle, en jeu";
        StringBuilder b = new StringBuilder();
        b.append(hpLx >= 0 && hpColor != 0 ? "Vie ✔" : "Vie ✘");
        b.append(" · ").append(spellX.length).append(" sort(s)");
        b.append(" · ennemi ").append(enemyColorSampled ? "mesuré" : "rouge par défaut");
        b.append(" · action ").append(actionX >= 0 ? "✔" : "✘");
        return b.toString();
    }

    private static String csv(int[] a) { StringBuilder b = new StringBuilder(); for (int i = 0; i < a.length; i++) { if (i > 0) b.append(','); b.append(a[i]); } return b.toString(); }
    private static String csv(float[] a) { StringBuilder b = new StringBuilder(); for (int i = 0; i < a.length; i++) { if (i > 0) b.append(','); b.append(a[i]); } return b.toString(); }
    private static int[] ints(String s) {
        if (s == null || s.isEmpty()) return new int[0];
        String[] p = s.split(","); int[] r = new int[p.length];
        try { for (int i = 0; i < p.length; i++) r[i] = Integer.parseInt(p[i].trim()); } catch (Exception e) { return new int[0]; }
        return r;
    }
    private static float[] floats(String s) {
        if (s == null || s.isEmpty()) return new float[0];
        String[] p = s.split(","); float[] r = new float[p.length];
        try { for (int i = 0; i < p.length; i++) r[i] = Float.parseFloat(p[i].trim()); } catch (Exception e) { return new float[0]; }
        return r;
    }
}
