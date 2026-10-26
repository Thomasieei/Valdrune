package fr.thomas.testbot;

import android.content.Context;
import android.graphics.Bitmap;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Base64;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.Locale;

/**
 * Cerveau IA : envoie une capture de l'écran à Claude, qui comprend le jeu
 * (genre, commandes, objectif, balle, voiture, ennemis, butin), aide le bot quand il est perdu
 * (menus, fin de match) et joue lui-même les jeux qu'aucun cerveau réflexe ne connaît.
 */
final class AiBrain {
    private static final String API = "https://api.anthropic.com/v1/messages";

    private final BotService b;
    private HandlerThread th;
    private Handler nh;
    private volatile boolean busy;
    private long lastCall, lastAudit;
    int calls, tokIn, tokOut, errors;
    volatile String note = "";
    private boolean analyzeAsked;

    /** Actions demandées par l'IA, exécutées une par une. */
    private static final class Act { String type; float x, y, dx, dy; long ms; }
    private final ArrayDeque<Act> queue = new ArrayDeque<>();
    private Act cur;
    private long curUntil;

    AiBrain(BotService b) { this.b = b; }

    boolean hasKey() { return Cfg.aiKey(b).length() > 20; }
    boolean busy() { return busy; }
    boolean executing() { return cur != null || !queue.isEmpty(); }

    void reset() { queue.clear(); cur = null; analyzeAsked = false; }

    // ------------------------------------------------------------------ demandes

    /** Première découverte du jeu : genre, commandes, objectif. */
    void analyze(long t) {
        if (!hasKey() || busy) return;
        analyzeAsked = true;
        send(t, true, "Première découverte de ce jeu.");
    }

    /** Le bot est perdu : l'IA dit quoi toucher. setup = il manque des infos de base (relance une analyse). */
    void help(long t, String why, boolean setup) {
        if (!hasKey() || busy || t - lastCall < 6000) return;
        if (setup) { if (!analyzeAsked) analyze(t); return; }
        send(t, false, why);
    }

    /** Toutes les 40 s : l'IA vérifie l'écran et signale les bugs visuels. */
    void audit(long t) {
        if (!hasKey() || busy) return;
        if (t - lastAudit < 40000 || t - lastCall < 6000) return;
        lastAudit = t;
        send(t, false, "Vérification de routine : signale tout bug visuel. Si tout va bien, renvoie actions vide.");
    }

    // ------------------------------------------------------------------ exécution des actions

    /** Mode IA directe : demande la suite dès que la file est vide. */
    void tickDirect(long t) {
        if (!executing() && !busy && t - lastCall > 2500) send(t, false, "Joue : donne les actions des 3 prochaines secondes pour progresser.");
        tickActions(t);
        if (!executing()) b.status = busy ? "L'IA réfléchit…" : "IA : " + note;
    }

    void tickActions(long t) {
        if (cur != null && t < curUntil) return;
        if (cur != null) { b.joyWant = null; b.holdStart = null; cur = null; }
        Act a = queue.poll();
        if (a == null) return;
        cur = a;
        float sw = b.sw, sh = b.sh;
        switch (a.type) {
            case "toucher":
                b.tap(a.x * sw, a.y * sh); curUntil = t + 300;
                b.status = "IA : je touche";
                break;
            case "joystick":
                if (b.cfg.joy != null) {
                    float r = BotService.dpS(b, 48), l = (float) Math.max(0.01, Math.hypot(a.dx, a.dy));
                    b.holdStart = null;
                    b.joyWant = new float[]{b.cfg.joy[0] * sw + a.dx / l * r, b.cfg.joy[1] * sh + a.dy / l * r};
                }
                curUntil = t + Math.max(150, Math.min(3000, a.ms));
                b.status = "IA : joystick";
                break;
            case "maintenir":
                float[] p = {a.x * sw, a.y * sh};
                b.holdStart = p; b.joyWant = p;
                curUntil = t + Math.max(150, Math.min(3000, a.ms));
                b.status = "IA : je maintiens";
                break;
            default:
                curUntil = t + Math.max(100, Math.min(3000, a.ms));
        }
    }

