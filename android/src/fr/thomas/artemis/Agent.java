package fr.thomas.artemis;

import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.view.accessibility.AccessibilityNodeInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;

/**
 * La boucle de l'agent, version mobile du profil « Flash » d'Artemis :
 * observer l'écran → demander UNE action à Claude → l'exécuter → recommencer.
 * Tout tourne sur le téléphone : pas de PC, pas d'ADB.
 */
final class Agent implements Runnable {
    interface Ui {
        void status(String text);
        /** Pose une question à l'utilisateur ; confirm = boutons Oui/Non. */
        void ask(String question, boolean confirm);
        void finished(boolean ok, String summary);
        void stealth(boolean hidden);
    }

    private static final String API = "https://api.anthropic.com/v1/messages";
    private static final Pattern RISKY = Pattern.compile(
            "(envoyer|send|payer|paiement|acheter|achat|commander|confirmer la commande|supprimer|effacer tout|delete|publier|poster|appeler|virement|transf[ée]rer|r[ée]server|s'abonner|souscrire)",
            Pattern.CASE_INSENSITIVE);

    private final AgentService svc;
    private final Ui ui;
    final String goal;
    private volatile boolean stop;
    private final LinkedBlockingQueue<String> answers = new LinkedBlockingQueue<>();

    private final List<String> history = new ArrayList<>();
    private final List<String> notes = new ArrayList<>();
    int step, tokIn, tokOut;
    private String lastSig = "", lastAction = "";
    private int sameCount;
    private boolean wantShot = true;
    private String approved = "";
    private int okUntilStep;

    Agent(AgentService svc, Ui ui, String goal) { this.svc = svc; this.ui = ui; this.goal = goal; }

    void stop() { stop = true; answers.offer("__stop__"); }
    void answer(String a) { answers.offer(a == null ? "" : a); }
    boolean stopped() { return stop; }

