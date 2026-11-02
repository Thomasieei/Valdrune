"""Ajoute les légendes du plan du royaume sur la vue de dessus rendue par Godot."""
import sys
from PIL import Image, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
W, H = im.size
side = min(W, H)
x0 = (W - side) // 2
im = im.crop((x0, 0, x0 + side, side)).resize((1200, 1200), Image.LANCZOS)
S = 1200
d = ImageDraw.Draw(im, "RGBA")
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 19)
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 40)
except OSError:
    font = small = big = ImageFont.load_default()


def px(x, z):
    return ((x + 320) / 640 * S, (z + 320) / 640 * S)


labels = [
    ("CHÂTEAU", "enceinte 104×84 m · donjon visitable", 0, -130),
    ("Bourg", "marché", -8, -20),
    ("Champs évolutifs", "blé et choux, ferme, moulin", 110, -5),
    ("Mine", "gisements fer, cuivre, or, cristal", 175, -175),
    ("Forêt de l'Ouest", "dense, avec clairières", -190, 20),
    ("Bûcherons", "", -120, -10),
    ("Lac", "ponton et barques", 175, 165),
    ("PORTAIL", "→ royaume des Nains (scellé)", 35, 235),
    ("Rivière", "deux ponts", -110, -50),
    ("Montagnes", "limites du royaume", -250, -280),
]
for name, sub, x, z in labels:
    cx, cy = px(x, z)
    d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(255, 220, 120, 255), outline=(40, 25, 10, 255), width=3)
    tw = d.textlength(name, font=font)
    sw = d.textlength(sub, font=small) if sub else 0
    w = max(tw, sw) + 20
    h = 36 + (26 if sub else 0)
    bx, by = cx + 12, cy - h / 2
    if bx + w > S - 10:
        bx = cx - 12 - w
    d.rounded_rectangle([bx, by, bx + w, by + h], radius=10, fill=(20, 18, 30, 190))
    d.text((bx + 10, by + 4), name, font=font, fill=(255, 225, 150, 255))
    if sub:
        d.text((bx + 10, by + 36), sub, font=small, fill=(225, 230, 240, 255))
# échelle
d.rounded_rectangle([20, S - 70, 300, S - 20], radius=10, fill=(20, 18, 30, 190))
x1, x2 = 40, 40 + 100 / 640 * S
d.line([x1, S - 40, x2, S - 40], fill=(255, 255, 255, 255), width=4)
d.text((x2 + 12, S - 55), "100 m", font=font, fill=(255, 255, 255, 255))
d.rounded_rectangle([S - 330, 20, S - 20, 80], radius=10, fill=(20, 18, 30, 190))
d.text((S - 315, 28), "Le Royaume — plan", font=font, fill=(255, 225, 150, 255))
d.text((S - 315, 56), "640 m × 640 m · nord en haut", font=small, fill=(225, 230, 240, 255))
im.save(dst)
print("ok", dst)