    // ------------------------------------------------------------------ réseau

    private void send(long t, boolean analyze, String why) {
        int[] f = CaptureService.frame;
        if (f == null) return;
        final int fw = CaptureService.fw, fh = CaptureService.fh;
        final String key = Cfg.aiKey(b), model = Cfg.aiModel(b);
        final String prompt = analyze ? analyzePrompt(fw, fh) : helpPrompt(why);
        busy = true; lastCall = t;
        if (nh == null) { th = new HandlerThread("testbot-ia"); th.start(); nh = new Handler(th.getLooper()); }
        final int[] ff = f;
        nh.post(() -> {
            String err = null; JSONObject res = null;
            try {
                String img = jpeg(ff, fw, fh);
                String text = call(key, model, img, prompt);
                res = json(text);
                if (res == null) err = "réponse illisible";
            } catch (Exception e) {
                err = e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName();
            }
            final String ferr = err; final JSONObject fres = res;
            b.post(() -> {
                busy = false;
                if (ferr != null) {
                    errors++;
                    if (errors <= 3 || errors % 10 == 0) b.event("IA : " + ferr);
                    note = "erreur";
                    return;
                }
                apply(fres, ff, fw, fh, analyze);
            });
        });
    }

    private static String jpeg(int[] f, int w, int h) {
        Bitmap bm = Bitmap.createBitmap(f, w, h, Bitmap.Config.ARGB_8888);
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        bm.compress(Bitmap.CompressFormat.JPEG, 72, o);
        bm.recycle();
        return Base64.encodeToString(o.toByteArray(), Base64.NO_WRAP);
    }

    private String call(String key, String model, String img, String prompt) throws Exception {
        JSONObject body = new JSONObject();
        body.put("model", model);
        body.put("max_tokens", 700);
        body.put("system", "Tu es le cerveau d'un bot qui teste des jeux mobiles en jouant à la place du développeur. "
                + "Tu regardes une capture de l'écran du téléphone. Tu réponds UNIQUEMENT par un objet JSON valide, sans texte autour. "
                + "Les positions sont des fractions de l'image : x de 0 (gauche) à 1 (droite), y de 0 (haut) à 1 (bas). "
                + "Ne touche jamais un bouton d'achat, de boutique, de publicité, de paramètres, de partage ou pour quitter.");
        JSONArray content = new JSONArray();
        JSONObject im = new JSONObject();
        im.put("type", "image");
        JSONObject src = new JSONObject();
        src.put("type", "base64"); src.put("media_type", "image/jpeg"); src.put("data", img);
        im.put("source", src);
        content.put(im);
        JSONObject tx = new JSONObject();
        tx.put("type", "text"); tx.put("text", prompt);
        content.put(tx);
        JSONObject msg = new JSONObject();
        msg.put("role", "user"); msg.put("content", content);
        body.put("messages", new JSONArray().put(msg));

        HttpURLConnection c = (HttpURLConnection) new URL(API).openConnection();
        c.setRequestMethod("POST");
        c.setConnectTimeout(15000);
        c.setReadTimeout(30000);
        c.setDoOutput(true);
        c.setRequestProperty("content-type", "application/json");
        c.setRequestProperty("x-api-key", key);
        c.setRequestProperty("anthropic-version", "2023-06-01");
        try (OutputStream os = c.getOutputStream()) { os.write(body.toString().getBytes(StandardCharsets.UTF_8)); }
        int code = c.getResponseCode();
        String resp = read(code >= 400 ? c.getErrorStream() : c.getInputStream());
        c.disconnect();
        if (code == 401) throw new Exception("clé API refusée (401)");
        if (code == 429) throw new Exception("trop de demandes ou crédit épuisé (429)");
        if (code >= 400) {
            String m = "erreur " + code;
            try { m += " : " + new JSONObject(resp).getJSONObject("error").getString("message"); } catch (Exception ignored) {}
            throw new Exception(m);
        }
        JSONObject r = new JSONObject(resp);
        calls++;
        JSONObject u = r.optJSONObject("usage");
        if (u != null) { tokIn += u.optInt("input_tokens"); tokOut += u.optInt("output_tokens"); }
        JSONArray parts = r.getJSONArray("content");
        StringBuilder s = new StringBuilder();
        for (int i = 0; i < parts.length(); i++) {
            JSONObject p = parts.getJSONObject(i);
            if ("text".equals(p.optString("type"))) s.append(p.optString("text"));
        }
        return s.toString();
    }

