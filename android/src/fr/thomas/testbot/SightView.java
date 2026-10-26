package fr.thomas.testbot;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.view.View;

/** Calque « vue du bot » : ce qu'il a repéré, où il touche, ce qu'il pense faire. */
final class SightView extends View {
    private final BotService b;
    private final Paint st = new Paint(Paint.ANTI_ALIAS_FLAG), fill = new Paint(Paint.ANTI_ALIAS_FLAG), txt = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final int[] loc = new int[2];
    private final RectF r = new RectF();

    SightView(BotService b) {
        super(b);
        this.b = b;
        st.setStyle(Paint.Style.STROKE);
        st.setStrokeWidth(Ui.dp(b, 2.5f));
        txt.setTypeface(Typeface.DEFAULT_BOLD);
        txt.setTextSize(Ui.dp(b, 13));
        txt.setTextAlign(Paint.Align.CENTER);
    }

    @Override
    protected void onDraw(Canvas c) {
        getLocationOnScreen(loc);
        c.save();
        c.translate(-loc[0], -loc[1]); // tout est en coordonnées écran
        float d = Ui.dp(b, 1);
        long now = BotService.now();

        // Bandeau d'état en haut
        String s = (b.on ? "BOT · " + b.status : "BOT en pause") + "   ·   vue " + CaptureService.fps + " img/s";
        float tw = txt.measureText(s) + d * 24, cx = b.sw / 2f, top = loc[1] + d * 8;
        r.set(cx - tw / 2, top, cx + tw / 2, top + d * 26);
        fill.setColor(0xD9101216);
        c.drawRoundRect(r, d * 13, d * 13, fill);
        txt.setColor(b.on ? 0xFFFFFFFF : 0xFFB8BEC9);
        c.drawText(s, cx, top + d * 18, txt);
        if (!b.on) { c.restore(); return; }

        if (b.bridge.live()) {
            Bridge.State s = b.bridge.last;
            float kx = s.sw > 0 ? b.sw / s.sw : 1, ky = s.sh > 0 ? b.sh / s.sh : 1;
            st.setColor(Ui.CYAN);
            c.drawCircle(s.px * kx, s.py * ky, d * 20, st);
            st.setColor(0xFFFFFFFF);
            float e = d * 10;
            for (float[] p : s.enemies) if (p[2] == 1) { float x = p[0] * kx, y = p[1] * ky; c.drawLine(x - e, y - e, x + e, y + e, st); c.drawLine(x + e, y - e, x - e, y + e, st); }
            st.setColor(Ui.AMBER);
            for (float[] p : s.chests) if (p[2] == 1) { float x = p[0] * kx, y = p[1] * ky; c.drawRect(x - d * 12, y - d * 12, x + d * 12, y + d * 12, st); }
            st.setColor(Ui.CORAL);
            for (float[] z : s.dangers) c.drawCircle(z[0] * kx, z[1] * ky, Math.max(z[2] * kx, d * 10), st);
            if (s.nav != null) { st.setColor(0xAAFFFFFF); c.drawLine(s.px * kx, s.py * ky, s.nav[0] * kx, s.nav[1] * ky, st); }
        }
        boolean footMode = !b.bridge.live() && b.effectiveBrain().equals("foot");
        if (footMode) {
            float[] bl = b.foot.ball, cr = b.foot.car;
            st.setColor(Ui.CYAN);
            if (bl != null) { c.drawCircle(bl[0], bl[1], d * 26, st); c.drawCircle(bl[0], bl[1], d * 4, st); }
            st.setColor(0xFFFFFFFF);
            if (cr != null) { c.drawRect(cr[0] - d * 26, cr[1] - d * 14, cr[0] + d * 26, cr[1] + d * 14, st); }
            if (bl != null && cr != null) { st.setColor(0x88FFFFFF); c.drawLine(cr[0], cr[1], bl[0], bl[1], st); }
        } else {
            // Mon perso (centre supposé)
            st.setColor(Ui.CYAN);
            c.drawCircle(b.px, b.py, d * 20, st);
        }
        // Note de l'IA sous le bandeau
        String note = b.ai.note;
        if (b.ai.hasKey() && note != null && !note.isEmpty()) {
            String n = "IA : " + (note.length() > 70 ? note.substring(0, 70) + "…" : note);
            float nw = txt.measureText(n) + d * 20;
            r.set(cx - nw / 2, top + d * 30, cx + nw / 2, top + d * 52);
            fill.setColor(0xCC101216);
            c.drawRoundRect(r, d * 11, d * 11, fill);
            txt.setColor(Ui.CYAN);
            c.drawText(n, cx, top + d * 46, txt);
        }

        // Ennemis (blanc : jamais rouge, sinon le bot croirait voir une barre de vie)
        st.setColor(0xFFFFFFFF);
        float e = d * 10;
        if (b.cfg.auto) for (float[] p : b.auto.enemies) { c.drawLine(p[0] - e, p[1] - e, p[0] + e, p[1] + e, st); c.drawLine(p[0] + e, p[1] - e, p[0] - e, p[1] + e, st); }
        else for (Vision.Blob p : b.enemies) { c.drawLine(p.x - e, p.y - e, p.x + e, p.y + e, st); c.drawLine(p.x + e, p.y - e, p.x - e, p.y + e, st); }

        // Butin (cyan : jamais doré, sinon le bot croirait voir du butin)
        st.setColor(Ui.CYAN);
        float k = d * 14;
        if (b.cfg.auto) for (float[] p : b.auto.loot) c.drawRect(p[0] - k, p[1] - k, p[0] + k, p[1] + k, st);
        else for (Vision.Blob p : b.chests) c.drawRect(p.x - k, p.y - k, p.x + k, p.y + k, st);

        // Cadre de la mini-carte, dessiné à l'extérieur pour ne pas fausser sa lecture
        float[] mmr = b.cfg.minimap;
        if (mmr != null) {
            st.setColor(0xAAFFFFFF);
            float g = d * 4;
            c.drawRect(mmr[0] * b.sw - g, mmr[1] * b.sh - g, mmr[2] * b.sw + g, mmr[3] * b.sh + g, st);
        }

        // Sorts repérés
        st.setColor(0xFF9F8BFF);
        for (float[] sp : b.cfg.spells) c.drawCircle(sp[0] * b.sw, sp[1] * b.sh, d * 30, st);

        // Doigt de boost
        if (b.hold2 != null) { fill.setColor(0xCC7FE0FF); c.drawCircle(b.hold2[0], b.hold2[1], d * 14, fill); }
        // Bouton gauche/droite tenu
        if (b.holdStart != null && b.joyWant != null) { fill.setColor(0xCCFFFFFF); c.drawCircle(b.holdStart[0], b.holdStart[1], d * 14, fill); }

        // Joystick tenu
        if (b.cfg.joy != null) {
            float jx = b.cfg.joy[0] * b.sw, jy = b.cfg.joy[1] * b.sh;
            st.setColor(0x88FFFFFF);
            c.drawCircle(jx, jy, d * 48, st);
            if (b.joyWant != null) {
                st.setColor(0xFFFFFFFF);
                c.drawLine(jx, jy, b.joyWant[0], b.joyWant[1], st);
                fill.setColor(0xFFFFFFFF);
                c.drawCircle(b.joyWant[0], b.joyWant[1], d * 9, fill);
            }
        }

        // Touchers récents (cercles qui s'effacent)
        for (int i = b.tapsShown.size() - 1; i >= 0; i--) {
            float[] t = b.tapsShown.get(i);
            float a = 1f - (now - t[2]) / 600f;
            if (a <= 0) continue;
            st.setColor(((int) (a * 255) << 24) | 0xFFFFFF);
            c.drawCircle(t[0], t[1], d * (8 + (1 - a) * 22), st);
        }
        c.restore();
    }
}
