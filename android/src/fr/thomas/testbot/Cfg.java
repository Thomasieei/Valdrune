package fr.thomas.testbot;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** Ce que le bot a appris pour un jeu donné (sauvegardé par jeu). */
final class Cfg {
    List<int[]> chest = new ArrayList<>(), enemy = new ArrayList<>();
    int[] player;
    /** fx, fy (fraction d'écran), luminosité de référence quand le sort est prêt */
    List<float[]> spells = new ArrayList<>();
    float[] joy;
    List<float[]> ignore = new ArrayList<>();
    int tol = 42, spellEvery = 700;
    String move = "auto"; // auto | joystick | toucher
    boolean autoSpells = true, autoChests = true, hunt = true, explore = true, popups = true;
    /** Mode auto : le bot découvre seul le jeu (déplacement, sorts, ennemis, butin). */
    boolean auto = true, calibrated = false, showSight = true;
    /** Points à ne jamais toucher (ouvrent un menu), en fractions d'écran. */
    List<float[]> avoid = new ArrayList<>();

    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("testbot", Context.MODE_PRIVATE); }

    static Cfg load(Context c, String pkg) {
        Cfg k = new Cfg();
        if (pkg == null) return k;
        String s = prefs(c).getString("cfg_" + pkg, null);
        if (s == null) return k;
        try {
            JSONObject o = new JSONObject(s);
            k.chest = ints(o.optJSONArray("chest"));
            k.enemy = ints(o.optJSONArray("enemy"));
            List<int[]> p = ints(o.optJSONArray("player"));
            k.player = p.isEmpty() ? null : p.get(0);
            k.spells = floats(o.optJSONArray("spells"));
            List<float[]> j = floats(o.optJSONArray("joy"));
            k.joy = j.isEmpty() ? null : j.get(0);
            k.ignore = floats(o.optJSONArray("ignore"));
            k.tol = o.optInt("tol", 42);
            k.spellEvery = o.optInt("spellEvery", 700);
            k.move = o.optString("move", "auto");
            k.autoSpells = o.optBoolean("autoSpells", true);
            k.autoChests = o.optBoolean("autoChests", true);
            k.hunt = o.optBoolean("hunt", true);
            k.explore = o.optBoolean("explore", true);
            k.popups = o.optBoolean("popups", true);
            k.auto = o.optBoolean("auto", true);
            k.showSight = o.optBoolean("showSight", true);
            k.calibrated = o.optBoolean("calibrated", false);
            k.avoid = floats(o.optJSONArray("avoid"));
        } catch (JSONException ignored) {}
        return k;
    }

    void save(Context c, String pkg) {
        if (pkg == null) return;
        try {
            JSONObject o = new JSONObject();
            o.put("chest", jInts(chest));
            o.put("enemy", jInts(enemy));
            List<int[]> p = new ArrayList<>(); if (player != null) p.add(player);
            o.put("player", jInts(p));
            o.put("spells", jFloats(spells));
            List<float[]> j = new ArrayList<>(); if (joy != null) j.add(joy);
            o.put("joy", jFloats(j));
            o.put("ignore", jFloats(ignore));
            o.put("tol", tol); o.put("spellEvery", spellEvery); o.put("move", move);
            o.put("autoSpells", autoSpells); o.put("autoChests", autoChests); o.put("hunt", hunt);
            o.put("explore", explore); o.put("popups", popups);
            o.put("auto", auto); o.put("showSight", showSight); o.put("calibrated", calibrated); o.put("avoid", jFloats(avoid));
            prefs(c).edit().putString("cfg_" + pkg, o.toString()).apply();
        } catch (JSONException ignored) {}
    }

    void clearLearned() {
        chest.clear(); enemy.clear(); player = null; spells.clear(); joy = null; ignore.clear(); avoid.clear(); calibrated = false;
    }

    private static List<int[]> ints(JSONArray a) throws JSONException {
        List<int[]> out = new ArrayList<>();
        if (a == null) return out;
        for (int i = 0; i < a.length(); i++) {
            JSONArray e = a.getJSONArray(i); int[] v = new int[e.length()];
            for (int k = 0; k < v.length; k++) v[k] = e.getInt(k);
            out.add(v);
        }
        return out;
    }

    private static List<float[]> floats(JSONArray a) throws JSONException {
        List<float[]> out = new ArrayList<>();
        if (a == null) return out;
        for (int i = 0; i < a.length(); i++) {
            JSONArray e = a.getJSONArray(i); float[] v = new float[e.length()];
            for (int k = 0; k < v.length; k++) v[k] = (float) e.getDouble(k);
            out.add(v);
        }
        return out;
    }

    private static JSONArray jInts(List<int[]> l) {
        JSONArray a = new JSONArray();
        for (int[] v : l) { JSONArray e = new JSONArray(); for (int x : v) e.put(x); a.put(e); }
        return a;
    }

    private static JSONArray jFloats(List<float[]> l) throws JSONException {
        JSONArray a = new JSONArray();
        for (float[] v : l) { JSONArray e = new JSONArray(); for (float x : v) e.put((double) x); a.put(e); }
        return a;
    }
}