    private static String read(InputStream in) throws Exception {
        if (in == null) return "";
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        int n;
        while ((n = in.read(buf)) > 0) o.write(buf, 0, n);
        in.close();
        return o.toString("UTF-8");
    }

    private static JSONObject json(String s) {
        if (s == null) return null;
        int a = s.indexOf('{'), z = s.lastIndexOf('}');
        if (a < 0 || z <= a) return null;
        try { return new JSONObject(s.substring(a, z + 1)); } catch (Exception e) { return null; }
    }

    /** Test de la clé depuis l'écran d'accueil (texte seul, pas d'image). */
    static void testKey(Context ctx, String key, String model, java.util.function.Consumer<String> done) {
        new Thread(() -> {
            String r;
            try {
                JSONObject body = new JSONObject();
                body.put("model", model); body.put("max_tokens", 10);
                body.put("messages", new JSONArray().put(new JSONObject().put("role", "user").put("content", "Réponds juste OK")));
                HttpURLConnection c = (HttpURLConnection) new URL(API).openConnection();
                c.setRequestMethod("POST"); c.setConnectTimeout(15000); c.setReadTimeout(20000); c.setDoOutput(true);
                c.setRequestProperty("content-type", "application/json");
                c.setRequestProperty("x-api-key", key);
                c.setRequestProperty("anthropic-version", "2023-06-01");
                try (OutputStream os = c.getOutputStream()) { os.write(body.toString().getBytes(StandardCharsets.UTF_8)); }
                int code = c.getResponseCode();
                String resp = read(code >= 400 ? c.getErrorStream() : c.getInputStream());
                if (code == 200) r = "Clé OK, l'IA répond";
                else {
                    String m = "";
                    try { m = new JSONObject(resp).getJSONObject("error").getString("message"); } catch (Exception ignored) {}
                    r = "Erreur " + code + (m.isEmpty() ? "" : " : " + m);
                }
            } catch (Exception e) { r = "Pas de connexion à l'IA : " + e.getClass().getSimpleName(); }
            done.accept(r);
        }).start();
    }

    // ------------------------------------------------------------------ prompts

    private String analyzePrompt(int w, int h) {
        return "Capture " + w + "x" + h + ". Découvre ce jeu comme un joueur qui l'ouvre pour la première fois. Réponds avec ce JSON :\n"
                + "{\"ecran\":\"jeu|menu|chargement|pub|autre\","
                + "\"genre\":\"rpg|foot_voiture|autre\","
                + "\"description\":\"une phrase\","
                + "\"objectif\":\"ce que le joueur doit faire pour gagner\","
                + "\"commandes\":[{\"nom\":\"joystick|gauche|droite|saut|boost|attaque|sort|interagir|autre\",\"x\":0.0,\"y\":0.0}],"
                + "\"a_eviter\":[{\"x\":0.0,\"y\":0.0}],"
                + "\"balle\":{\"x\":0.0,\"y\":0.0} ou null,"
                + "\"ma_voiture\":{\"x\":0.0,\"y\":0.0} ou null (point au milieu de la carrosserie colorée),"
                + "\"attaque_vers\":\"gauche|droite\" ou null (côté de la cage adverse),"
                + "\"ennemi\":{\"x\":0.0,\"y\":0.0} ou null,"
                + "\"butin\":{\"x\":0.0,\"y\":0.0} ou null,"
                + "\"minicarte\":{\"x0\":0.0,\"y0\":0.0,\"x1\":0.0,\"y1\":0.0} ou null (cadre exact de la mini-carte),"
                + "\"toucher_pour_jouer\":{\"x\":0.0,\"y\":0.0} ou null (si c'est un menu : le bouton pour lancer une partie),"
                + "\"bug\":\"bug visuel vu, ou null\"}";
    }

