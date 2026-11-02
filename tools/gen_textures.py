"""Textures peintes, stylisées et raccordables (tileable) pour l'architecture du royaume.
Palette volontairement douce pour s'accorder au low poly Avramania et aux persos Quaternius."""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import gaussian_filter
import os, sys

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)
N = 512


def tile_noise(scale, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((N, N))
    amp = 1.0
    tot = 0
    for o in range(octaves):
        g = max(2, int(N / scale * (2 ** o)))
        base = r.random((g, g))
        img = Image.fromarray((base * 255).astype(np.uint8))
        # répétition 3x3 pour un raccord sans couture
        big = Image.new("L", (g * 3, g * 3))
        for i in range(3):
            for j in range(3):
                big.paste(img, (i * g, j * g))
        big = big.resize((N * 3, N * 3), Image.BICUBIC)
        a = np.asarray(big, dtype=float)[N:2 * N, N:2 * N] / 255.0
        acc += a * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def save(name, arr):
    arr = np.clip(arr, 0, 1)
    Image.fromarray((arr * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))


def bricks(name, rows, cols, palette, mortar, mortar_px=5, jitter=0.07, bevel=0.18, seed=1, offset=0.5):
    r = np.random.default_rng(seed)
    img = np.zeros((N, N, 3))
    h = N // rows
    w = N // cols
    nz = tile_noise(40, 5, seed)
    nz2 = tile_noise(8, 3, seed + 9)
    yy, xx = np.mgrid[0:N, 0:N]
    row = np.minimum(yy // h, rows - 1)
    shift = (row % 2) * int(w * offset)
    xs = (xx + shift) % N
    col = xs // w
    lx = (xs % w) / w
    ly = (yy % h) / h
    ids = row * 1000 + col
    uniq = np.unique(ids)
    colors = {}
    for u in uniq:
        c = np.array(palette[r.integers(len(palette))], dtype=float)
        c *= 1 + r.normal(0, jitter)
        colors[u] = c
    lut = np.zeros((ids.max() + 1, 3))
    for u, c in colors.items():
        lut[u] = c
    img = lut[ids]
    # dégradé de lumière (haut clair, bas sombre) + bords biseautés
    m = mortar_px / h
    mx = mortar_px / w
    edge = np.minimum(np.minimum(lx, 1 - lx) / mx, np.minimum(ly, 1 - ly) / m)
    top = np.clip((ly - m) / (3 * m), 0, 1)
    shade = 1 + bevel * (1 - np.clip(edge - 1, 0, 1)) * (np.where(ly < 0.5, 0.6, -1.0))
    img = img * shade[..., None]
    img = img * (0.88 + 0.24 * nz[..., None]) * (0.95 + 0.1 * nz2[..., None])
    is_mortar = (edge < 1)
    img[is_mortar] = np.array(mortar) * (0.85 + 0.3 * nz[is_mortar][..., None])
    save(name, img)


def planks(name, n, palette, seed=3, vertical=True):
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:N, 0:N]
    w = N // n
    p = np.minimum(xx // w, n - 1)
    lx = (xx % w) / w
    base = np.array([palette[r.integers(len(palette))] for _ in range(n)], dtype=float)
    base *= (1 + r.normal(0, 0.06, (n, 1)))
    img = base[p]
    grain = tile_noise(6, 3, seed)
    streak = np.sin((yy / N * 2 * np.pi * 3) + grain * 9 + p * 1.7) * 0.5 + 0.5
    img = img * (0.86 + 0.18 * streak[..., None])
    gap = (lx < 0.03) | (lx > 0.97)
    img[gap] *= 0.45
    img *= (1 - 0.12 * np.clip(1 - np.abs(lx - 0.5) * 2.2, 0, 1)[..., None] * 0)  # (réservé)
    save(name, img)


def roof(name, rows, cols, palette, seed=4):
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:N, 0:N]
    h = N // rows
    w = N // cols
    row = np.minimum(yy // h, rows - 1)
    xs = (xx + (row % 2) * (w // 2)) % N
    col = xs // w
    lx = (xs % w) / w - 0.5
    ly = (yy % h) / h
    pal = np.array(palette, dtype=float)
    ids = (row * 97 + col * 31) % len(pal)
    jit = r.normal(0, 0.05, (rows + 2, cols * 2 + 2))
    img = pal[ids] * (1 + jit[row, col])[..., None]
    # tuile arrondie : bas arrondi plus clair, ombre portée en haut
    curve = 1 - (lx * 2) ** 2
    rounded = ly > (1 - 0.35 * curve)
    shade = 0.75 + 0.45 * ly
    img = img * shade[..., None]
    img[rounded] *= 1.0
    edge = np.abs(lx) > 0.47
    img[edge] *= 0.6
    nz = tile_noise(30, 4, seed)
    img *= (0.9 + 0.2 * nz[..., None])
    save(name, img)


def flat(name, color, var=0.08, seed=5, scale=30):
    nz = tile_noise(scale, 5, seed)
    img = np.ones((N, N, 3)) * np.array(color) * (1 - var + 2 * var * nz)[..., None]
    save(name, img)


def flagstones(name, palette, mortar, seed=6, cells=10):
    """Dallage irrégulier (Voronoï raccordable)."""
    r = np.random.default_rng(seed)
    pts = r.random((cells * cells, 2)) * N
    # raccord : copier les points autour
    allp = np.concatenate([pts + np.array([dx, dy]) * N for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    cols = np.array([palette[i % len(palette)] for i in r.integers(0, 100, len(pts))], dtype=float)
    cols *= (1 + r.normal(0, 0.035, (len(pts), 1)))
    yy, xx = np.mgrid[0:N, 0:N]
    P = np.stack([xx.ravel(), yy.ravel()], 1).astype(float)
    from scipy.spatial import cKDTree
    t = cKDTree(allp)
    d, idx = t.query(P, k=2)
    owner = idx[:, 0] % len(pts)
    border = (d[:, 1] - d[:, 0]) < 3.5
    img = cols[owner].reshape(N, N, 3)
    dd = (d[:, 1] - d[:, 0]).reshape(N, N)
    img *= (0.92 + 0.08 * np.clip(dd / 25, 0, 1))[..., None]
    nz = tile_noise(25, 4, seed)
    img *= (0.9 + 0.2 * nz[..., None])
    img[border.reshape(N, N)] = mortar
    save(name, img)


# --- Pierre du château : blocs taillés beige-gris, chauds ---
bricks("pierre_chateau", 8, 4, [(0.70, 0.66, 0.58), (0.64, 0.61, 0.55), (0.74, 0.70, 0.62), (0.60, 0.58, 0.54), (0.68, 0.63, 0.53)],
       (0.36, 0.33, 0.30), mortar_px=5, seed=11)
# Soubassement plus sombre et plus gros
bricks("pierre_base", 6, 3, [(0.50, 0.49, 0.47), (0.56, 0.54, 0.50), (0.46, 0.45, 0.44)], (0.26, 0.25, 0.24), mortar_px=6, seed=12)
# Créneaux / pierre claire de bordure
bricks("pierre_claire", 4, 2, [(0.80, 0.77, 0.70), (0.76, 0.73, 0.66)], (0.45, 0.42, 0.38), mortar_px=4, seed=13)
roof("toit_ardoise", 16, 10, [(0.30, 0.36, 0.52), (0.27, 0.33, 0.48), (0.33, 0.40, 0.56)], seed=21)
roof("toit_tuile", 16, 10, [(0.70, 0.33, 0.22), (0.64, 0.30, 0.20), (0.75, 0.38, 0.25)], seed=22)
roof("toit_chaume", 24, 6, [(0.78, 0.65, 0.38), (0.72, 0.60, 0.34), (0.80, 0.68, 0.42)], seed=23)
planks("bois", 6, [(0.52, 0.36, 0.22), (0.48, 0.33, 0.20), (0.56, 0.39, 0.24)], seed=31)
planks("bois_sombre", 5, [(0.34, 0.23, 0.15), (0.30, 0.20, 0.13), (0.37, 0.25, 0.16)], seed=32)
flat("crepi", (0.90, 0.85, 0.74), var=0.06, seed=41)
flagstones("dallage", [(0.66, 0.62, 0.55), (0.63, 0.59, 0.53), (0.68, 0.64, 0.57)], (0.46, 0.42, 0.37), seed=51, cells=9)
flagstones("paves", [(0.60, 0.57, 0.51), (0.63, 0.59, 0.52), (0.57, 0.54, 0.49)], (0.42, 0.39, 0.34), seed=52, cells=16)
bricks("parquet", 16, 2, [(0.58, 0.40, 0.25), (0.54, 0.37, 0.23), (0.61, 0.43, 0.27)], (0.30, 0.20, 0.12), mortar_px=2, seed=61, offset=0.37)
print("ok")

# Sillons de champ (bandes de terre), répétables
yy, xx = np.mgrid[0:N, 0:N]
nz = tile_noise(20, 4, 71)
band = (np.sin(yy / N * 2 * np.pi * 8) * 0.5 + 0.5)
c_dark = np.array((0.36, 0.26, 0.17)); c_light = np.array((0.55, 0.42, 0.28))
img = c_dark + (c_light - c_dark) * (band ** 1.5)[..., None]
img *= (0.88 + 0.24 * nz[..., None])
save("sillons", img)

# Terre battue des sentiers
nz = tile_noise(30, 5, 81); nz2 = tile_noise(6, 3, 82)
img = np.ones((N, N, 3)) * np.array((0.56, 0.45, 0.31)) * (0.85 + 0.25 * nz[..., None]) * (0.92 + 0.12 * nz2[..., None])
save("terre", img)
