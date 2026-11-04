package com.thomas.botlab;

/** Une image capturée (réduite). scale = largeurImage / largeurEcran. */
public class Frame {
    public final byte[] px;
    public final int w, h, stride, screenW, screenH;
    public final float scale;
    public final long time;

    public Frame(byte[] px, int w, int h, int stride, int screenW, int screenH, long time) {
        this.px = px; this.w = w; this.h = h; this.stride = stride;
        this.screenW = screenW; this.screenH = screenH;
        this.scale = w / (float) screenW; this.time = time;
    }

    /** Couleur 0xRRGGBB. */
    public int rgb(int x, int y) {
        if (x < 0) x = 0; else if (x >= w) x = w - 1;
        if (y < 0) y = 0; else if (y >= h) y = h - 1;
        int i = y * stride + x * 4;
        return ((px[i] & 255) << 16) | ((px[i + 1] & 255) << 8) | (px[i + 2] & 255);
    }

    public float lum(int cx, int cy, int r) {
        float sum = 0; int n = 0;
        for (int y = cy - r; y <= cy + r; y++)
            for (int x = cx - r; x <= cx + r; x++) {
                int c = rgb(x, y);
                sum += 0.299f * ((c >> 16) & 255) + 0.587f * ((c >> 8) & 255) + 0.114f * (c & 255);
                n++;
            }
        return n == 0 ? 0 : sum / n;
    }
}