    private String helpPrompt(String why) {
        Cfg c = b.cfg;
        StringBuilder s = new StringBuilder();
        s.append("Jeu : ").append(c.aiDesc.isEmpty() ? "inconnu" : c.aiDesc).append(". Objectif : ").append(c.aiGoal.isEmpty() ? "inconnu" : c.aiGoal).append(".\n");
        s.append("Commandes connues :");
        if (c.joy != null) s.append(String.format(Locale.US, " joystick(%.2f,%.2f)", c.joy[0], c.joy[1]));
        if (c.jump != null) s.append(String.format(Locale.US, " saut(%.2f,%.2f)", c.jump[0], c.jump[1]));
        if (c.boost != null) s.append(String.format(Locale.US, " boost(%.2f,%.2f)", c.boost[0], c.boost[1]));
        for (float[] sp : c.spells) s.append(String.format(Locale.US, " sort(%.2f,%.2f)", sp[0], sp[1]));
        s.append("\nSituation : ").append(why).append('\n');
        s.append("Réponds avec ce JSON :\n{\"ecran\":\"jeu|menu|chargement|pub|fin_de_partie|autre\","
                + "\"note\":\"ce que tu vois et fais, 8 mots max\","
                + "\"actions\":[{\"type\":\"toucher\",\"x\":0.0,\"y\":0.0} | {\"type\":\"joystick\",\"dx\":-1..1,\"dy\":-1..1,\"ms\":800}"
                + " | {\"type\":\"maintenir\",\"x\":0.0,\"y\":0.0,\"ms\":800} | {\"type\":\"attendre\",\"ms\":500}] (5 actions max),"
                + "\"bug\":\"bug visuel vu (texte qui déborde, élément mal placé, objet figé, écran incohérent), ou null\"}");
        return s.toString();
    }

    // ------------------------------------------------------------------ appliquer la réponse

    private static float[] pt(JSONObject o) {
        if (o == null || !o.has("x") || !o.has("y")) return null;
        float x = (float) o.optDouble("x", -1), y = (float) o.optDouble("y", -1);
        if (x < 0 || y < 0 || x > 1 || y > 1) return null;
        return new float[]{x, y};
    }

