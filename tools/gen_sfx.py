#!/usr/bin/env python3
"""Sons de signature des pouvoirs, synthétisés (aucune source externe) → assets/sons/*.wav"""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sons")
rng = np.random.default_rng(7)
def env(n, a, d):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)
def lp(x, k):
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc); y[i] = acc
    return y
def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
def boom(dur=1.4):
    n = int(SR * dur); t = np.arange(n) / SR
    f = 55 * np.exp(-t * 2.5) + 28
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.005, 0.35)
    noise = lp(rng.standard_normal(n), 0.08) * env(n, 0.002, 0.25) * 1.6
    crack = rng.standard_normal(n) * env(n, 0.0005, 0.03) * 0.6
    return sub * 1.2 + noise + crack
def whoosh(dur=0.7):
    n = int(SR * dur); t = np.arange(n) / SR
    x = rng.standard_normal(n); k = 0.02 + 0.25 * np.sin(np.pi * t / dur) ** 2
    y = np.zeros(n); acc = 0.0
    for i in range(n):
        acc += k[i] * (x[i] - acc); y[i] = acc
    return y * np.sin(np.pi * t / dur) ** 1.5
save("sov_explosion", boom())
o = boom(1.2); w = whoosh(1.2); save("sov_onde", o * 0.8 + w * 1.4)
# lames : tintement métallique + scintillement
n = int(SR * 1.3); t = np.arange(n) / SR
ring = sum(np.sin(2 * np.pi * f * t + p) * env(n, 0.002, d) for f, p, d in [(1320, 0, .5), (1987, 1, .35), (2640, 2, .25), (3511, .5, .18)])
shimmer = np.sin(2 * np.pi * 880 * t) * np.sin(2 * np.pi * 7 * t) * env(n, 0.15, 0.4) * 0.4
save("sov_lames", ring + shimmer + whoosh(1.3) * 0.5)
# possession : drone grave qui monte, chœur désaccordé, souffle
n = int(SR * 1.8); t = np.arange(n) / SR
dr = sum(np.sin(2 * np.pi * (f + 18 * t) * t) for f in [110, 111.7, 164.5, 220.9]) * np.minimum(1, t / 0.6) * np.exp(-np.maximum(0, t - 1.2) * 4)
breath = lp(rng.standard_normal(n), 0.05) * np.sin(np.pi * t / 1.8) * 1.5
save("sov_possession", dr * 0.5 + breath)
print("ok")
