#!/usr/bin/env python3
"""Génère les miniatures des sorts (assets/ui/icons/*.png) à partir des SVG de game-icons.net (CC BY 3.0).
Usage : python3 tools/gen_icons.py <dossier_du_depot_game-icons>"""
import sys, os, re, subprocess, io, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops
SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "icons")
ICONS = {  # icone: (svg, couleur)
 "feu": ("lorc/fireball", (1.0, .55, .15)), "bouclier": ("lorc/magic-shield", (.35, .8, 1.0)),
 "givre": ("lorc/frozen-orb", (.6, .9, 1.0)), "racines": ("lorc/vine-whip", (.5, .85, .3)),
 "main": ("lorc/magic-palm", (.7, .55, 1.0)), "gravite": ("lorc/heavy-fall", (.55, .3, .9)),
 "arsenal": ("lorc/sword-array", (.6, .85, 1.0)), "projection": ("lorc/punch-blast", (.85, .5, 1.0)),
 "vortex": ("lorc/vortex", (.45, .25, .75)), "dome": ("delapouite/lightning-dome", (1.0, .85, .4)),
 "mur": ("delapouite/stone-wall", (.9, .8, .55)), "reflet": ("lorc/mirror-mirror", (.7, .95, 1.0)),
 "sablier": ("lorc/hourglass", (.85, .85, 1.0)), "chaines": ("lorc/imprisoned", (1.0, .75, .35)),
 "meteore": ("lorc/burning-meteor", (1.0, .45, .15)), "piliers": ("lorc/earth-spit", (.75, .6, .4)),
 "eclair": ("lorc/lightning-storm", (.65, .8, 1.0)), "faille": ("lorc/magic-portal", (.85, .2, .55)),
 "legion": ("lorc/ghost-ally", (.5, .75, 1.0)), "couronne": ("delapouite/overlord-helm", (.9, .2, .25)),
 "oeil": ("delapouite/eye-target", (.4, .9, 1.0)), "transpo": ("lorc/teleport", (.6, .4, 1.0)),
 "incarnation": ("lorc/aura", (1.0, .8, .35)), "possession": ("lorc/puppet", (.75, .3, 1.0)),
 "lames": ("lorc/sword-spin", (.55, .95, .95)), "onde": ("lorc/psychic-waves", (.95, .9, .6)),
 "epee": ("lorc/broadsword", (1.0, .85, .4)), "esquive": ("lorc/dodging", (.6, .9, 1.0)),
 "vol": ("lorc/angel-wings", (.55, .85, 1.0)), "grimoire": ("delapouite/spell-book", (.85, .7, 1.0)),
 "carte": ("lorc/treasure-map", (.95, .8, .5)),
}
S = 192
def glyph(path):
    svg = open(os.path.join(SRC, path + ".svg")).read()
    svg = svg.replace('<path d="M0 0h512v512H0z"/>', '')
    png = subprocess.run(["rsvg-convert", "-w", str(int(S * .62)), "-h", str(int(S * .62))], input=svg.encode(), capture_output=True, check=True).stdout
    g = Image.open(io.BytesIO(png)).convert("RGBA")
    return g.getchannel("A")
def badge(name, path, col):
    c = tuple(int(255 * v) for v in col)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # disque : dégradé radial (lumière en haut), coloré par l'élément
    disc = Image.new("RGBA", (S, S))
    px = disc.load()
    for y in range(S):
        for x in range(S):
            dx, dy = (x - S / 2) / (S / 2), (y - S * .42) / (S / 2)
            r = min(1.0, math.hypot(dx, dy))
            k = (1 - r) ** 1.4
            px[x, y] = (int(10 + c[0] * .62 * k), int(10 + c[1] * .62 * k), int(16 + c[2] * .62 * k), 255)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse((4, 4, S - 5, S - 5), fill=255)
    img.paste(disc, (0, 0), mask)
    d = ImageDraw.Draw(img)
    # cercle runique discret
    for i in range(36):
        a = i / 36 * math.tau
        r0, r1 = S * .40, S * (.43 if i % 3 else .45)
        d.line([(S / 2 + math.cos(a) * r0, S / 2 + math.sin(a) * r0), (S / 2 + math.cos(a) * r1, S / 2 + math.sin(a) * r1)], fill=c + (70,), width=2)
    a = glyph(path)
    off = ((S - a.width) // 2, (S - a.height) // 2 + 2)
    full = Image.new("L", (S, S), 0); full.paste(a, off)
    # halo coloré, ombre portée, glyphe clair
    glow = full.filter(ImageFilter.GaussianBlur(9))
    gl = Image.new("RGBA", (S, S), tuple(min(255, int(v * 1.15) + 30) for v in c) + (0,)); gl.putalpha(ImageChops.multiply(glow, Image.new("L", (S, S), 235)))
    img = Image.alpha_composite(img, gl)
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sh.putalpha(full.filter(ImageFilter.GaussianBlur(3)).point(lambda v: v * .8))
    img.alpha_composite(sh, (3, 5))
    fg = Image.new("RGBA", (S, S))
    gp = fg.load(); fp = full.load()
    for y in range(S):
        t = y / S
        row = tuple(int(255 - (255 - v) * (.15 + .55 * t)) for v in c)
        for x in range(S):
            if fp[x, y]:
                gp[x, y] = row + (fp[x, y],)
    img = Image.alpha_composite(img, fg)
    # anneau doré + reflet
    d = ImageDraw.Draw(img)
    d.ellipse((4, 4, S - 5, S - 5), outline=(230, 195, 120, 255), width=5)
    d.ellipse((10, 10, S - 11, S - 11), outline=c + (150,), width=2)
    d.arc((14, 12, S - 15, S - 40), 200, 340, fill=(255, 255, 255, 60), width=4)
    img = img.resize((128, 128), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))
for n, (p, col) in ICONS.items():
    badge(n, p, col)
print(len(ICONS), "icônes")
