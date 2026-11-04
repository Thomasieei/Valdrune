package fr.thomas.artemis;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

/** Réglages, routines et historique, stockés localement sur le téléphone. */
final class Cfg {
    private Cfg() {}

    static final String[] MODELS = {"claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5"};
    static final String[] MODEL_NAMES = {"Haiku 5.5 — rapide, économique", "Sonnet 5.5 — plus fiable", "Opus 5.5 — le plus malin, cher"};
    static final String[] VISION_NAMES = {"Auto (capture seulement si utile)", "Toujours (plus précis, plus cher)", "Jamais (texte seul, le moins cher)"};

    static SharedPreferences p(Context c) { return c.getSharedPreferences("artemis", Context.MODE_PRIVATE); }

    static String key(Context c) { return p(c).getString("key", "").trim(); }
    static String model(Context c) { return p(c).getString("model", MODELS[0]); }
    static int vision(Context c) { return p(c).getInt("vision", 0); }
    static int maxSteps(Context c) { return p(c).getInt("max_steps", 30); }
    static boolean guard(Context c) { return p(c).getBoolean("guard", true); }

    static void put(Context c, String k, Object v) {
        SharedPreferences.Editor e = p(c).edit();
        if (v instanceof Integer) e.putInt(k, (Integer) v);
        else if (v instanceof Boolean) e.putBoolean(k, (Boolean) v);
        else e.putString(k, String.valueOf(v));
        e.apply();
    }

    // ------------------------------------------------------------------ routines

    static JSONArray routines(Context c) {
        String s = p(c).getString("routines", null);
        try {
            if (s != null) return new JSONArray(s);
        } catch (Exception ignored) {}
        JSONArray a = new JSONArray();
        addTo(a, "Météo", "Ouvre l'appli météo et dis-moi le temps qu'il fera aujourd'hui et demain à Brignoles.");
        addTo(a, "Résumé notifs", "Ouvre le volet des notifications, lis-les toutes et fais-moi un résumé court de ce qui est important. N'efface rien.");
        addTo(a, "Batterie", "Ouvre les paramètres de batterie et dis-moi quelles applis consomment le plus.");
        return a;
    }

    private static void addTo(JSONArray a, String name, String task) {
        try { a.put(new JSONObject().put("name", name).put("task", task)); } catch (Exception ignored) {}
    }

    static void addRoutine(Context c, String name, String task) {
        JSONArray a = routines(c);
        addTo(a, name, task);
        put(c, "routines", a.toString());
    }

    static void removeRoutine(Context c, int i) {
        JSONArray a = routines(c);
        a.remove(i);
        put(c, "routines", a.toString());
    }

    // ------------------------------------------------------------------ historique

    static JSONArray history(Context c) {
        try { return new JSONArray(p(c).getString("history", "[]")); } catch (Exception e) { return new JSONArray(); }
    }

    static void addHistory(Context c, String goal, String result, boolean ok, int steps, int tokIn, int tokOut) {
        JSONArray old = history(c), a = new JSONArray();
        try {
            a.put(new JSONObject().put("t", System.currentTimeMillis()).put("goal", goal).put("result", result)
                    .put("ok", ok).put("steps", steps).put("in", tokIn).put("out", tokOut));
            for (int i = 0; i < old.length() && a.length() < 20; i++) a.put(old.get(i));
        } catch (Exception ignored) {}
        put(c, "history", a.toString());
    }
}
