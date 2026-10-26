package fr.thomas.testbot;

import java.util.regex.Pattern;

/**
 * Cerveau « passerelle » : joue avec l'état exact envoyé par le jeu (aucune capture d'écran).
 * Priorités : esquiver les zones rouges > potion si PV bas > combattre le monstre proche
 * > suivre le chemin calculé par le jeu (monstre, coffre, sortie) > explorer.
 */
final class BridgeBrain {
    private static final Pattern RX_SAFE_ACTION = Pattern.compile("ouvrir|ramasser|récupérer|recuperer|prendre|coffre|butin|continuer|entrer", Pattern.CASE_INSENSITIVE);
    private static final Pattern RX_LEAVE = Pattern.compile("retourner|place|sortir", Pattern.CASE_INSENSITIVE);

    private final BotService b;
    private float kx = 1, ky = 1;
    private long lastAtk, lastSpell, lastPot, lastAction, stuckT, detourUntil, lastDodge, lastWander, lastEnemyEvent;
    private float stuckWx, stuckWz;
    private int detourSide = 1, spellIdx, lastEnemies = -1;
    private double wander = Math.random() * 6.283;
    private boolean lowWarned;

    BridgeBrain(BotService b) { this.b = b; }

    private float X(float x) { return x * kx; }
    private float Y(float y) { return y * ky; }

    void stop() { b.joyWant = null; b.holdStart = null; b.hold2 = null; }

    void tick(long t, Bridge.State s) {
        if (s.sw > 0 && s.sh > 0) { kx = b.sw / s.sw; ky = b.sh / s.sh; }
        if (!s.inGame) { stop(); b.status = "Passerelle : hors partie (" + s.mode + ")"; return; }
        float px = X(s.px), py = Y(s.py);
        b.px = px; b.py = py;
        if (s.joy != null) b.cfg.joy = new float[]{X(s.joy[0]) / b.sw, Y(s.joy[1]) / b.sh};
        if (s.dead) { stop(); b.status = "Mort : j'attends la réapparition"; return; }

        // Bilan des monstres pour le rapport (ex. « salle vidée »)
        if (lastEnemies > 0 && s.enemies.isEmpty() && t - lastEnemyEvent > 5000) { lastEnemyEvent = t; b.event("Plus aucun monstre (" + s.mode + ")"); }
        lastEnemies = s.enemies.size();

        // 1. Zones rouges : je sors avant tout
        float ax = 0, ay = 0; boolean danger = false;
        for (float[] d : s.dangers) {
            float dx = px - X(d[0]), dy = py - Y(d[1]);
            float l = (float) Math.hypot(dx, dy), r = Math.max(X(d[2]), 20) * 1.15f + BotService.dpS(b, 16);
            if (l < r) {
                danger = true;
                if (l < 1) { dx = (float) Math.cos(wander); dy = (float) Math.sin(wander); l = 1; }
                float w = (r - l) / r + 0.3f;
                ax += dx / l * w; ay += dy / l * w;
            }
        }
        if (danger) {
            if (t - lastDodge > 1500) { b.nDodges++; lastDodge = t; }
            b.status = "Esquive une zone rouge";
            move(s, ax, ay);
            castReady(t, s, true); // on peut lancer en courant
            return;
        }

        // 2. Potion si la vie est basse
        float hp = (float) s.hp / s.hpMax;
        if (hp < 0.35f) {
            if (!lowWarned) { lowWarned = true; b.event("PV bas (" + Math.round(hp * 100) + " %)"); }
            float[] pot = spell(s, "POT");
            if (pot != null && pot[2] == 1 && t - lastPot > 1500) { b.tap(X(pot[0]), Y(pot[1])); lastPot = t; }
        } else if (hp > 0.6f) lowWarned = false;

        // 3. Bouton d'action contextuel (ouvrir un coffre…) ; « Retourner sur la Place » seulement quand le donjon est fini
        if (s.action != null && t - lastAction > 1500) {
            boolean safe = RX_SAFE_ACTION.matcher(s.actionText).find() && !BotService.RX_BAD.matcher(s.actionText).find();
            boolean leave = RX_LEAVE.matcher(s.actionText).find() && s.enemies.isEmpty() && s.chests.isEmpty();
            if (safe || leave) {
                b.tap(X(s.action[0]), Y(s.action[1])); lastAction = t;
                b.status = "Touche « " + s.actionText + " »";
                if (leave) b.event("Donjon terminé : « " + s.actionText + " »");
                return;
            }
        }

        // 4. Combat
        float[] en = s.enemies.isEmpty() ? null : s.enemies.get(0); // déjà trié par distance
        if (en != null && en[3] < 7.5f) castReady(t, s, false);
        if (en != null && en[3] < 3.3f) {
            stop();
            b.status = "Combat" + (en[6] == 1 ? " contre le boss" : "") + " (" + Math.round(en[4] * 100 / en[5]) + " % PV)";
            float[] atk = spell(s, "ATK");
            if (atk != null && t - lastAtk > 350) { b.tap(X(atk[0]), Y(atk[1])); lastAtk = t; }
            stuckT = 0;
            return;
        }

        // 5. Suivre le chemin calculé par le jeu
        float dx, dy;
        if (s.nav != null) {
            dx = X(s.nav[0]) - px; dy = Y(s.nav[1]) - py;
            b.status = (s.navWhat.equals("ennemi") ? "Chasse un monstre" : s.navWhat.equals("coffre") ? "Va au coffre" : "Va vers la sortie") + " (" + Math.round(s.nav[2]) + " m)";
        } else {
            if (t - lastWander > 3000) { wander += (Math.random() - 0.5) * 2.4; lastWander = t; }
            dx = (float) Math.cos(wander); dy = (float) Math.sin(wander);
            b.status = "Explore";
        }
        // Coincé contre un mur (ma position dans le monde ne change plus) : je contourne un instant
        if (t < detourUntil) {
            double a = Math.atan2(dy, dx) + detourSide * 1.4;
            dx = (float) Math.cos(a); dy = (float) Math.sin(a);
            b.status = "Contourne un obstacle";
        } else if (stuckT == 0 || Math.hypot(s.wx - stuckWx, s.wz - stuckWz) > 0.4) {
            stuckT = t; stuckWx = s.wx; stuckWz = s.wz;
        } else if (t - stuckT > 1500) {
            b.nStuck++; detourSide = -detourSide; detourUntil = t + 900; stuckT = 0;
            wander += 2;
        }
        move(s, dx, dy);
    }