    @Override public void run() {
        String key = Cfg.key(svc), model = Cfg.model(svc);
        int max = Cfg.maxSteps(svc), vision = Cfg.vision(svc);
        boolean ok = false; String summary = "Arrêté.";
        try {
            if (key.length() < 20) throw new Exception("Aucune clé API Claude : ouvre Artémis et colle ta clé dans Réglages.");
            sleep(500);
            while (!stop) {
                if (step >= max) { summary = "Limite de " + max + " étapes atteinte sans finir. Tâche trop longue ou bloquée."; break; }
                step++;
                ui.status("Étape " + step + " · je regarde l'écran…");

                ui.stealth(true);
                sleep(120);
                Screen sc = Screen.read(svc);
                boolean changed = !sc.sig.equals(lastSig);
                boolean shotNow = vision == 1 || (vision == 0 && (wantShot || sc.els.size() < 8 || !changed));
                String img = shotNow ? Screen.shot(svc) : null;
                ui.stealth(false);

                StringBuilder p = new StringBuilder();
                p.append("OBJECTIF : ").append(goal).append("\n\n");
                if (!notes.isEmpty()) p.append("TES NOTES :\n- ").append(String.join("\n- ", notes)).append("\n\n");
                p.append("HISTORIQUE (").append(step - 1).append(" étapes) :\n");
                if (history.isEmpty()) p.append("(début)\n");
                int from = Math.max(0, history.size() - 14);
                if (from > 0) p.append("(").append(from).append(" étapes plus anciennes omises)\n");
                for (int i = from; i < history.size(); i++) p.append(history.get(i)).append('\n');
                if (step > 1 && !changed) p.append("⚠ L'écran n'a PAS changé après ta dernière action.\n");
                p.append("\nÉCRAN ACTUEL — appli : ").append(sc.pkg.isEmpty() ? "?" : sc.pkg)
                        .append(" (positions @x,y de 0 à 1000)\n").append(sc.text);
                if (img == null) p.append("\n(pas de capture cette fois ; action regarder pour en demander une)");
                p.append("\nÉtape ").append(step).append('/').append(max).append(". Donne la prochaine action.");

                ui.status("Étape " + step + " · je réfléchis…");
                JSONObject act = call(key, model, p.toString(), img);
                if (stop) break;
                lastSig = sc.sig;
                wantShot = false;

                String a = act.optString("action");
                String think = act.optString("pensee").trim();
                String note = act.optString("note").trim();
                if (!note.isEmpty()) { notes.add(note); if (notes.size() > 10) notes.remove(0); }
                ui.status(think.isEmpty() ? "Étape " + step : think);

                String desc = a + describe(act, sc);
                sameCount = desc.equals(lastAction) && !changed ? sameCount + 1 : 0;
                lastAction = desc;

                if ("terminer".equals(a)) { ok = true; summary = act.optString("texte", "Fait."); break; }
                if ("echec".equals(a)) { summary = "Je n'y arrive pas : " + act.optString("texte", "?"); break; }

                // Garde-fou côté appli : une action engageante demande toujours ton accord.
                if (Cfg.guard(svc) && ("toucher".equals(a) || "ecrire".equals(a)) && act.optBoolean("valider", "toucher".equals(a))) {
                    Screen.El el = sc.get(act.optInt("index", -1));
                    String lbl = el != null ? el.label : "";
                    if (!lbl.isEmpty() && RISKY.matcher(lbl).find() && !approved.equals(lbl) && step > okUntilStep) {
                        String r = askUser("Je m'apprête à toucher « " + lbl + " ». Je continue ?", true);
                        if (r == null) break;
                        boolean yes = r.equalsIgnoreCase("oui");
                        history.add(fmt(think, "voulait toucher « " + lbl + " »",
                                yes ? "l'utilisateur a dit OUI, refais l'action" : "l'utilisateur a dit NON, ne le fais pas"));
                        if (yes) approved = lbl;
                        continue;
                    }
                }

                String res = exec(a, act, sc);
                if (res == null) break;
                if (sameCount >= 2) res += " — tu répètes la même action sans effet, change d'approche";
                history.add(fmt(think, a + describe(act, sc), res));
            }
        } catch (Exception e) {
            summary = "Erreur : " + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName());
        }
        if (stop && !ok && summary.equals("Arrêté.")) summary = "Arrêté à l'étape " + step + ".";
        Cfg.addHistory(svc, goal, summary, ok, step, tokIn, tokOut);
        ui.stealth(false);
        ui.finished(ok, summary);
    }

    // ------------------------------------------------------------------ actions

    /** Exécute l'action ; renvoie le résultat pour l'historique, ou null si l'utilisateur a arrêté. */
    private String exec(String a, JSONObject act, Screen sc) throws InterruptedException {
        Screen.El el = sc.get(act.optInt("index", -1));
        String txt = act.optString("texte");
        String r;
        ui.stealth(true);
        try {
            switch (a) {
                case "toucher":
                    if (el == null) return "index invalide";
                    r = GestureController.tap(svc, el.cx(), el.cy(), 1500) ? "ok" : "geste refusé";
                    break;
                case "appui_long":
                    if (el == null) return "index invalide";
                    r = GestureController.longPress(svc, el.cx(), el.cy(), 800, 1500) ? "ok" : "geste refusé";
                    break;
                case "toucher_xy": {
                    float x = clamp(act.optInt("x", -1)) * sc.w / 1000f, y = clamp(act.optInt("y", -1)) * sc.h / 1000f;
                    r = GestureController.tap(svc, x, y, 1500) ? "ok" : "geste refusé";
                    break;
                }
                case "ecrire":
                    r = type(el, txt, act.optBoolean("valider"));
                    break;
                case "defiler":
                    r = scroll(act.optString("direction", "bas"), el, sc);
                    break;
                case "retour":
                    r = GestureController.performGlobalAction(svc, "back") ? "ok" : "échec";
                    break;
                case "accueil":
                    r = GestureController.performGlobalAction(svc, "home") ? "ok" : "échec";
                    break;
                case "notifications":
                    r = GestureController.performGlobalAction(svc, "notifications") ? "volet ouvert" : "échec";
                    break;
                case "ouvrir_appli":
                    r = openApp(txt);
                    sleep(1500);
                    break;
                case "attendre":
                    sleep(Math.max(500, Math.min(8000, act.optInt("ms", 2000))));
                    r = "attendu";
                    break;
                case "regarder":
                    wantShot = true;
                    r = "capture au prochain tour";
                    break;
                case "demander":
                case "confirmer": {
                    ui.stealth(false);
                    String ans = askUser(txt.isEmpty() ? "?" : txt, "confirmer".equals(a));
                    if (ans == null) return null;
                    if ("confirmer".equals(a) && ans.equalsIgnoreCase("oui")) okUntilStep = step + 3;
                    return "réponse de l'utilisateur : " + ans;
                }
                default:
                    r = "action inconnue";
            }
        } finally { ui.stealth(false); }
        sleep(a.equals("ecrire") ? 600 : 900);
        return r;
    }

    private String type(Screen.El el, String txt, boolean submit) throws InterruptedException {
        if (el != null) { GestureController.tap(svc, el.cx(), el.cy(), 1500); sleep(450); }
        boolean ok = GestureController.setText(svc, txt);
        if (!ok) {
            // Repli : presse-papiers + coller dans le champ qui a le curseur.
            GestureController.setClipboard(svc, txt);
            sleep(150);
            AccessibilityNodeInfo n = HierarchyDumper.findInputNode(svc);
            ok = n != null && n.performAction(AccessibilityNodeInfo.ACTION_PASTE);
            HierarchyDumper.safeRecycle(n);
            if (!ok) return "aucun champ texte trouvé (touche d'abord le champ)";
        }
        if (submit) {
            sleep(250);
            AccessibilityNodeInfo n = HierarchyDumper.findInputNode(svc);
            boolean sent = n != null && n.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.getId());
            HierarchyDumper.safeRecycle(n);
            return sent ? "texte écrit et validé" : "texte écrit, validation impossible (touche le bouton)";
        }
        return "texte écrit";
    }

    private String scroll(String dir, Screen.El el, Screen sc) {
        float cx = el != null ? el.cx() : sc.w / 2f, cy = el != null ? el.cy() : sc.h / 2f;
        float hh = (el != null ? (el.b - el.t) : sc.h) * 0.3f, hw = (el != null ? (el.r - el.l) : sc.w) * 0.3f;
        hh = Math.max(hh, 150); hw = Math.max(hw, 150);
        boolean ok;
        switch (dir) {
            case "haut": ok = GestureController.swipe(svc, cx, cy - hh, cx, cy + hh, 350, 1500); break;
            case "gauche": ok = GestureController.swipe(svc, cx - hw, cy, cx + hw, cy, 300, 1500); break;
            case "droite": ok = GestureController.swipe(svc, cx + hw, cy, cx - hw, cy, 300, 1500); break;
            default: ok = GestureController.swipe(svc, cx, cy + hh, cx, cy - hh, 350, 1500);
        }
        return ok ? "défilé vers " + dir : "geste refusé";
    }

    private String openApp(String name) {
        PackageManager pm = svc.getPackageManager();
        Intent main = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> apps = pm.queryIntentActivities(main, 0);
        String want = fold(name);
        ResolveInfo best = null; int bestScore = 0;
        List<String> labels = new ArrayList<>();
        for (ResolveInfo ri : apps) {
            String lab = String.valueOf(ri.loadLabel(pm));
            String f = fold(lab);
            labels.add(lab);
            int s = f.equals(want) ? 3 : f.startsWith(want) ? 2 : (f.contains(want) || (want.length() > 3 && want.contains(f))) ? 1 : 0;
            if (s > bestScore) { bestScore = s; best = ri; }
        }
        if (best == null || want.isEmpty()) {
            StringBuilder sb = new StringBuilder("appli « " + name + " » introuvable. Applis installées : ");
            java.util.Collections.sort(labels);
            sb.append(String.join(", ", labels.subList(0, Math.min(80, labels.size()))));
            return sb.toString();
        }
        Intent i = pm.getLaunchIntentForPackage(best.activityInfo.packageName);
        if (i == null) return "impossible de lancer " + best.loadLabel(pm);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        svc.startActivity(i);
        return "ouverture de " + best.loadLabel(pm);
    }

    private String askUser(String q, boolean confirm) throws InterruptedException {
        answers.clear();
        ui.ask(q, confirm);
        while (!stop) {
            String a = answers.poll(500, TimeUnit.MILLISECONDS);
            if (a != null) return "__stop__".equals(a) ? null : a;
        }
        return null;
    }

    // ------------------------------------------------------------------ Claude

    private JSONObject call(String key, String model, String prompt, String img) throws Exception {
        JSONObject body = new JSONObject();
        body.put("model", model);
        body.put("max_tokens", 600);
        body.put("system", SYSTEM);
        body.put("tools", new JSONArray().put(TOOL));
        body.put("tool_choice", new JSONObject().put("type", "tool").put("name", "agir"));
        JSONArray content = new JSONArray();
        if (img != null) {
            content.put(new JSONObject().put("type", "image").put("source", new JSONObject()
                    .put("type", "base64").put("media_type", "image/jpeg").put("data", img)));
        }
        content.put(new JSONObject().put("type", "text").put("text", prompt));
        body.put("messages", new JSONArray().put(new JSONObject().put("role", "user").put("content", content)));

        Exception last = null;
        for (int attempt = 0; attempt < 3 && !stop; attempt++) {
            try {
                HttpURLConnection c = (HttpURLConnection) new URL(API).openConnection();
                c.setRequestMethod("POST");
                c.setConnectTimeout(15000);
                c.setReadTimeout(60000);
                c.setDoOutput(true);
                c.setRequestProperty("content-type", "application/json");
                c.setRequestProperty("x-api-key", key);
                c.setRequestProperty("anthropic-version", "2023-06-01");
                try (OutputStream os = c.getOutputStream()) { os.write(body.toString().getBytes(StandardCharsets.UTF_8)); }
                int code = c.getResponseCode();
                String resp = read(code >= 400 ? c.getErrorStream() : c.getInputStream());
                c.disconnect();
                if (code == 401) throw new Exception("clé API refusée (401) — vérifie-la dans Réglages");
                if (code == 429 || code == 529 || code >= 500) { last = new Exception("serveur occupé (" + code + ")"); sleep(2500L * (attempt + 1)); continue; }
                if (code >= 400) {
                    String m = "erreur " + code;
                    try { m += " : " + new JSONObject(resp).getJSONObject("error").getString("message"); } catch (Exception ignored) {}
                    throw new Exception(m);
                }
                JSONObject r = new JSONObject(resp);
                JSONObject u = r.optJSONObject("usage");
                if (u != null) { tokIn += u.optInt("input_tokens"); tokOut += u.optInt("output_tokens"); }
                JSONArray parts = r.getJSONArray("content");
                for (int i = 0; i < parts.length(); i++) {
                    JSONObject pt = parts.getJSONObject(i);
                    if ("tool_use".equals(pt.optString("type"))) return pt.getJSONObject("input");
                }
                throw new Exception("réponse sans action");
            } catch (java.io.IOException io) {
                last = new Exception("réseau : " + io.getMessage());
                sleep(2000);
            }
        }
        throw last != null ? last : new Exception("arrêté");
    }

    private static final String SYSTEM =
            "Tu es Artémis, un agent qui utilise le téléphone Android de l'utilisateur à sa place, comme un humain le ferait. "
            + "À chaque étape tu reçois l'objectif, l'historique de tes actions, tes notes, la liste numérotée des éléments de l'écran "
            + "(et parfois une capture). Tu appelles l'outil agir avec UNE SEULE action.\n"
            + "Règles :\n"
            + "- Touche par index (action toucher) dès que l'élément est dans la liste. toucher_xy seulement pour ce qui n'est visible que sur la capture (x,y de 0 à 1000).\n"
            + "- Pour lancer une appli, utilise ouvrir_appli avec son nom (ex. « Météo », « WhatsApp ») plutôt que chercher l'icône.\n"
            + "- Pour écrire : action ecrire avec l'index du champ (il est touché puis rempli) ; valider=true pour appuyer sur Entrée / Rechercher.\n"
            + "- Pour voir plus de contenu : defiler (direction bas pour descendre dans une liste), avec l'index de la liste si besoin.\n"
            + "- Ferme les pop-ups, bannières cookies et pubs qui gênent. Refuse les permissions inutiles.\n"
            + "- Si l'écran n'a pas changé après ton action, change d'approche (autre élément, regarder, défiler, retour). Jamais 3 fois la même action.\n"
            + "- Avant toute action engageante ou irréversible (envoyer un message ou un mail, payer, acheter, commander, réserver, supprimer, publier, appeler) : "
            + "action confirmer avec une question précise, sauf si l'historique montre que l'utilisateur a déjà dit OUI à cette action exacte.\n"
            + "- Si une information manque (quel contact, quel texte, quelle date…), action demander.\n"
            + "- Ne saisis jamais de mot de passe, code PIN ou code bancaire : action demander pour que l'utilisateur le fasse lui-même.\n"
            + "- Utilise note pour garder une info utile pour la suite (ex. un prix relevé, un résultat intermédiaire).\n"
            + "- Objectif atteint → terminer, avec dans texte un résumé court qui contient l'information demandée (ex. la météo lue à l'écran).\n"
            + "- Impossible après plusieurs essais → echec avec la raison.\n"
            + "- pensee : une phrase courte en français, affichée à l'utilisateur pendant que tu travailles.";

    private static final JSONObject TOOL = buildTool();

    private static JSONObject buildTool() {
        try {
            JSONObject props = new JSONObject();
            props.put("pensee", new JSONObject().put("type", "string").put("description", "Ce que tu fais et pourquoi, une phrase courte."));
            props.put("action", new JSONObject().put("type", "string").put("enum", new JSONArray()
                    .put("toucher").put("toucher_xy").put("appui_long").put("ecrire").put("defiler").put("retour").put("accueil")
                    .put("notifications").put("ouvrir_appli").put("attendre").put("regarder").put("demander").put("confirmer")
                    .put("terminer").put("echec")));
            props.put("index", new JSONObject().put("type", "integer").put("description", "Numéro de l'élément [n] (toucher, appui_long, ecrire, defiler)."));
            props.put("x", new JSONObject().put("type", "integer").put("description", "toucher_xy : 0 à 1000, gauche→droite."));
            props.put("y", new JSONObject().put("type", "integer").put("description", "toucher_xy : 0 à 1000, haut→bas."));
            props.put("texte", new JSONObject().put("type", "string").put("description",
                    "ecrire : le texte ; ouvrir_appli : nom de l'appli ; demander/confirmer : la question ; terminer/echec : résumé pour l'utilisateur."));
            props.put("valider", new JSONObject().put("type", "boolean").put("description", "ecrire : appuyer sur Entrée après."));
            props.put("direction", new JSONObject().put("type", "string").put("enum", new JSONArray().put("bas").put("haut").put("gauche").put("droite")));
            props.put("ms", new JSONObject().put("type", "integer").put("description", "attendre : durée en millisecondes."));
            props.put("note", new JSONObject().put("type", "string").put("description", "Optionnel : info à mémoriser pour la suite."));
            return new JSONObject().put("name", "agir").put("description", "Effectue une action sur le téléphone.")
                    .put("input_schema", new JSONObject().put("type", "object").put("properties", props)
                            .put("required", new JSONArray().put("pensee").put("action")));
        } catch (Exception e) { throw new RuntimeException(e); }
    }

    // ------------------------------------------------------------------ utilitaires

    private static String describe(JSONObject act, Screen sc) {
        StringBuilder s = new StringBuilder();
        if (act.has("index")) {
            Screen.El el = sc.get(act.optInt("index"));
            s.append(" [").append(act.optInt("index")).append(']');
            if (el != null && !el.label.isEmpty()) s.append(" « ").append(el.label.length() > 40 ? el.label.substring(0, 40) + "…" : el.label).append(" »");
        }
        if (act.has("x")) s.append(" @").append(act.optInt("x")).append(',').append(act.optInt("y"));
        if (act.has("direction")) s.append(' ').append(act.optString("direction"));
        String t = act.optString("texte");
        if (!t.isEmpty()) s.append(" \"").append(t.length() > 60 ? t.substring(0, 60) + "…" : t).append('"');
        return s.toString();
    }

    private String fmt(String think, String action, String res) {
        return step + ". " + action + " → " + res + (think.isEmpty() ? "" : "  (" + think + ")");
    }

    private static int clamp(int v) { return Math.max(0, Math.min(1000, v)); }

    private static String fold(String s) {
        String n = Normalizer.normalize(s == null ? "" : s, Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        return n.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
    }

    private void sleep(long ms) throws InterruptedException {
        long end = System.currentTimeMillis() + ms;
        while (!stop && System.currentTimeMillis() < end) Thread.sleep(Math.min(100, end - System.currentTimeMillis() + 1));
    }

    private static String read(InputStream in) throws Exception {
        if (in == null) return "";
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        byte[] b = new byte[8192]; int n;
        while ((n = in.read(b)) > 0) o.write(b, 0, n);
        in.close();
        return o.toString("UTF-8");
    }
}
