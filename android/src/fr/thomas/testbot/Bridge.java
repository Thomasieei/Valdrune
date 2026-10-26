package fr.thomas.testbot;

import org.json.JSONArray;
import org.json.JSONObject;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Passerelle : le jeu envoie lui-même ce qu'il y a à l'écran (UDP local, port 47231), 10 fois par seconde.
 * Plus besoin de capture d'écran : positions exactes en pixels, PV, sorts prêts, zones rouges, chemin du jeu.
 */
final class Bridge {
    static final int PORT = 47231;

    static final class State {
        long t;
        String game = "", mode = "";
        boolean inGame, dead;
        int sw, sh;
        float px, py, wx, wz;
        int hp, hpMax;
        final List<float[]> enemies = new ArrayList<>();   // x, y, visible, distance monde, pv, pvMax, boss
        final List<float[]> chests = new ArrayList<>();    // x, y, visible, distance
        final List<float[]> dangers = new ArrayList<>();   // x, y, rayon écran, rayon monde, distance monde, temps restant
        final List<String> spellKeys = new ArrayList<>();
        final List<float[]> spells = new ArrayList<>();    // x, y, prêt
        float[] joy;                                       // x, y, rayon
        float[] nav;                                       // x, y, distance
        String navWhat = "";
        float[] action;                                    // x, y
        String actionText = "";
        final List<String> errors = new ArrayList<>();
    }

    private final BotService b;
    private Thread th;
    private DatagramSocket sock;
    private volatile boolean running;
    volatile State last;
    volatile int packets, badPackets;

    Bridge(BotService b) { this.b = b; }

    /** Données de moins d'une demi-seconde : le jeu parle au bot. */
    boolean live() { State s = last; return s != null && BotService.now() - s.t < 600; }

    void start() {
        if (running) return;
        running = true;
        th = new Thread(() -> {
            try {
                sock = new DatagramSocket(PORT, InetAddress.getByName("127.0.0.1"));
                byte[] buf = new byte[65535];
                while (running) {
                    DatagramPacket p = new DatagramPacket(buf, buf.length);
                    sock.receive(p);
                    try {
                        State s = parse(new String(p.getData(), 0, p.getLength(), StandardCharsets.UTF_8));
                        last = s; packets++;
                        if (!s.errors.isEmpty()) b.post(() -> { for (String e : s.errors) b.event("Erreur du jeu : " + e); });
                    } catch (Exception e) { badPackets++; }
                }
            } catch (Exception e) {
                if (running) b.post(() -> b.event("Passerelle : port " + PORT + " indisponible (" + e.getClass().getSimpleName() + ")"));
            } finally { running = false; }
        }, "testbot-pont");
        th.setDaemon(true);
        th.start();
    }

    void stop() {
        running = false;
        try { if (sock != null) sock.close(); } catch (Exception ignored) {}
    }

    private static State parse(String txt) throws Exception {
        JSONObject o = new JSONObject(txt);
        State s = new State();
        s.t = BotService.now();
        s.game = o.optString("jeu", "");
        s.mode = o.optString("mode", "");
        s.inGame = o.optBoolean("enJeu", false);
        JSONObject ec = o.optJSONObject("ecran");
        if (ec != null) { s.sw = ec.optInt("w"); s.sh = ec.optInt("h"); }
        JSONArray er = o.optJSONArray("erreurs");
        if (er != null) for (int i = 0; i < er.length(); i++) s.errors.add(er.optString(i));
        JSONObject j = o.optJSONObject("joueur");
        if (j != null) {
            s.px = (float) j.optDouble("x"); s.py = (float) j.optDouble("y");
            s.wx = (float) j.optDouble("wx"); s.wz = (float) j.optDouble("wz");
            s.hp = j.optInt("pv"); s.hpMax = Math.max(1, j.optInt("pvMax", 1)); s.dead = j.optInt("mort") == 1;
        }
        JSONArray a = o.optJSONArray("ennemis");
        if (a != null) for (int i = 0; i < a.length(); i++) {
            JSONObject e = a.getJSONObject(i);
            s.enemies.add(new float[]{(float) e.optDouble("x"), (float) e.optDouble("y"), e.optInt("v"), (float) e.optDouble("d"), e.optInt("pv"), Math.max(1, e.optInt("pvMax", 1)), e.optInt("boss")});
        }
        a = o.optJSONArray("coffres");
        if (a != null) for (int i = 0; i < a.length(); i++) {
            JSONObject e = a.getJSONObject(i);
            s.chests.add(new float[]{(float) e.optDouble("x"), (float) e.optDouble("y"), e.optInt("v"), (float) e.optDouble("d")});
        }
        a = o.optJSONArray("dangers");
        if (a != null) for (int i = 0; i < a.length(); i++) {
            JSONObject e = a.getJSONObject(i);
            s.dangers.add(new float[]{(float) e.optDouble("x"), (float) e.optDouble("y"), (float) e.optDouble("r"), (float) e.optDouble("wr"), (float) e.optDouble("d"), (float) e.optDouble("t")});
        }
        a = o.optJSONArray("sorts");
        if (a != null) for (int i = 0; i < a.length(); i++) {
            JSONObject e = a.getJSONObject(i);
            s.spellKeys.add(e.optString("k"));
            s.spells.add(new float[]{(float) e.optDouble("x"), (float) e.optDouble("y"), e.optInt("pret")});
        }
        JSONObject jo = o.optJSONObject("joy");
        if (jo != null) s.joy = new float[]{(float) jo.optDouble("x"), (float) jo.optDouble("y"), (float) jo.optDouble("r", 50)};
        JSONObject nv = o.optJSONObject("nav");
        if (nv != null) { s.nav = new float[]{(float) nv.optDouble("x"), (float) nv.optDouble("y"), (float) nv.optDouble("d")}; s.navWhat = nv.optString("quoi"); }
        JSONObject ac = o.optJSONObject("action");
        if (ac != null) { s.action = new float[]{(float) ac.optDouble("x"), (float) ac.optDouble("y")}; s.actionText = ac.optString("texte"); }
        return s;
    }
}