    private float[] spell(Bridge.State s, String k) {
        int i = s.spellKeys.indexOf(k);
        return i < 0 ? null : s.spells.get(i);
    }

    /** Lance un sort prêt (Q, W, E, R, D, F), à tour de rôle. */
    private void castReady(long t, Bridge.State s, boolean moving) {
        if (!b.cfg.autoSpells || t - lastSpell < Math.max(350, b.cfg.spellEvery)) return;
        int n = s.spellKeys.size();
        for (int k = 0; k < n; k++) {
            int i = (spellIdx + k) % n;
            String key = s.spellKeys.get(i);
            if (key.equals("ATK") || key.equals("POT")) continue;
            float[] sp = s.spells.get(i);
            if (sp[2] != 1) continue;
            b.tap(X(sp[0]), Y(sp[1]));
            spellIdx = (i + 1) % n; lastSpell = t; b.nSpells++;
            return;
        }
    }

    /** Pousse le joystick du jeu dans la direction (dx, dy) de l'écran. */
    private void move(Bridge.State s, float dx, float dy) {
        float l = (float) Math.hypot(dx, dy);
        if (l < 0.001f) { stop(); return; }
        if (s.joy != null) {
            float jx = X(s.joy[0]), jy = Y(s.joy[1]), r = Math.max(X(s.joy[2]), BotService.dpS(b, 30));
            b.holdStart = null;
            b.joyWant = new float[]{jx + dx / l * r * 0.95f, jy + dy / l * r * 0.95f};
        } else {
            b.joyWant = null;
            float md = Math.min(b.sw, b.sh);
            b.tap(b.px + dx / l * md * 0.25f, b.py + dy / l * md * 0.25f);
        }
    }
}