    private void apply(JSONObject r, int[] f, int fw, int fh, boolean analyze) {
        Cfg c = b.cfg;
        String bug = r.optString("bug", "");
        if (!bug.isEmpty() && !"null".equals(bug)) b.event("Bug vu par l'IA : " + bug);
        String ecran = r.optString("ecran", "jeu");

        if (analyze) {
            String g = r.optString("genre", "autre");
            c.genre = g.equals("rpg") || g.equals("foot_voiture") ? g : "autre";
            c.aiDesc = r.optString("description", "");
            c.aiGoal = r.optString("objectif", "");
            JSONArray cmds = r.optJSONArray("commandes");
            if (cmds != null) for (int i = 0; i < cmds.length(); i++) {
                JSONObject o = cmds.optJSONObject(i);
                float[] p = pt(o);
                if (p == null) continue;
                String n = o.optString("nom", "");
                switch (n) {
                    case "joystick": c.joy = p; c.move = "joystick"; break;
                    case "gauche": c.left = p; break;
                    case "droite": c.right = p; break;
                    case "saut": c.jump = p; break;
                    case "boost": c.boost = p; break;
                    case "attaque": case "sort": {
                        boolean dup = false;
                        for (float[] s : c.spells) if (Math.hypot(s[0] - p[0], s[1] - p[1]) < 0.04) dup = true;
                        if (!dup) c.spells.add(new float[]{p[0], p[1], Vision.luma(f, fw, fh, p[0] * fw, p[1] * fh, 4)});
                        break;
                    }
                    default: break;
                }
            }
            JSONArray av = r.optJSONArray("a_eviter");
            if (av != null) for (int i = 0; i < av.length(); i++) { float[] p = pt(av.optJSONObject(i)); if (p != null) c.avoid.add(p); }
            float[] p;
            if ((p = pt(r.optJSONObject("balle"))) != null) c.ball = Vision.sample(f, fw, fh, p[0] * fw, p[1] * fh);
            if ((p = pt(r.optJSONObject("ma_voiture"))) != null) c.car = Vision.sample(f, fw, fh, p[0] * fw, p[1] * fh);
            if ((p = pt(r.optJSONObject("ennemi"))) != null) { int[] col = Vision.sample(f, fw, fh, p[0] * fw, p[1] * fh); if (col != null) c.enemy.add(col); }
            if ((p = pt(r.optJSONObject("butin"))) != null) { int[] col = Vision.sample(f, fw, fh, p[0] * fw, p[1] * fh); if (col != null) c.chest.add(col); }
            JSONObject mm = r.optJSONObject("minicarte");
            if (mm != null) {
                float a0 = (float) mm.optDouble("x0", -1), b0 = (float) mm.optDouble("y0", -1), a1 = (float) mm.optDouble("x1", -1), b1 = (float) mm.optDouble("y1", -1);
                if (a0 >= 0 && b0 >= 0 && a1 <= 1 && b1 <= 1 && a1 - a0 > 0.04 && b1 - b0 > 0.04) { c.minimap = new float[]{a0, b0, a1, b1}; b.auto.mini.reset(); }
            }
            String att = r.optString("attaque_vers", "");
            if (att.equals("gauche")) c.attack = -1; else if (att.equals("droite")) c.attack = 1;
            if (c.joy != null || !c.spells.isEmpty()) c.calibrated = true; // l'IA a déjà trouvé les commandes : pas de calibrage à l'aveugle
            b.saveCfg();
            note = c.aiDesc;
            b.event("IA : " + (c.aiDesc.isEmpty() ? "jeu analysé" : c.aiDesc) + " → cerveau " + BotService.brainName(b.effectiveBrain()));
            if (!ecran.equals("jeu")) {
                float[] go = pt(r.optJSONObject("toucher_pour_jouer"));
                if (go != null) b.tap(go[0] * b.sw, go[1] * b.sh);
                analyzeAsked = false; // on ré-analysera une fois en jeu si des infos manquent
            }
            return;
        }

        note = r.optString("note", "");
        JSONArray acts = r.optJSONArray("actions");
        if (acts == null) return;
        for (int i = 0; i < Math.min(5, acts.length()); i++) {
            JSONObject o = acts.optJSONObject(i);
            if (o == null) continue;
            Act a = new Act();
            a.type = o.optString("type", "attendre");
            a.x = (float) o.optDouble("x", 0.5); a.y = (float) o.optDouble("y", 0.5);
            a.dx = (float) o.optDouble("dx", 0); a.dy = (float) o.optDouble("dy", 0);
            a.ms = o.optLong("ms", 600);
            if (a.type.equals("toucher") || a.type.equals("maintenir")) {
                if (a.x < 0 || a.x > 1 || a.y < 0 || a.y > 1) continue;
                boolean bad = false;
                for (float[] p : c.avoid) if (Math.hypot(p[0] - a.x, p[1] - a.y) < 0.05) bad = true;
                if (bad) continue;
            }
            queue.add(a);
        }
        if (!ecran.equals("jeu") && !note.isEmpty()) b.status = "IA : " + note;
    }
}
